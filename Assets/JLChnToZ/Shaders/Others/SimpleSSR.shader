/* A simple screen space reflection implementaion. (C) 2022 Jeremy Lam aka. Vistanz. Released under MIT license. */
Shader "JLChnToZ/SimpleSSR" {
    Properties {
        _Color ("Color Tint", Color) = (1, 1, 1, 1)
        _BumpMap ("Normal Map", 2D) = "bump" {}
        _NormalPower ("Normal Power", Range(0, 2)) = 1
        [IntRange] _MaxIteration ("Max Iteration", Range(20, 1000)) = 60
        _Size ("Reflection Size", Range(0, 10)) = 1
        _Fade ("Fade Intensity", Range(0, 0.5)) = 0
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
            #include "UnityStandardUtils.cginc"
            #include "UnityImageBasedLighting.cginc"

            struct v2f {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 position : TEXCOORD1;
                float3 normal : TEXCOORD2;
                float3 binormal : TEXCOORD3;
                float3 tangent : TEXCOORD4;
                UNITY_FOG_COORDS(5)
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            float4 _Color;
            UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);
            sampler2D _GrabTexture;
            sampler2D _BumpMap;
            float4 _BumpMap_ST;
            float _NormalPower;
            float _Size;
            float _Fade;
            int _MaxIteration;

            #if UNITY_SPECCUBE_BOX_PROJECTION
            #define BOX_PROJECTION(dir, pos, idx) boxProjection(dir, pos, unity_SpecCube##idx##_ProbePosition, unity_SpecCube##idx##_BoxMin, unity_SpecCube##idx##_BoxMax)
            float3 boxProjection(float3 direction, float3 position, float4 cubePos, float3 boxMin, float3 boxMax) {
                UNITY_BRANCH if (cubePos.w > 0) {
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
                UNITY_BRANCH if (unity_SpecCube0_BoxMin.w < 1) {
                    #if UNITY_SPECCUBE_BOX_PROJECTION
                    envData.reflUVW = BOX_PROJECTION(reflectedDir, position, 1);
                    #endif
                    return lerp(
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
                float4 screenPos = ComputeScreenPos(mul(UNITY_MATRIX_VP, float4(position, 1)));
                screenPos = UNITY_PROJ_COORD(screenPos);
                return float4(screenPos.xy / screenPos.w, 0, 0);
            }

            half3 calcSSR(float3 position, float3 normal) {
                float3 startPos = position;
                // Calculate the ray direction from camera to current surface.
                float3 inDir = normalize(position - _WorldSpaceCameraPos);
                // Calculate the reflection direction from the ray and nornmal.
                float3 reflectedDir = normalize(reflect(inDir, normal));
                // Adjust the threshold with the angle, distance from the camera and max iteration count.
                float threshold = (1 + dot(inDir, normal)) * length(position - _WorldSpaceCameraPos) * _Size / _MaxIteration;
                float3 ray = reflectedDir * threshold;
                // Grab base color from blended reflection probe.
                half3 refl = getReflectedColor(position, reflectedDir, 0);
                [fastopt] for (int i = 0; i < _MaxIteration; i++) {
                    position += ray;
                    float4 screenPos = screenProjCoordLod(position);
                    // Single Pass Stereo Support
                    #if UNITY_SINGLE_PASS_STEREO
                    float4 scaleOffset = unity_StereoScaleOffset[unity_StereoEyeIndex];
                    float2 screenPosSingleEye = (screenPos.xy - scaleOffset.zw) / scaleOffset.xy;
                    #else
                    float2 screenPosSingleEye = screenPos;
                    #endif
                    // If the ray is already shoot to outside of the screen, discard the tracing routine.
                    UNITY_BRANCH if (any(screenPosSingleEye < 0 || screenPosSingleEye > 1)) break;
                    // Compare the screen space depth with the ray, treat as hitting the other surface when it is close enough.
                    UNITY_BRANCH if (length(
                        LinearEyeDepth(SAMPLE_DEPTH_TEXTURE_LOD(_CameraDepthTexture, screenPos).x) + // Camera depth buffer at the position
                        mul(UNITY_MATRIX_V, float4(position, 1)).z // Current camera depth where the ray shoot to
                    ) < threshold) {
                        // Get the color at the screen position.
                        half4 refl2 = tex2Dlod(_GrabTexture, screenPos);
                        // Calculate the screen space distance to the edge for fading.
                        screenPosSingleEye = (screenPosSingleEye - 0.5) * sign((screenPos - screenProjCoordLod(position - ray)).xy);
                        return lerp(
                            refl, refl2.rgb, refl2.a
                            * (1 - sqrt((float)i / _MaxIteration)) // Fade out for high iteration steps.
                            * (1 - smoothstep(_Fade, 0.5, max(screenPosSingleEye.x, screenPosSingleEye.y))) // Fade out for close to screen edge.
                            / (1 + length(startPos - position)) // Fade out for reaching too far.
                        );
                    }
                }
                return refl;
            }

            v2f vert(appdata_tan v) {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.position = mul(unity_ObjectToWorld, v.vertex);
                o.normal = normalize(mul((float3x3)unity_ObjectToWorld, v.normal));
                o.binormal = normalize(mul((float3x3)unity_ObjectToWorld, cross(v.normal, v.tangent.xyz) * v.tangent.w));
                o.tangent = normalize(mul((float3x3)unity_ObjectToWorld, v.tangent));
                o.uv = TRANSFORM_TEX(v.texcoord, _BumpMap);
                UNITY_TRANSFER_FOG(o, o.vertex);
                return o;
            }

            half4 frag(v2f i) : SV_Target {
                UNITY_SETUP_INSTANCE_ID(i);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
                half4 col = half4(calcSSR(i.position, mul(
                    transpose(float3x3(i.tangent, i.binormal, i.normal)),
                    UnpackScaleNormal(tex2D(_BumpMap, i.uv), _NormalPower)
                )), 1) * _Color;
                col.rgb *= col.a;
                col.a = saturate(col.r * col.g * col.b);
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}
