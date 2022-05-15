using UnityEngine;

#if UNITY_EDITOR
using System;
using System.Linq;
using System.Collections.Generic;
using System.Reflection;

using UnityEditor;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEngine.SceneManagement;

using VRC.SDK3.Components;
using VRC.SDKBase;
using VRC.Udon;
#endif

using UnityObject = UnityEngine.Object;

namespace JLChnToZ.VRC.Answer {
    internal enum ProcessMode {
        InactiveGameObject = 0,
        RemoveChildrenComponentsOnly = 1,
        RemoveSelfComponentsOnly = 2,
    }

    [DisallowMultipleComponent]
    public sealed class SyncFriendlyPlatformSelector: MonoBehaviour {
        [Header("Supported Platforms")]
        [SerializeField] internal bool pcPlatform = true;
        [SerializeField] internal bool questPlatform = true;

        [Header("Handling Method on Unsupported Platform")]
        [SerializeField] internal ProcessMode processMode;
    }

    #if UNITY_EDITOR
    [CustomEditor(typeof(SyncFriendlyPlatformSelector))]
    [CanEditMultipleObjects]
    internal sealed class SyncFriendlyPlatformSelectorEditor: Editor {
        SerializedProperty pcPlatform;
        SerializedProperty questPlatform;
        SerializedProperty processMode;

        void OnEnable() {
            pcPlatform = serializedObject.FindProperty("pcPlatform");
            questPlatform = serializedObject.FindProperty("questPlatform");
            processMode = serializedObject.FindProperty("processMode");
        }

        public override void OnInspectorGUI() {
            EditorGUILayout.PropertyField(pcPlatform);
            EditorGUILayout.PropertyField(questPlatform);
            EditorGUILayout.PropertyField(processMode);
            if (!processMode.hasMultipleDifferentValues)
                switch ((ProcessMode)processMode.intValue) {
                    case ProcessMode.InactiveGameObject:
                        EditorGUILayout.HelpBox(
                            "Inactives this game object and its children when building to unsupported platform. Also removes components that don't affects synchronization.",
                            MessageType.Info
                        );
                        break;
                    case ProcessMode.RemoveChildrenComponentsOnly:
                        EditorGUILayout.HelpBox(
                            "Removes components that don't affects synchronization in this game object and its children when building to unsupported platform.",
                            MessageType.Info
                        );
                        break;
                    case ProcessMode.RemoveSelfComponentsOnly:
                        EditorGUILayout.HelpBox(
                            "Removes components that don't affects synchronization in this game object when building to unsupported platform. Children objects and its components will retain as-is.",
                            MessageType.Info
                        );
                        break;
                }
            serializedObject.ApplyModifiedProperties();
        }
    }

    internal sealed class PlatformSelectorPreprocessor: IProcessSceneWithReport {
        static readonly FieldInfo publicVariablesUnityEngineObjectsField =
            typeof(UdonBehaviour).GetField("publicVariablesUnityEngineObjects", BindingFlags.NonPublic | BindingFlags.Instance);

        public int callbackOrder => 0;

        public void OnProcessScene(Scene scene, BuildReport report) {
            var platform = EditorUserBuildSettings.activeBuildTarget;
            var queue = new Queue<(GameObject, ProcessMode)>();
            // Filter all game objects with SyncFriendlyPlatformSelector components
            foreach (
                var selector in scene.GetRootGameObjects()
                .SelectMany(go => go.GetComponentsInChildren<SyncFriendlyPlatformSelector>(true))
            ) {
                // Enqueue the game objects if platform is mark unsupported.
                if (
                    (platform == BuildTarget.StandaloneWindows64 && !selector.pcPlatform) ||
                    (platform == BuildTarget.Android && !selector.questPlatform)
                ) queue.Enqueue((selector.gameObject, selector.processMode));
                // Whatever the settings it has, remove the component as we don't want to include them in built world.
                UnityObject.DestroyImmediate(selector);
            }
            // We use queue to recursively iterate over every game objects.
            while (queue.Count > 0) {
                var (gameObject, processMode) = queue.Dequeue();
                CleanComponents(gameObject);
                if (processMode == ProcessMode.InactiveGameObject || processMode == ProcessMode.RemoveChildrenComponentsOnly) {
                    if (processMode == ProcessMode.InactiveGameObject)
                        gameObject.SetActive(false);
                    foreach (Transform child in gameObject.transform)
                        queue.Enqueue((child.gameObject, processMode));
                }
            }
        }

        static void CleanComponents(GameObject gameObject) {
            var components = gameObject.GetComponents<Component>();
            // Skip if the game object is empty.
            switch (components.Length) {
                case 0: return;
                case 1: if (components[0] is Transform) return; break;
            }
            // Sort components by dependency order to safely disarm.
            var comparer = new DependencyComparer();
            var queue = new Queue<Component>(components);
            var enqueuedComponents = new HashSet<Component>();
            while (queue.Count > 0) {
                var component = queue.Dequeue();
                if (component == null) continue;
                // When there is a required component, that component type will move to the end of the internal priority order list.
                // And it will ensures that component will be removed after dependency lock is resolved.
                foreach (var requireComponent in component.GetType().GetCustomAttributes<RequireComponent>(true)) {
                    EnqueueComponents(queue, enqueuedComponents, comparer, gameObject, requireComponent.m_Type0);
                    EnqueueComponents(queue, enqueuedComponents, comparer, gameObject, requireComponent.m_Type1);
                    EnqueueComponents(queue, enqueuedComponents, comparer, gameObject, requireComponent.m_Type2);
                }
            }
            // No need to sort if no dependency problem within this game object.
            if (!comparer.IsEmpty) Array.Sort(components, comparer);
            foreach (var component in components) {
                // Transform component is mandatory so we don't touch it.
                if (component == null || component is Transform) continue;
                // We will keep all behaviours which has `INetworkID` interface but will set them disabled.
                // (I believe this interface tells VRChat to give a network ID to this component for network sync)
                if (component is Behaviour behaviour && behaviour is INetworkID) {
                    behaviour.enabled = false;
                    // Remove references to unused assets.
                    if (behaviour is UdonBehaviour) {
                        if (publicVariablesUnityEngineObjectsField.GetValue(behaviour) is List<UnityObject> refs)
                            for (int i = 0; i < refs.Count; i++)
                                refs[i] = null;
                    } else if (behaviour is VRCObjectPool objectPool)
                        objectPool.Pool = new GameObject[0];
                    continue;
                }
                // Anything else, kill them!
                UnityObject.DestroyImmediate(component);
            }
        }

        static void EnqueueComponents(Queue<Component> queue, HashSet<Component> enqueuedComponents, DependencyComparer comparer, GameObject gameObject, Type type) {
            if (type == null) return;
            comparer.Priortize(type);
            foreach (var component in gameObject.GetComponents(type))
                if (enqueuedComponents.Add(component))
                    queue.Enqueue(component);
        }

        class DependencyComparer: IComparer<Component> {
            static readonly Comparer<int> intComparer = Comparer<int>.Default;
            readonly List<Type> order = new List<Type>();

            public bool IsEmpty => order.Count == 0;

            public int Compare(Component x, Component y) {
                Type xType = x.GetType(), yType = y.GetType();
                return intComparer.Compare(
                    order.FindIndex(type => type.IsAssignableFrom(xType)),
                    order.FindIndex(type => type.IsAssignableFrom(yType))
                );
            }

            public void Priortize(Type type) {
                order.Remove(type);
                order.Add(type);
            }
        }
    }
    #endif
}
