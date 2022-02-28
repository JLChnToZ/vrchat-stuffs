Shader "Unlit/FrameRateIndicator" {
	Properties {
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

			#include "UnityCG.cginc"

			static const float4 K_HSV2RGB = float4(1, 2. / 3., 1. / 3., 3);

			struct appdata {
				float4 vertex: POSITION;
				float4 normal: NORMAL;
			};

			struct v2f {
				float3 worldNorm: TEXCOORD0;
				float3 viewDir: TEXCOORD1;
				UNITY_FOG_COORDS(2)
				float4 vertex: SV_POSITION;
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
				return half4(lerp(0.64, 0, saturate(health)), 1, 1 - saturate(health - 0.8), intensity);
			}

			v2f vert(appdata v) {
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.worldNorm = mul(unity_ObjectToWorld, float4(v.normal.xyz, 0)).xyz;
				o.viewDir = mul(unity_CameraToWorld, float4(0, 0, 1, 0)).xyz;
				UNITY_TRANSFER_FOG(o, o.vertex);
				return o;
			}

			half4 frag(v2f i): SV_Target {
				float intensity = 1 - dot(i.worldNorm.xyz, i.viewDir.xyz);
				half4 col = healthColor(lerp(unity_DeltaTime.x, unity_DeltaTime.z, intensity) * 20, intensity);
				col = half4(hsv2rgb(col.xyz), saturate(intensity) / 2);
				UNITY_APPLY_FOG(i.fogCoord, col);
				return col;
			}
			ENDCG
		}
	}
}
