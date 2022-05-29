using System;
using System.Collections.Generic;
using UnityEngine;
using UdonSharp;
using VRC.SDKBase;
using VRC.SDK3.Components;
using VRC.Udon;
using VRC.Udon.Common;
using VRC.Udon.Common.Interfaces;
#if UNITY_EDITOR && !COMPILER_UDONSHARP
using System.Linq;
using System.Threading.Tasks;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEngine.SceneManagement;
using UdonSharpEditor;

using UnityObject = UnityEngine.Object;
#endif

namespace JLChnToZ.VRC {
    [UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
    [RequireComponent(typeof(VRCObjectPool))]
    public class PickupablePoolManager: UdonSharpBehaviour {
        VRCObjectPool objectPool;
        bool hasShuffled;
        [SerializeField] bool autoSpawn = true;
        [UdonSynced] bool hasDrain;

        void Start() {
            objectPool = (VRCObjectPool)GetComponent(typeof(VRCObjectPool));
            if (Networking.IsOwner(gameObject)) SendCustomEventDelayedFrames(nameof(AutoSpawnNext), 0);
        }

        public override void OnOwnershipTransferred(VRCPlayerApi player) {
            if (player.isLocal) Shuffle();
        }

        public void AutoSpawnNext() {
            if (autoSpawn) SpawnNext();
        }

        public void SpawnNext() {
            if (!Networking.IsOwner(gameObject)) {
                SendCustomNetworkEvent(NetworkEventTarget.Owner, nameof(SpawnNext));
                return;
            }
            DoSpawn();
        }

        void Shuffle() {
            if (objectPool == null) Start();
            objectPool.Shuffle();
            hasShuffled = true;
        }

        void DoSpawn() {
            if (!hasShuffled) Shuffle();
            if (objectPool.TryToSpawn() != null) return;
            hasDrain = true;
            RequestSerialization();
            objectPool.Shuffle();
        }

        public void _ReturnToPool(GameObject returnObj) {
            if (!Networking.IsOwner(gameObject)) return;
            if (!Networking.IsOwner(returnObj)) Networking.SetOwner(Networking.LocalPlayer, returnObj);
            objectPool.Return(returnObj);
            if (!hasDrain) return;
            hasDrain = false;
            RequestSerialization();
            SendCustomEventDelayedSeconds(nameof(AutoSpawnNext), 1);
        }
    }

#if UNITY_EDITOR && !COMPILER_UDONSHARP
    [CustomEditor(typeof(PickupablePoolManager))]
    internal class PickupablePoolManagerEditor: Editor {
        float batchSetTime = 300;
        float batchRespawnDistance = -1;
        Transform batchSpawnTarget;
        SerializedProperty autoSpawnProperty;

        void OnEnable() {
            InitRespawnTime();
            autoSpawnProperty = serializedObject.FindProperty("autoSpawn");
        }

        void InitRespawnTime() {
            var objPool = (target as Component).GetComponent<VRCObjectPool>();
            bool hasSpawnTime = false;
            bool hasRespawnDistance = false;
            bool hasTarget = false;
            batchSpawnTarget = null;
            foreach (var obj in objPool.Pool)
                if (obj != null)
                    foreach (var udon in GetUdonBehaviours<PickupableManager>(obj)) {
                        if (!hasSpawnTime && udon.publicVariables.TryGetVariableValue("resetDuration", out batchSetTime))
                            hasSpawnTime = true;
                        if (!hasRespawnDistance && udon.publicVariables.TryGetVariableValue("respawnDistance", out batchRespawnDistance))
                            hasRespawnDistance = true;
                        if (udon.publicVariables.TryGetVariableValue("customSpawnTarget", out Transform spawnTarget)) {
                            if (batchSpawnTarget == null && spawnTarget != null) {
                                batchSpawnTarget = spawnTarget;
                                hasTarget = true;
                            } else if (hasTarget && batchSpawnTarget != spawnTarget) {
                                batchSpawnTarget = null;
                            }
                        }
                    }
            if (!hasSpawnTime) batchSetTime = 300;
            if (!hasRespawnDistance) batchRespawnDistance = -1;
        }

        public override void OnInspectorGUI() {
            if (UdonSharpGUI.DrawDefaultUdonSharpBehaviourHeader(target)) return;
            EditorGUILayout.PropertyField(autoSpawnProperty);
            EditorGUILayout.Space();

            EditorGUILayout.LabelField("Pickupable Pool Manager Utilities", EditorStyles.boldLabel);
            if (GUILayout.Button("Add all children with handlers to object pool")) DeferStart(AssignPickupableChildren);
            if (GUILayout.Button("Set references to all pooled objects")) DeferStart(AssignPickupable);
            EditorGUILayout.Space();

            EditorGUILayout.LabelField("Batch Set Auto Respawn", EditorStyles.boldLabel);
            EditorGUI.BeginChangeCheck();
            bool autoRespawn = EditorGUILayout.ToggleLeft("Enable (When untouched for certain time)", !float.IsInfinity(batchSetTime));
            bool respawnChanged = EditorGUI.EndChangeCheck();
            if (autoRespawn) {
                if (respawnChanged) batchSetTime = 0;
                batchSetTime = EditorGUILayout.FloatField("Time", batchSetTime);
            } else if (respawnChanged)
                batchSetTime = float.PositiveInfinity;
            if (GUILayout.Button("Apply All")) DeferStart(AssignRespawnTime);
            EditorGUI.BeginChangeCheck();
            autoRespawn = EditorGUILayout.ToggleLeft("Enable (If before pickuped by anyone but moved by physics)", batchRespawnDistance >= 0);
            respawnChanged = EditorGUI.EndChangeCheck();
            if (autoRespawn) {
                if (respawnChanged) batchRespawnDistance = 0;
                batchRespawnDistance = EditorGUILayout.FloatField("Distance", batchRespawnDistance);
            } else if (respawnChanged)
                batchRespawnDistance = -1;
            if (GUILayout.Button("Apply All")) DeferStart(AssignResepawnDistance);
            if (autoRespawn)
                EditorGUILayout.HelpBox("This feature requires custom spawn position setted, you can batch assign it below.", MessageType.Info);
            EditorGUILayout.Space();

            EditorGUILayout.LabelField("Batch Set Spawn Position", EditorStyles.boldLabel);
            batchSpawnTarget = EditorGUILayout.ObjectField("Custom Spawn Position", batchSpawnTarget, typeof(Transform), true) as Transform;
            EditorGUILayout.BeginHorizontal();
            if (GUILayout.Button("Assign This")) {
                batchSpawnTarget = (target as Component).transform;
                DeferStart(AssignSpawnTarget);
            }
            if (GUILayout.Button("Apply All")) DeferStart(AssignSpawnTarget);
            EditorGUILayout.EndHorizontal();
            EditorGUILayout.HelpBox("This is for prevents position shifted when parent is moved, or as a reference on measuring distance to its spawn point.", MessageType.Info);

            serializedObject.ApplyModifiedProperties();
        }

        void AssignPickupableChildren() {
            var targetComponent = target as Component;
            var objPool = targetComponent.GetComponent<VRCObjectPool>();
            var poolSet = new HashSet<GameObject>();
            if (!(target is UdonBehaviour targetUb))
                targetUb = UdonSharpEditorUtility.GetBackingUdonBehaviour(target as UdonSharpBehaviour);
            foreach (Transform child in targetComponent.transform)
                foreach (var udon in GetUdonBehaviours<PickupableManager>(child)) {
                    if (!TrySetOrAddVariable(udon, "poolManager", targetUb))
                        Debug.LogWarning($"Failed to assign {targetUb} as poolManager to {udon}.");
                    poolSet.Add(child.gameObject);
                }
            var poolObjects = new GameObject[poolSet.Count];
            poolSet.CopyTo(poolObjects);
            objPool.Pool = poolObjects;
            RecordPrefabChangedIfNeeded(objPool);
            Debug.Log($"Reassigned object pool entries: {poolObjects.Length}", objPool);
        }

        void AssignPickupable() {
            var targetComponent = target as Component;
            var objPool = targetComponent.GetComponent<VRCObjectPool>();
            if (!(target is UdonBehaviour targetUb))
                targetUb = UdonSharpEditorUtility.GetBackingUdonBehaviour(target as UdonSharpBehaviour);
            BatchAssignVariable(objPool.Pool, "poolManager", targetUb);
        }

        void AssignRespawnTime() => BatchAssignVariable("resetDuration", batchSetTime);

        void AssignResepawnDistance() => BatchAssignVariable("respawnDistance", batchRespawnDistance);

        void AssignSpawnTarget() => BatchAssignVariable("customSpawnTarget", batchSpawnTarget);

        void BatchAssignVariable<T>(string variableName, T value) {
            var targetComponent = target as Component;
            var objPool = targetComponent.GetComponent<VRCObjectPool>();
            BatchAssignVariable(objPool.Pool, variableName, value);
        }

        static void BatchAssignVariable<T>(GameObject[] gameObjects, string variableName, T value) {
            foreach (var obj in gameObjects)
                if (obj != null)
                    foreach (var udon in GetUdonBehaviours<PickupableManager>(obj))
                        if (!TrySetOrAddVariable(udon, variableName, value))
                            Debug.LogWarning($"Failed to assign {variableName} to {udon}.");
        }

        static IEnumerable<UdonBehaviour> GetUdonBehaviours<T>(Component component) => GetUdonBehaviours<T>(component.gameObject);

        static IEnumerable<UdonBehaviour> GetUdonBehaviours<T>(GameObject gameObject) {
            var udons = gameObject.GetComponents<UdonBehaviour>();
            var type = typeof(T);
            foreach (var udon in udons) 
                if (udon.programSource is UdonSharpProgramAsset program && type.IsAssignableFrom(program.sourceCsScript.GetClass()))
                    yield return udon;
        }

        static async void DeferStart(Action callback) {
            await Task.Delay(500);
            callback();
        }

        static bool TrySetOrAddVariable<T>(UdonBehaviour udonBehaviour, string symbolName, T value) {
            var vars = udonBehaviour.publicVariables;
            if (vars.TrySetVariableValue(symbolName, value) || vars.TryAddVariable(
                Activator.CreateInstance(
                    typeof(UdonVariable<>).MakeGenericType(typeof(T)),
                    symbolName, value
                ) as IUdonVariable
            )) {
                RecordPrefabChangedIfNeeded(udonBehaviour);
                return true;
            }
            return false;
        }

        static void RecordPrefabChangedIfNeeded(UnityObject obj) {
            if (PrefabUtility.IsPartOfPrefabInstance(obj))
                PrefabUtility.RecordPrefabInstancePropertyModifications(obj);
        }
    }

    internal sealed class PickupablePoolManagerPreprocessor: IProcessSceneWithReport {
        static readonly Type pickupablePoolManagerType = typeof(PickupablePoolManager);
        public int callbackOrder => 0;

        public void OnProcessScene(Scene scene, BuildReport report) {
            foreach (var ub in scene.GetRootGameObjects().SelectMany(go => go.GetComponentsInChildren<UdonBehaviour>(true)))
                if (
                    ub != null &&
                    ub.programSource is UdonSharpProgramAsset usharpAsset &&
                    usharpAsset.sourceCsScript != null &&
                    usharpAsset.sourceCsScript.GetClass() == pickupablePoolManagerType
                ) {
                    var pool = ub.GetComponent<VRCObjectPool>();
                    if (pool != null && pool.Pool != null)
                        foreach (var entry in pool.Pool)
                            if (entry != null)
                                entry.SetActive(false);
                }
        }
    }
#endif
}
