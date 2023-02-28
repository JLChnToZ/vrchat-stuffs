Shader "Unlit/ColorPickerPalette" {
    Properties {}
    SubShader {
        Tags {
            "RenderType" = "Opaque"
            "PreviewType" = "Plane"
        }
        LOD 100
        Pass {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };

            float3 hsv2rgb(float3 hsv) {
                return hsv.z * lerp(1, saturate(abs(fmod(hsv.x * 6 + float3(0, 4, 2), 6) - 3) - 1), hsv.y);
            }

            v2f vert(appdata v) {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                UNITY_TRANSFER_FOG(o, o.vertex);
                return o;
            }

            float4 frag(v2f i) : SV_Target {
                float2 uv = (i.uv - 0.5) * 2;
                float3 hsv = float3(frac(atan2(uv.y, uv.x) * 0.16), length(uv), 1); // 0.16 ~= 1 / PI / 2
                if (hsv.y > 1) discard;
                float4 col = float4(hsv2rgb(hsv), 1);
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}
