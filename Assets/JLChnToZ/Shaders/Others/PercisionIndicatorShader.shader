// This is a shader for checking is the precision "healthy" at the coordinate it is in.
// When it shows orange, red, purplish or even black means the precision is not accurate and will cause jittering.
// Frame Rate option is for adding frame rate as a "healthy consideration", low frame rate will make the color result towards red / black.
// Dynamic option is to to make it raves, although it is only an eye candy effect.
Shader "Unlit/PercisionIndicator" {
	Properties {
		[Toggle(_DYNAMIC)] _Dynamic ("Dynamic", Int) = 0
		[Toggle(_FRAMERATE)] _FrameRate ("Frame Rate", Int) = 0
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
			#pragma multi_compile __ _DYNAMIC
			#pragma multi_compile __ _FRAMERATE

			#include "UnityCG.cginc"

			static const float4 K_HSV2RGB = float4(1, 2. / 3., 1. / 3., 3);

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
			};

			half3 hsv2rgb(half3 c) {
				half3 p = abs(frac(c.xxx + K_HSV2RGB.xyz) * 6 - K_HSV2RGB.www);
				return c.z * lerp(K_HSV2RGB.xxx, saturate(p - K_HSV2RGB.xxx), c.y);
			}

			half4 alphaBlend(half4 d, half4 s) {
				half4 o;
				o.a = s.a + d.a * (1 - s.a);
				o.rgb = (s.rgb * s.a + d.rgb * d.a * (1 - s.a)) / o.a;
				return o;
			}

			half4 healthColor(half health, half intensity) {
				return half4(lerp(0.64, -0.31, saturate(health)), 1, 1 - saturate(health - 0.25), intensity);
			}

			v2f vert(appdata v) {
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.worldPos = mul(unity_ObjectToWorld, v.vertex);
				#ifdef _FRAMERATE
				o.viewDir = mul(unity_CameraToWorld, float4(0, 0, 1, 0)).xyz;
				#endif
				o.worldNorm = mul(unity_ObjectToWorld, float4(v.normal.xyz, 0)).xyz;
				UNITY_TRANSFER_FOG(o, o.vertex);
				return o;
			}

			half4 frag(v2f i): SV_Target {
				float3 health = log2(abs(i.worldPos)) / 10 - 0.5;
				half3 norm = abs(normalize(i.worldNorm));
				norm = 1 - sqrt(1 - norm * norm);
				norm *= saturate(half3(sign(i.worldNorm)) * half3(sign(i.worldPos))) /  dot(norm, 1);
				#ifdef _DYNAMIC
				half3 vibe = sin(i.worldNorm * 3.1 + _Time.w + half3(0, 2.1, 4.19)) + 1;
				if (any(abs(vibe) > 0)) vibe /= dot(vibe, 1);
				norm = max(0, norm - vibe / 10);
				#endif
				#ifdef _FRAMERATE
				health += lerp(unity_DeltaTime.x, unity_DeltaTime.z, 1 - dot(i.worldNorm.xyz, i.viewDir.xyz)) * 10;
				#endif
				half4 col = healthColor(health.x, norm.x);
				col = alphaBlend(col, healthColor(health.y, norm.y));
				col = alphaBlend(col, healthColor(health.z, norm.z));
				col = half4(hsv2rgb(col.xyz), dot(norm, 1));
				UNITY_APPLY_FOG(i.fogCoord, col);
				return col;
			}
			ENDCG
		}
	}
}
