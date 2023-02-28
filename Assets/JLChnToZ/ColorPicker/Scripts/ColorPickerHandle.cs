using UdonSharp;
using UnityEngine;
using VRC.SDK3.Components;

namespace JLChnToZ.VRC.ColorPicker {
    [RequireComponent(typeof(VRCPickup))]
    [UdonBehaviourSyncMode(BehaviourSyncMode.None)]
    public class ColorPickerHandle : UdonSharpBehaviour {
        [SerializeField] float radius = 0.5F;
        [SerializeField] float height = 1F;
        [SerializeField] Transform indicator;
        UdonSharpBehaviour[] callbacks;
        int callbackCount;
        Renderer indicatorOrb;
        LineRenderer line;
        public Color selectedColor = Color.white;
        bool isDragging;
        MaterialPropertyBlock propertyBlock;

        void Start() {
            line = indicator.GetComponentInChildren<LineRenderer>();
            indicatorOrb = indicator.GetComponentInChildren<MeshRenderer>();
            if (indicatorOrb == null) indicatorOrb = indicator.GetComponentInChildren<SkinnedMeshRenderer>();
            propertyBlock = new MaterialPropertyBlock();
            line.useWorldSpace = false;
        }

        void Update() {
            indicator.SetPositionAndRotation(transform.position, transform.rotation);
            var pos = indicator.localPosition;
            var posXZ = new Vector2(pos.x, pos.z);
            posXZ = posXZ.normalized * Mathf.Clamp(posXZ.magnitude, 0, radius);
            pos.x = posXZ.x;
            pos.z = posXZ.y;
            pos.y = Mathf.Clamp(pos.y, 0, height);
            float h = Mathf.Repeat(Mathf.Atan2(pos.z, pos.x) / Mathf.PI / 2, 1);
            float s = posXZ.magnitude / radius;
            float v = 1 - pos.y / height;
            selectedColor = Color.HSVToRGB(h, s, v);
            indicator.localPosition = pos;
            if (line != null) {
                line.startColor = selectedColor;
                line.endColor = Color.HSVToRGB(h, s, 1);
                line.positionCount = 2;
                line.SetPosition(0, GetLinePos(pos));
                pos.y = 0;
                line.SetPosition(1, GetLinePos(pos));
            }
            indicatorOrb.GetPropertyBlock(propertyBlock);
            propertyBlock.SetColor("_Color", selectedColor);
            indicatorOrb.SetPropertyBlock(propertyBlock);
        }

        Vector3 GetLinePos(Vector3 pos) {
            return line.transform.InverseTransformPoint(indicator.parent.TransformPoint(pos));
        }

        public override void OnPickup() {
            isDragging = true;
        }

        public override void OnDrop() {
            isDragging = false;
            transform.SetPositionAndRotation(indicator.position, indicator.rotation);
            if (callbacks != null)
                foreach (var callback in callbacks)
                    if (callback == null) callback.SendCustomEvent("ColorChanged");
        }

        public void SetColor(Color newColor) {
            float h, s, v;
            Color.RGBToHSV(newColor, out h, out s, out v);
            h *= Mathf.PI * 2;
            s *= radius;
            v = (1 - v) * height;
            indicator.localPosition = new Vector3(Mathf.Cos(h) * s, v, Mathf.Sin(h) * s);
            selectedColor = newColor;
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
    }
}