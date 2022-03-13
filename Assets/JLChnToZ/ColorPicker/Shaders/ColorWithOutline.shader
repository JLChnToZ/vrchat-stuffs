Shader "Unlit/ColorWithOutline" {
    Properties {
        _Color ("Color", Color) = (1, 1, 1, 1)
        _OutlineThickness ("Outline Thickness", Range(0, 0.1)) = 0.03
    }

    SubShader {
        Tags { "RenderType" = "Opaque" }
        LOD 100

        Stencil {
            Ref 0
            Comp Equal
            Pass IncrSat
            Fail keep
            ZFail keep
        }

        CGINCLUDE
        #pragma vertex vert
        #pragma fragment frag
        #pragma multi_compile_fog

        #include "UnityCG.cginc"

        struct v2f {
            UNITY_FOG_COORDS(0)
            float4 vertex : SV_POSITION;
        };

        float4 _Color;
        ENDCG

        Pass {
            CGPROGRAM
            struct appdata {
                float4 vertex : POSITION;
            };

            v2f vert (appdata v) {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                UNITY_TRANSFER_FOG(o, o.vertex);
                return o;
            }

            fixed4 frag(v2f i) : SV_Target {
                fixed4 col = _Color;
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
        Pass {
            CGPROGRAM
            struct appdata {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };
            
            float _OutlineThickness;

            v2f vert (appdata v) {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex + normalize(v.normal) * _OutlineThickness);
                UNITY_TRANSFER_FOG(o, o.vertex);
                return o;
            }

            fixed4 frag(v2f i) : SV_Target {
                fixed4 col = fixed4(1 - _Color.rgb, 1);
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}
