// This file "NixieTube-AudioLink-Dots.shader" is provided in zlib license (Copyright (c) 2021 kden) (Copyright (c) 2022 JLChnToZ aka. Vistanz)
// With code based on https://github.com/y23586/vrchat-time-shaders (License: CC0)

Shader "SPORADIC-E/NixieClock-AudioLink-Dots" {
  Properties {
    _Color ("Color", Color) = (1,1,1,1)
    _EmissionColor ("Emission", Color) = (0,0,0,1)
    _EmissionIntensity("EmissionIntensity", Range(0,10)) = 1.0
    _TexChars ("Characters", 2D) = "white" {}
    _Glossiness ("Smoothness", Range(0,1)) = 0.5
    _Metallic ("Metallic", Range(0,1)) = 0.0
    _Cutoff ("Cutoff", Range(0,1)) = 0.5

    _FlickerP ("flickering power", Range(0,1)) = 0.0
  }
  SubShader {
      Tags { "RenderType"="Transparent" "Queue"="Transparent" }
      LOD 100
      ZWrite Off
      Blend SrcAlpha OneMinusSrcAlpha
      Cull Off

      CGPROGRAM
      #pragma surface surf Standard fullforwardshadows alpha
      #pragma target 3.0

			#define EPSILON 1.192092896e-07
      #define VRCCLOCK_LOCAL_TIME int2(1, 0)

      #include "Assets/AudioLink/Shaders/AudioLink.cginc"

      sampler2D _VRCClockTexture;
      float4 _VRCClockTexture_TexelSize;

      sampler2D _TexChars;

      struct Input {
        float2 uv_TexChars;
      };

      half _Glossiness;
      half _Metallic;
      fixed4 _Color;
      fixed4 _EmissionColor;
      float _EmissionIntensity;
      float _Cutoff;
      float _FlickerP;

      UNITY_INSTANCING_BUFFER_START(Props)
      UNITY_INSTANCING_BUFFER_END(Props)

      bool VRCClockAvailable() {
        return _VRCClockTexture_TexelSize.z > 4;
      }

      half4 VRCClockData(int2 uv) {
        half2 dim = _VRCClockTexture_TexelSize.zw;
        half4 v = tex2Dlod(_VRCClockTexture, float4((uv + 0.5) / dim, 0, 0));
        v.xyz = v.xyz <= 0.0031308 ? v.xyz * 12.92 : (pow(max(abs(v.xyz), EPSILON), 1 / 2.4) * 1.055) - 0.055;
        return v;
      }

      float half42Int(half4 vec) {
        uint4 v = round(vec * 255);
        return v.x + v.y * 256 + v.z * 65536 + v.w * 16777216;
      }

      float rand(fixed2 co){
        return frac(sin(dot(co.xy ,fixed2(12.9898,78.233))) * 43758.5453);
      }

      float getTime() {
        if (AudioLinkIsAvailable()) // AudioLink
          return AudioLinkDecodeDataAsSeconds(ALPASS_GENERALVU_LOCAL_TIME);
        if (VRCClockAvailable()) // Alternative
          return float(half42Int(VRCClockData(VRCCLOCK_LOCAL_TIME))) / 1000.;
        return _Time.y;
      }

      void surf (Input IN, inout SurfaceOutputStandard o) {
        float2 uv0 = IN.uv_TexChars;
        float flick = lerp(_FlickerP, 1.0, rand(fixed2(_Time.w, _Time.z)));
        fixed4 c = tex2D(_TexChars, uv0);
        float blink = step(frac(getTime()), 0.5);
        clip(c.a-_Cutoff);
        o.Albedo = c.rgb*c.a*blink;
        o.Emission = (_EmissionColor*_EmissionIntensity*c.a*((c.r + c.g + c.b)/3))*flick*blink;
        o.Metallic = _Metallic*c.a;
        o.Smoothness = _Glossiness*c.a;
        const float clipThreshold = 0.01;
        o.Alpha = c.a;
      }
      ENDCG
  }
  FallBack "Diffuse"
}
