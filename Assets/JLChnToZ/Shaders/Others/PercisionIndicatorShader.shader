// This is a shader for checking is the precision "healthy" at the coordinate it is in.
// When it shows orange, red, purplish or even black means the precision is not accurate and will cause jittering.
// Frame Rate option is for adding frame rate as a "healthy consideration", low frame rate will make the color tint towards red / black.
// DDynamic option is to to make it raves, although it is designed as an eye candy effect, it intentionally coded to moves towards positive quadrant so it could be act as compass in some cases.
Shader "Unlit/PercisionIndicator" {
	Properties {
		[Toggle(_DYNAMIC)] _Dynamic ("Dynamic", Int) = 0
		[Toggle(_FRAMERATE)] _FrameRate ("Frame Rate", Int) = 0
		[Toggle(_RMAXIS)] _RmAxis ("XYZ Compass (Raymarching)", Int) = 0
		_RmAxisSize ("Compass Size", Float) = 0.005
		[Enum(UnityEngine.Rendering.CullMode)] _Cull ("Culling", Float) = 2
		[Enum(UnityEngine.Rendering.CompareFunction)] _ZTest ("Z Test", Float) = 4
		[Toggle] _ZWrite ("Z Write", Int) = 1
		[Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend ("Source Blend", Int) = 1
		[Enum(UnityEngine.Rendering.BlendMode)] _DstBlend ("Destination Blend", Int) = 10
	}
	SubShader {
		Tags {
			"Queue" = "Transparent"
			"IgnoreProjector" = "True"
			"RenderType" = "Transparent"
			"VRCFallback" = "Hidden"
		}
		LOD 100
		ZTest [_ZTest]
		ZWrite [_ZWrite]
		Cull [_Cull]
		Blend [_SrcBlend] [_DstBlend]

		Pass {
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fog
			#pragma shader_feature_local _DYNAMIC
			#pragma shader_feature_local _FRAMERATE
			#pragma shader_feature_local _RMAXIS

			#include "UnityCG.cginc"

			static const float4 K_HSV2RGB = float4(1, 2. / 3., 1. / 3., 3);

			#if _RMAXIS
			float _RmAxisSize;
			#endif

			struct appdata {
				float4 vertex: POSITION;
				float4 normal: NORMAL;
			};

			struct v2f {
				float4 vertex: SV_POSITION;
				float3 worldPos: TEXCOORD0;
				float3 worldNorm: TEXCOORD1;
				UNITY_FOG_COORDS(2)
				#ifdef _FRAMERATE
				float3 viewDir: TEXCOORD3;
				#endif
				#ifdef _RMAXIS
				float3 vertWorldPos: TEXCOORD4;
				#endif
			};

			half3 hsv2rgb(half3 c) {
				half3 p = abs(frac(c.xxx + K_HSV2RGB.xyz) * 6 - K_HSV2RGB.www);
				return c.z * lerp(K_HSV2RGB.xxx, saturate(p - K_HSV2RGB.xxx), c.y);
			}

			half3 healthColor(half health) {
				return half3(lerp(0.64, -0.31, saturate(health)), 1, 1 - saturate(health * 2 - 0.75));
			}

			v2f vert(appdata v) {
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.worldPos = mul(unity_ObjectToWorld, float4(0, 0, 0, 1));
				o.worldNorm = mul(unity_ObjectToWorld, float4(v.normal.xyz, 0));
				#ifdef _FRAMERATE
				o.viewDir = mul(unity_CameraToWorld, float4(0, 0, 1, 0));
				#endif
				#if _RMAXIS
				o.vertWorldPos = mul(unity_ObjectToWorld, v.vertex);
				#endif
				UNITY_TRANSFER_FOG(o, o.vertex);
				return o;
			}

			half4 frag(v2f i): SV_Target {
				half3 health = log2(abs(i.worldPos)) / 10 - 0.5;
				half3 norm = i.worldNorm;
				norm = 1 - sqrt(1 - norm * norm);
				norm *= saturate(i.worldNorm * i.worldPos) / dot(norm, 1);
				#ifdef _DYNAMIC
				norm += (sin(i.worldNorm * 3.1 - _Time.w + half3(0, 2.1, 4.2)) + 1) / 20;
				#endif
				half4 col = half4(health * norm, dot(norm, 1));
				#ifdef _FRAMERATE
				col += lerp(unity_DeltaTime.z, unity_DeltaTime.x, dot(i.worldNorm, i.viewDir)) * half4(2, 2, 2, 10);
				#endif
				col = half4(hsv2rgb(healthColor(col.x + col.y + col.z)), saturate(col.w));
				#if _RMAXIS
				half3 pos = _WorldSpaceCameraPos;
				half3 viewDir = normalize(i.vertWorldPos - pos);
				half4 axisSize = _RmAxisSize * half4(1, distance(pos, i.worldPos).xxx) * half4(1000, 1, 2, 5);
				[fastopt] for (int x = 0; x < 20; x++) {
					half3 dist = half3(
						distance(pos.yz, i.worldPos.yz),
						distance(pos.xz, i.worldPos.xz),
						distance(pos.xy, i.worldPos.xy)
					);
					if (any(dist.xyz < axisSize.z)) {
						half3 axis = smoothstep(axisSize.w, axisSize.y, dist);
						col = lerp(col, half4(axis, 1), length(frac(pos * axisSize.x - _Time.y) * axis));
						break;
					}
					pos += viewDir * min(min(dist.x, dist.y), dist.z);
				}
				#endif
				UNITY_APPLY_FOG(i.fogCoord, col);
				return col;
			}
			ENDCG
		}
	}
}
