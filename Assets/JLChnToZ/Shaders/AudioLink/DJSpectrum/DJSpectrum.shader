// DJ Booth Like Spectrum Graph Shader
Shader "Unlit/AudioLinkDJSpectrum" {
    Properties {
        [PerRendererData][HideInInspector] _MainTex ("Unused", 2D) = "white" {}
        [HDR] _Color1 ("Bass Color", Color) = (0, .25, .75, 1)
        [HDR] _Color2 ("Low Mid Color", Color) = (0, .5, .25, 1)
        [HDR] _Color3 ("High Hid Color", Color) = (.25, .5, 0, 1)
        [HDR] _Color4 ("Treble Color", Color) = (.75, .25, 0, 1)
    }
    SubShader {
        Tags { "RenderType" = "Opaque" }
        LOD 100

        Pass {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"
            #include "Packages/com.llealloo.audiolink/Runtime/Shaders/AudioLink.cginc"
            #define AVG_SIZE 128

            half4 _Color1;
            half4 _Color2;
            half4 _Color3;
            half4 _Color4;

            struct appdata {
                float4 vertex: POSITION;
                float2 uv: TEXCOORD0;
            };

            struct v2f {
                float2 uv: TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex: SV_POSITION;
            };

            v2f vert(appdata v) {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                UNITY_TRANSFER_FOG(o, o.vertex);
                return o;
            }

            fixed4 frag(v2f i): SV_Target {
                float offset = (1 - i.uv.x) * AUDIOLINK_WIDTH;
                float4 curr = float4(
                    AudioLinkLerp(ALPASS_AUDIOLINK + float2(offset, 0)).r,
                    AudioLinkLerp(ALPASS_AUDIOLINK + float2(offset, 1)).r,
                    AudioLinkLerp(ALPASS_AUDIOLINK + float2(offset, 2)).r,
                    AudioLinkLerp(ALPASS_AUDIOLINK + float2(offset, 3)).r
                );
                float v = abs(i.uv.y * 2 - 1);
                float4 vz = 1 - sqrt(saturate(1 + v - curr));
                fixed4 col = fixed4(0, 0, 0, 1) + 2 * fixed4(
                    lerp(0, _Color1.rgb, vz.x) +
                    lerp(0, _Color2.rgb, vz.y) +
                    lerp(0, _Color3.rgb, vz.z) +
                    lerp(0, _Color4.rgb, vz.w),
                    0
                );
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}
