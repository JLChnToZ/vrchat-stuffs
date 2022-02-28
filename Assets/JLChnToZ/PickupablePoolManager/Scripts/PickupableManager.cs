using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.SDK3.Components;
using VRC.Udon.Common.Interfaces;

namespace JLChnToZ.VRC {
    [UdonBehaviourSyncMode(BehaviourSyncMode.Continuous)]
    [RequireComponent(typeof(VRCObjectSync))]
    [RequireComponent(typeof(VRCPickup))]
    public class PickupableManager: UdonSharpBehaviour {
        [SerializeField] PickupablePoolManager poolManager;
        [SerializeField] float resetDuration = 300F;
        [UdonSynced] bool hasPickuped;
        [UdonSynced] float resetTimeLeft = float.PositiveInfinity;
        VRCObjectSync objSync;
        bool isPickingUp;

        void Start() {
            if (poolManager == null) {
                poolManager = GetComponentInParent<PickupablePoolManager>();
                if (poolManager == null)
                    Debug.LogError("Object pool is not defined, pickupable manager will not work properly.");
            }
        }

        public override void OnSpawn() {
            if (objSync == null) objSync = (VRCObjectSync)GetComponent(typeof(VRCObjectSync));
            if (Networking.IsOwner(gameObject)) {
                objSync.Respawn();
                hasPickuped = false;
                ResetTimer();
            }
            gameObject.SetActive(true);
            isPickingUp = false;
        }

        void Update() {
            if (!Networking.IsOwner(gameObject)) return;
            if (hasPickuped && !isPickingUp && resetTimeLeft > 0) {
                resetTimeLeft -= Time.deltaTime;
                if (resetTimeLeft <= 0) _BroadcastReturnToPool();
            }
        }

        public override void OnPickup() {
            if (!hasPickuped) {
                hasPickuped = true;
                poolManager.SpawnNext();
            }
            isPickingUp = true;
            resetTimeLeft = float.PositiveInfinity;
        }

        public override void OnDrop() {
            isPickingUp = false;
            ResetTimer();
        }

        void ResetTimer() => resetTimeLeft = resetDuration > 0 ? resetDuration : float.PositiveInfinity;

        public void _BroadcastReturnToPool() {
            ReturnToPool();
            SendCustomNetworkEvent(NetworkEventTarget.All, nameof(ReturnToPool));
        }

        public void ReturnToPool() {
            isPickingUp = false;
            hasPickuped = false;
            resetTimeLeft = float.PositiveInfinity;
            gameObject.SetActive(false);
            poolManager._ReturnToPool(gameObject);
        }
    }
}
