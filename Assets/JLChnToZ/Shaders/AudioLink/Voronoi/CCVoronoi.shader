// An attempt to recreate the Voronoi diagram shown in Color Chord 2 demo video, using pure CG (HLSL).
// https://youtu.be/UI4eqOP2AU0
// It uses internal data in AudioLink, tested with AudioLink v0.2.8.
Shader "Unlit/CCVoronoi" {
    Properties {
        [HDR] _Color ("Base Color", Color) = (0, 0, 0, 0)
        _Intensity ("Max Intensity", Float) = 1
        _MaxAlpha ("Max Alpha", Range(0, 1)) = 1
        _Smooth ("Smooth Edge", Float) = 0
        _Offset ("UV Offset (XY) Distance (Z)", Vector) = (0.5, 0.5, 0.5, 0)
    }
    SubShader {
        Tags {
            "RenderType" = "Transparent"
            "Queue" = "Transparent"
            "IgnoreProjector" = "True"
        }
        LOD 100
        Blend SrcAlpha OneMinusSrcAlpha

        Pass {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog

            #include "UnityCG.cginc"
            #include "Packages/com.llealloo.audiolink/Runtime/Shaders/AudioLink.cginc"

            #define TWO_PI 6.28318530718

            float _Intensity;
            float4 _Offset;
            float4 _Color;
            float _MaxAlpha;
            float _Smooth;

            struct appdata {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };

            v2f vert(appdata v) {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag(v2f i) : SV_Target {
                const float radPerNote = TWO_PI / AUDIOLINK_EXPBINS;
                float4 col = float4(0, 0, 0, 1);
                float4 summary = AudioLinkData(ALPASS_CCINTERNAL);
                float4 summaryB = AudioLinkData(ALPASS_CCINTERNAL + uint2(0, 1));
                float4 closestNote = 0;
                float closestDist = 2;
                [unroll(COLORCHORD_MAX_NOTES)] for (int x = 0; x < summaryB.z; x++) {
                    float4 notesB = AudioLinkData(ALPASS_CCINTERNAL + int2(x + 1, 1));
                    if (notesB.y <= 0) continue;
                    float4 note = AudioLinkData(ALPASS_CCINTERNAL + int2(notesB.z + 1, 0));
                    float2 targetUV;
                    sincos(note.x * radPerNote, targetUV.x, targetUV.y);
                    float dist = distance(targetUV * _Offset.z + _Offset.xy, i.uv);
                    float val = smoothstep(-_Smooth, _Smooth, note.y / (closestNote.y + note.y) - dist / (closestDist + dist));
                    if (val > 0) {
                        closestNote = lerp(closestNote, note, val);
                        closestDist = lerp(closestDist, dist, val);
                        col.rgb = lerp(col.rgb, AudioLinkCCtoRGB(note.x, pow(note.w, _Intensity), summaryB.y), val);
                    }
                }
                col.rgb = _Color.rgb + col.rgb * _Intensity;
                col.a = saturate(lerp(_Color.a, _MaxAlpha, closestNote.w));
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}
