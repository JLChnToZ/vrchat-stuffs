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
using System.Threading.Tasks;
using UnityEditor;
using UdonSharpEditor;
#endif

namespace JLChnToZ.VRC {
    [UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
    [RequireComponent(typeof(VRCObjectPool))]
    public class PickupablePoolManager: UdonSharpBehaviour {
        VRCObjectPool objectPool;
        bool hasShuffled;
        [UdonSynced] bool hasDrain;

        void Start() {
            objectPool = (VRCObjectPool)GetComponent(typeof(VRCObjectPool));
        }

        public override void OnPlayerJoined(VRCPlayerApi player) {
            if (player.isLocal && Networking.IsOwner(player, gameObject)) DoSpawn();
        }

        public override void OnOwnershipTransferred(VRCPlayerApi player) {
            if (player.isLocal) Shuffle();
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
            if (!Networking.IsOwner(returnObj)) Networking.SetOwner(Networking.GetOwner(gameObject), returnObj);
            objectPool.Return(returnObj);
            if (!hasDrain) return;
            hasDrain = false;
            RequestSerialization();
            SendCustomEventDelayedSeconds(nameof(SpawnNext), 1);
        }
    }

#if UNITY_EDITOR && !COMPILER_UDONSHARP
    [CustomEditor(typeof(PickupablePoolManager))]
    internal class PickupablePoolManagerEditor: Editor {
        float batchSetTime = 300;

        void OnEnable() {
            InitRespawnTime();
        }

        void InitRespawnTime() {
            var objPool = (target as Component).GetComponent<VRCObjectPool>();
            foreach (var obj in objPool.Pool)
                if (obj != null)
                    foreach (var udon in GetUdonBehaviours<PickupableManager>(obj))
                        if (udon.publicVariables.TryGetVariableValue("resetDuration", out batchSetTime))
                            return;
            batchSetTime = 300;
        }

        public override void OnInspectorGUI() {
            if (UdonSharpGUI.DrawDefaultUdonSharpBehaviourHeader(target)) return;
            EditorGUILayout.LabelField("Pickupable Pool Manager Utilities", EditorStyles.boldLabel);
            if (GUILayout.Button("Add all children with handlers to object pool")) DeferStart(AssignPickupableChildren);
            if (GUILayout.Button("Set references to all pooled objects")) DeferStart(AssignPickupable);
            EditorGUILayout.Space();
            EditorGUILayout.LabelField("Batch Set Auto Respawn", EditorStyles.boldLabel);
            EditorGUI.BeginChangeCheck();
            bool autoRespawn = EditorGUILayout.ToggleLeft("Enable Auto Respawn", !float.IsInfinity(batchSetTime));
            bool respawnChanged = EditorGUI.EndChangeCheck();
            if (autoRespawn) {
                if (respawnChanged) batchSetTime = 0;
                batchSetTime = EditorGUILayout.FloatField("Respawn Time", batchSetTime);
            } else if (respawnChanged)
                batchSetTime = float.PositiveInfinity;
            if (GUILayout.Button("Apply All")) DeferStart(AssignRespawnTime);
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
            foreach (var obj in objPool.Pool)
                if (obj != null)
                    foreach (var udon in GetUdonBehaviours<PickupableManager>(obj))
                        if (!TrySetOrAddVariable(udon, "poolManager", targetUb))
                            Debug.LogWarning($"Failed to assign {targetUb} as poolManager to {udon}.");
        }

        void AssignRespawnTime() {
            var targetComponent = target as Component;
            var objPool = targetComponent.GetComponent<VRCObjectPool>();
            foreach (var obj in objPool.Pool)
                if (obj != null)
                    foreach (var udon in GetUdonBehaviours<PickupableManager>(obj))
                        if (!TrySetOrAddVariable(udon, "resetDuration", batchSetTime))
                            Debug.LogWarning($"Failed to assign respawn time to {udon}.");
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

        static void RecordPrefabChangedIfNeeded(Component component) {
            if (PrefabUtility.IsPartOfPrefabInstance(component))
                PrefabUtility.RecordPrefabInstancePropertyModifications(component);
        }
    }
#endif
}
