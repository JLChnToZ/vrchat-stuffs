using UdonSharp;
using UnityEngine;
using VRC.SDK3.Components;
using VRC.SDKBase;

namespace JLChnToZ.VRC.ColorPicker {
    [RequireComponent(typeof(VRCPickup))]
    [UdonBehaviourSyncMode(BehaviourSyncMode.Continuous)]
    public class ColorPickerHandle : UdonSharpBehaviour {
        const float TWO_PI = Mathf.PI * 2;
        [SerializeField] float radius = 0.5F;
        [SerializeField] float height = 1F;
        [SerializeField] Transform indicator;
        [SerializeField] bool isGlobal;
        [SerializeField] Color color = Color.white;
        UdonSharpBehaviour[] callbacks;
        int callbackCount;
        Renderer indicatorOrb;
        LineRenderer line;
        VRCPickup pickup;
        [UdonSynced] Color syncedColor;
        [UdonSynced] bool syncedDragging;
        bool isRemoteDragging;
        bool isDragging;
        MaterialPropertyBlock propertyBlock;

        public Color SelectedColor {
            get => color;
            set {
                if (!Networking.IsOwner(gameObject))
                    Networking.SetOwner(Networking.LocalPlayer, gameObject);
                color = value;
                UpdateColor();
            }
        }

        void Start() {
            line = indicator.GetComponentInChildren<LineRenderer>(true);
            indicatorOrb = indicator.GetComponentInChildren<MeshRenderer>(true);
            if (indicatorOrb == null) indicatorOrb = indicator.GetComponentInChildren<SkinnedMeshRenderer>(true);
            pickup = (VRCPickup)GetComponent(typeof(VRCPickup));
            propertyBlock = new MaterialPropertyBlock();
            line.useWorldSpace = false;
            if (isGlobal) syncedColor = color;
        }

        void OnEnable() => UpdatePickupable();

        void Update() {
            indicator.SetPositionAndRotation(transform.position, transform.rotation);
            var pos = indicator.localPosition;
            var posXZ = new Vector2(pos.x, pos.z);
            posXZ = posXZ.normalized * Mathf.Clamp(posXZ.magnitude, 0, radius);
            pos.x = posXZ.x;
            pos.z = posXZ.y;
            pos.y = Mathf.Clamp(pos.y, 0, height);
            float h = Mathf.Repeat(Mathf.Atan2(pos.z, pos.x) / TWO_PI, 1);
            float s = posXZ.magnitude / radius;
            float v = 1 - pos.y / height;
            SelectedColor = Color.HSVToRGB(h, s, v);
            indicator.localPosition = pos;
            if (line != null) {
                line.startColor = color;
                line.endColor = Color.HSVToRGB(h, s, 1);
                line.positionCount = 2;
                line.SetPosition(0, GetLinePos(pos));
                pos.y = 0;
                line.SetPosition(1, GetLinePos(pos));
            }
            indicatorOrb.GetPropertyBlock(propertyBlock);
            propertyBlock.SetColor("_Color", color);
            indicatorOrb.SetPropertyBlock(propertyBlock);
        }

        Vector3 GetLinePos(Vector3 pos) {
            return line.transform.InverseTransformPoint(indicator.parent.TransformPoint(pos));
        }

        public override void OnPickup() {
            isDragging = true;
            if (isGlobal) {
                isRemoteDragging = true;
                syncedDragging = true;
            }
        }

        public override void OnDrop() {
            isDragging = false;
            if (isGlobal) {
                isRemoteDragging = false;
                syncedDragging = false;
            }
            UpdatePickupable();
            ColorChangeCallback();
        }

        public override void OnDeserialization() {
            if (!isGlobal) return;
            if (syncedColor != color) SelectedColor = color;
            if (isRemoteDragging != syncedDragging) {
                isRemoteDragging = syncedDragging;
                if (!syncedDragging) ColorChangeCallback();
            }
            UpdatePickupable();
        }

        void UpdatePickupable() {
            pickup.pickupable = Networking.IsOwner(gameObject) || !syncedDragging;
            if (!syncedDragging) transform.SetPositionAndRotation(indicator.position, indicator.rotation);
        }

        public override void OnOwnershipTransferred(VRCPlayerApi player) {
            if (player.isLocal) pickup.pickupable = true;
        }

        public void UpdateColor() {
            float h, s, v;
            Color.RGBToHSV(color, out h, out s, out v);
            h *= TWO_PI;
            s *= radius;
            v = (1 - v) * height;
            indicator.localPosition = new Vector3(Mathf.Sin(h) * s, v, Mathf.Cos(h) * s);
            if (!isDragging) OnDrop();
        }

        public void RegisterCallback(UdonSharpBehaviour ub) {
            if (callbacks == null)
                callbacks = new UdonSharpBehaviour[10];
            else if (callbacks.Length <= callbackCount) {
                var temp = new UdonSharpBehaviour[callbacks.Length + 10];
                System.Array.Copy(callbacks, temp, callbackCount);
                callbacks = temp;
            }
            callbacks[callbackCount++] = ub;
        }

        void ColorChangeCallback() {
            if (callbacks != null)
                foreach (var callback in callbacks)
                    if (callback == null) callback.SendCustomEvent("ColorChanged");
        }
    }
}