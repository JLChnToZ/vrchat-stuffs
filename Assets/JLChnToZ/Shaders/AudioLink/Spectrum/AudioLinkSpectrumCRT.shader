// Renders AudioLink DFT as spectrum graph to CustomRenderTexture
Shader "Hidden/AudioLinkSpectrumCRT" {
    Properties {
        [HDR] _Color ("Color", Color) = (1, 1, 1, 1)
        [Toggle] _RAINBOW ("Rainbow Colors", Int) = 0
        [Toggle] _SMOOTH ("Smooth Lerp", Int) = 0
        _RecordTime ("Record Time", Float) = 1
        _Intensity ("Intensity (Scale)", Float) = 1
        [Enum(mag, 0, magEQ, 1, magfilt, 2)] _Channel ("Channel", Int) = 0
    }
    SubShader {
        LOD 100
        Blend One Zero

        Pass {
            CGPROGRAM
            #include "UnityCustomRenderTexture.cginc"
            #include "Assets/AudioLink/Shaders/AudioLink.cginc"
            #pragma multi_compile_local __ _RAINBOW_ON
            #pragma multi_compile_local __ _SMOOTH_ON
            #pragma vertex CustomRenderTextureVertexShader
            #pragma fragment frag
            #pragma target 3.0

            #define AL_WRAP_TIME 134217.727

            float4 _Color;
            float _RecordTime;
            float _Intensity;
            int _Channel;
            
            #if _RAINBOW_ON
            float3 hsv2rgb(float3 hsv) {
                return hsv.z * lerp(1, saturate(abs(fmod(hsv.x * 6 + float3(0, 4, 2), 6) - 3) - 1), hsv.y);
            }
            #endif

            float2 align(float2 uv, float2 size) {
                return saturate((floor(uv * size) + 0.5) / size);
            }

            float4 frag(v2f_customrendertexture IN): COLOR {
                float2 size = float2(_CustomRenderTextureWidth, _CustomRenderTextureHeight);
                float currentTime = AudioLinkDecodeDataAsSeconds(ALPASS_GENERALVU_LOCAL_TIME);
                float4 lastTimeRaw = tex2D(_SelfTexture2D, align(1, size));
                float lastTime = DecodeFloatRGBA(lastTimeRaw) * AL_WRAP_TIME;
                float2 offset = float2((currentTime - lastTime) / _RecordTime, 0);
                if (offset.x < -0.5) offset.x += 1;
                if (all(IN.localTexcoord.xy >= 1 - 1 / size))
                    return offset.x >= 1 / size.x ? EncodeFloatRGBA(currentTime / AL_WRAP_TIME) : lastTimeRaw;
                if (offset.x < 1 / size.x) offset.x = 0;
                float4 realtime = _Color;
                float value = AudioLinkLerpMultiline(ALPASS_DFT + float2(IN.localTexcoord.y * AUDIOLINK_ETOTALBINS, 0))[_Channel] * _Intensity;
                #if _RAINBOW_ON
                    float3 hsv = saturate(float3(0.6 - value / 2, 1, value * 10));
                    realtime *= float4(hsv2rgb(hsv), hsv.z);
                #else
                    realtime *= value;
                #endif
                float4 record = tex2D(_SelfTexture2D, align(IN.localTexcoord.xy - offset, size));
                value = IN.localTexcoord.x / offset.x;
                #if _SMOOTH_ON
                    value = smoothstep(0, 1, value);
                #else
                    value = saturate(value);
                #endif
                return lerp(realtime, record, value);
            }
            ENDCG
        }
    }
}
