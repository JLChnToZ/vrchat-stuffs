/* A simple screen space reflection implementaion. (C) 2022 Jeremy Lam aka. Vistanz. Released under MIT license. */
Shader "JLChnToZ/SimpleSSR" {
    Properties {
        _Color ("Color Tint", Color) = (1, 1, 1, 1)
        _BumpMap ("Normal Map", 2D) = "bump" {}
        _NormalPower ("Normal Power", Range(0, 2)) = 1
        [IntRange] _MaxIteration ("Max Iteration", Range(20, 1000)) = 60
        _Threshold ("Hit Threshold", Float) = 0.1
    }
    SubShader {
        Tags {
            "Queue" = "Transparent"
            "RenderType" = "Transparent"
            "IgnoreProjector" = "True"
        }
        LOD 100
        ZWrite off
        Blend One One

        GrabPass { }

        Pass {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog
            #pragma target 3.0

            #include "UnityCG.cginc"
            #include "UnityImageBasedLighting.cginc"

            struct appdata {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float2 uv : TEXCOORD0;
            };

            struct v2f {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 position : TEXCOORD1;
                float3 normal : TEXCOORD2;
                float3 binormal : TEXCOORD3;
                float3 tangent : TEXCOORD4;
                UNITY_FOG_COORDS(5)
            };

            float4 _Color;
            sampler2D _CameraDepthTexture;
            sampler2D _GrabTexture;
            sampler2D _BumpMap;
            float4 _BumpMap_ST;
            float _NormalPower;
            float _Threshold;
            int _MaxIteration;

            #if UNITY_SPECCUBE_BOX_PROJECTION
            #define BOX_PROJECTION(dir, pos, idx) boxProjection(dir, pos, unity_SpecCube##idx##_ProbePosition, unity_SpecCube##idx##_BoxMin, unity_SpecCube##idx##_BoxMax)
            float3 boxProjection(float3 direction, float3 position, float4 cubePos, float3 boxMin, float3 boxMax) {
                UNITY_BRANCH
                if (cubePos.w > 0) {
                    const float3 factors = ((direction > 0 ? boxMax : boxMin) - position) / direction;
                    direction = direction * min(min(factors.x, factors.y), factors.z) + position - cubePos;
                }
                return direction;
            }
            #else
            #define BOX_PROJECTION(dir, pos, idx) dir
            #endif

            half3 getReflectedColor(float3 position, float3 reflectedDir, float roughness) {
                Unity_GlossyEnvironmentData envData;
                envData.roughness = (1.7 - 0.7 * roughness) * roughness;
                envData.reflUVW = BOX_PROJECTION(reflectedDir, position, 0);
                half3 probe = Unity_GlossyEnvironment(UNITY_PASS_TEXCUBE(unity_SpecCube0), unity_SpecCube0_HDR, envData);
                #if UNITY_SPECCUBE_BLENDING
                UNITY_BRANCH
                if (unity_SpecCube0_BoxMin.w < 0.99999) {
                    #if UNITY_SPECCUBE_BOX_PROJECTION
                    envData.reflUVW = BOX_PROJECTION(reflectedDir, position, 1);
                    #endif
                    probe = lerp(
                        Unity_GlossyEnvironment(
                            UNITY_PASS_TEXCUBE_SAMPLER(unity_SpecCube1, unity_SpecCube0),
                            unity_SpecCube1_HDR, envData
                        ),
                        probe, unity_SpecCube0_BoxMin.w
                    );
                }
                #endif
                return probe;
            }

            float4 screenProjCoordLod(float3 position) {
                float4 clipPos = mul(UNITY_MATRIX_VP, float4(position, 1));
                float4 screenPos = ComputeScreenPos(clipPos);
                screenPos = UNITY_PROJ_COORD(screenPos);
                return float4(screenPos.xy / screenPos.w, 0, 0);
            }

            half3 calcSSR(float3 position, float3 normal) {
                float3 startPos = position;
                float3 inDir = normalize(position - _WorldSpaceCameraPos);
                float3 reflectedDir = normalize(reflect(inDir, normal));
                float threshold = (1 + dot(inDir, normal)) * _Threshold;
                float3 ray = reflectedDir * threshold;
                half3 refl = getReflectedColor(position, reflectedDir, 0); // Base color from blended reflection probe.
                [fastopt] for (int i = 0; i < _MaxIteration; i++) {
                    position += ray;
                    float4 screenPos = screenProjCoordLod(position);
                    if (any(screenPos.xy < 0 || screenPos.xy > 1)) break; // Stop tracing when the ray already shoot to outside of the screen, and prevent color from clamped position popping out.
                    if (length(
                            LinearEyeDepth(tex2Dlod(_CameraDepthTexture, screenPos).x) +
                            mul(UNITY_MATRIX_V, float4(position, 1)).z
                        ) < threshold) {
                        half4 refl2 = tex2Dlod(_GrabTexture, screenPos);
                        return lerp(
                            refl, refl2.rgb,
                            refl2.a * (1 - sqrt(float(i) / float(_MaxIteration))) * (1 - smoothstep(0, 0.5, max(abs(screenPos.x - 0.5), abs(screenPos.y - 0.5)))) / (1 + length(startPos - position))
                        );
                    }
                }
                return refl;
            }

            v2f vert(appdata v) {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.position = mul(unity_ObjectToWorld, v.vertex);
                o.normal = normalize(mul((float3x3)unity_ObjectToWorld, v.normal));
                o.binormal = normalize(mul((float3x3)unity_ObjectToWorld, cross(v.normal, v.tangent.xyz) * v.tangent.w));
                o.tangent = normalize(mul((float3x3)unity_ObjectToWorld, v.tangent));
                o.uv = TRANSFORM_TEX(v.uv, _BumpMap);
                UNITY_TRANSFER_FOG(o, o.vertex);
                return o;
            }

            half4 frag(v2f i) : SV_Target {
                float3x3 TBN = transpose(float3x3(i.tangent, i.binormal, i.normal));
                float3 normal = UnpackNormal(lerp(float4(0.5, 0.5, 1, 1), tex2D(_BumpMap, i.uv), _NormalPower));
                half4 col = half4(calcSSR(i.position, mul(TBN, normal)), 1) * _Color;
                col.rgb *= col.a;
                col.a = saturate(col.r * col.g * col.b);
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}
