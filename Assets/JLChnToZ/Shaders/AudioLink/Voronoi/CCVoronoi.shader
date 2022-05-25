// An attempt to recreate the Voronoi diagram shown in Color Chord 2 demo video, using pure CG (HLSL).
// https://youtu.be/UI4eqOP2AU0
// It uses internal data in AudioLink, tested with AudioLink v0.2.8.
Shader "Unlit/CCVoronoi" {
    SubShader {
        Tags {
            "RenderType" = "Opaque"
        }
        LOD 100

        Pass {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog

            #include "UnityCG.cginc"
            #include "Assets/AudioLink/Shaders/AudioLink.cginc"

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
                fixed4 col = 1;
                float4 summary = AudioLinkData(ALPASS_CCINTERNAL);
                float4 summaryB = AudioLinkData(ALPASS_CCINTERNAL + uint2(0, 1));
                float4 closestPeak = 0;
                float closestDistance = 2;
                float total = 0;
                int maxNotes = int(min(COLORCHORD_MAX_NOTES, summaryB.z));
                [loop] for (int x = 0; x < maxNotes; x++) {
                    float4 notesB = AudioLinkData(ALPASS_CCINTERNAL + int2(x + 1, 1));
                    if (notesB.y <= 0) continue;
                    float4 peak = AudioLinkData(ALPASS_CCINTERNAL + int2(notesB.z + 1, 0));
                    float power = peak.y / summary.y;
                    float2 targetUV;
                    sincos((total + power / 2) * 6.2832, targetUV.x, targetUV.y);
                    targetUV *= 0.5;
                    targetUV += 0.5;
                    total += power;
                    float dist = distance(targetUV, i.uv);
                    if (dist / (closestDistance + dist) < peak.y / (closestPeak.y + peak.y)) {
                        closestDistance = dist;
                        closestPeak = peak;
                    }
                }
                col.xyz = AudioLinkCCtoRGB(closestPeak.x, closestPeak.w, summaryB.y);
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}
