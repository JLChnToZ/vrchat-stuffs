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
        const long customEpoch = 637134336000000000L; // 01/01/2020 00:00 UTC
        const float ticksPerSecond = System.TimeSpan.TicksPerSecond;
        [SerializeField] PickupablePoolManager poolManager;
        [Tooltip("Auto respawns if no one touched it for certain time.")]
        [SerializeField] float resetDuration = 300F;
        [Tooltip("If this object is physics controlled and it is moved too far away to this threshold value before pickuped by someone, it will automatically go back to spawn point. It requires custom spawn target in order to work. Can set to -1 to disable.")]
        [SerializeField] float respawnDistance = -1;
        [SerializeField] Transform customSpawnTarget;
        [UdonSynced] bool hasPickuped;
        [UdonSynced] float resetTime = float.PositiveInfinity;
        VRCObjectSync objSync;
        new Rigidbody rigidbody;
        bool isPickingUp;

        float CurrentTime => (Networking.GetNetworkDateTime().Ticks - customEpoch) / ticksPerSecond;

        void Start() {
            if (poolManager == null) {
                poolManager = GetComponentInParent<PickupablePoolManager>();
                if (poolManager == null)
                    Debug.LogError("Object pool is not defined, pickupable manager will not work properly.");
            }
            rigidbody = GetComponent<Rigidbody>();
        }

        void OnEnable() {
            if (!hasPickuped && Networking.IsOwner(gameObject) && customSpawnTarget != null)
                transform.SetPositionAndRotation(customSpawnTarget.position, customSpawnTarget.rotation);
        }

        public override void OnSpawn() {
            if (objSync == null) objSync = (VRCObjectSync)GetComponent(typeof(VRCObjectSync));
            if (Networking.IsOwner(gameObject)) {
                objSync.Respawn();
                if (customSpawnTarget != null)
                    transform.SetPositionAndRotation(customSpawnTarget.position, customSpawnTarget.rotation);
                hasPickuped = false;
                ResetTimer();
            }
            gameObject.SetActive(true);
            isPickingUp = false;
        }

        void Update() {
            if (!Networking.IsOwner(gameObject)) return;
            if (hasPickuped) {
                if (!isPickingUp && resetTime <= CurrentTime)
                    SendCustomNetworkEvent(NetworkEventTarget.All, nameof(ReturnToPool));
                return;
            }
            if (respawnDistance >= 0 &&
                !rigidbody.isKinematic &&
                customSpawnTarget != null &&
                Vector3.Distance(customSpawnTarget.position, transform.position) >= respawnDistance
            ) OnSpawn();
        }

        public override void OnPickup() {
            if (!hasPickuped) {
                hasPickuped = true;
                poolManager.AutoSpawnNext();
            }
            isPickingUp = true;
            resetTime = float.PositiveInfinity;
        }

        public override void OnDrop() {
            isPickingUp = false;
            ResetTimer();
        }

        void ResetTimer() => resetTime = resetDuration > 0 ?
            CurrentTime + resetDuration :
            float.PositiveInfinity;

        public void ReturnToPool() {
            isPickingUp = false;
            hasPickuped = false;
            resetTime = float.PositiveInfinity;
            gameObject.SetActive(false);
            poolManager._ReturnToPool(gameObject);
        }
    }
}
