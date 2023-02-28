// Single Pass X-Y Oscilloscope Fragment Shader
Shader "Unlit/AudioLinkOscilloscope" {
	Properties {
		[HDR] _Color ("Line Color (RGB) Line Intensity (A)", Color) = (0, 1, 0.5, 0.1)
		[Enum(Default, 0, Theme Color 1, 1, Theme Color 2, 2, Theme Color 3, 3, Theme Color 4, 4, Rainbow, 5)]
		_ColorMode ("Line Color Mode", Int) = 0
		_BGColor ("Background Color", Color) = (0, 0, 0, 1)
		[NoScaleOffset] _MainTex ("Background", 2D) = "white" {}
		_Scale ("Scale", Float) = 0.35
		[IntRange] _SampleCount ("Sample Count", Range(1, 2045)) = 511
		_Thickness ("Line Thickness", Float) = 0.001
	}
	SubShader {
		Tags { "RenderType" = "Opaque" }
		LOD 100
		Pass {
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fog

			#include "UnityCG.cginc"
			#include "Packages/com.llealloo.audiolink/Runtime/Shaders/AudioLink.cginc"

			struct appdata {
				float4 vertex: POSITION;
				float2 uv: TEXCOORD0;
			};

			struct v2f {
				float2 uv: TEXCOORD0;
				float3 worldPos: TEXCOORD1;
				UNITY_FOG_COORDS(2)
				float4 vertex: SV_POSITION;
			};

			sampler2D _MainTex;
			float4 _Color;
			float4 _BGColor;
			int _SampleCount;
			int _ColorMode;
			float _Thickness;
			float _Scale;

			// Function adopted from https://stackoverflow.com/a/19212122
			float drawLine(float2 p1, float2 p2, float2 uv, float thickness) {
				float a = distance(p1, uv);
				float b = distance(p2, uv);
				float c = distance(p1, p2);
				float h = a;
				float v = _Color.a;
				if (c > thickness) {
					if (a >= c || b >= c) return 0;
					h = (a + b + c) * 0.5;
					h = sqrt(h * (h - a) * (h - b) * (h - c)) * 2 / c;
					v /= c * _SampleCount / 10;
				}
				return (1 - smoothstep(thickness / 2, thickness / 2, h)) * v;
			}

			float2 getWaveform(int index) {
				float4 v = AudioLinkDataMultiline(ALPASS_WAVEFORM + int2(index, 0));
				return (v.x + float2(v.w, -v.w)) * _Scale + 0.5;
			}

			v2f vert(appdata v) {
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.worldPos = mul(unity_ObjectToWorld, v.vertex);
				o.uv = v.uv;
				UNITY_TRANSFER_FOG(o, o.vertex);
				return o;
			}

			fixed4 frag(v2f i) : COLOR {
				float4 v = 0;
				float4 col = tex2D(_MainTex, i.uv) * _BGColor;
				float thickness = _Thickness * distance(i.worldPos.xyz, _WorldSpaceCameraPos.xyz);
				for (int x = 0; x < _SampleCount; x++) {
					float p = float(x) / float(_SampleCount);
					float t = drawLine(getWaveform(x), getWaveform(x + 1), i.uv, thickness) * sqrt(1 - p);
					if (_ColorMode == 5) v += float4(AudioLinkHSVtoRGB(float3(p, 1, t)), t);
					else v += t;
				}
				float4 tint = float4(_Color.xyz, 1);
				if (_ColorMode == 1) tint.xyz = AudioLinkData(ALPASS_THEME_COLOR0);
				else if (_ColorMode == 2) tint.xyz = AudioLinkData(ALPASS_THEME_COLOR1);
				else if (_ColorMode == 3) tint.xyz = AudioLinkData(ALPASS_THEME_COLOR2);
				else if (_ColorMode == 4) tint.xyz = AudioLinkData(ALPASS_THEME_COLOR3);
				col = lerp(col, tint * v, saturate(v.w));
				UNITY_APPLY_FOG(i.fogCoord, col);
				return col;
			}
			ENDCG
		}
	}
}
