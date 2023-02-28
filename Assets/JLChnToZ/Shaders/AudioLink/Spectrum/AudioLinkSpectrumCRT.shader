// Renders AudioLink DFT as spectrum graph to CustomRenderTexture
Shader "Hidden/AudioLinkSpectrumCRT" {
    Properties {
        [HDR] _Color ("Color", Color) = (1, 1, 1, 1)
        [HDR] _Color2 ("Color 2 (For Autocorrelator Negative Values)", Color) = (1, 1, 1, 1)
        [Toggle] _RAINBOW ("Rainbow Colors", Int) = 0
        [Toggle] _CUSTOM_GRADIANT ("Custom Gradiant", Int) = 0
        _GradiantTex ("Gradiant Texture", 2D) = "black" {}
        [Toggle] _SMOOTH ("Smooth Lerp", Int) = 0
        _RecordTime ("Record Time", Float) = 1
        _Intensity ("Intensity (Scale)", Float) = 1
        [Enum(mag, 0, magEQ, 1, magfilt, 2, autocorrelator, 4, uncorrelatedAutocorrelator, 5)] _Channel ("Channel", Int) = 0
    }
    SubShader {
        LOD 100
        Blend One Zero

        Pass {
            CGPROGRAM
            #include "UnityCustomRenderTexture.cginc"
            #include "Assets/AudioLink/Shaders/AudioLink.cginc"
            #pragma shader_feature_local __ _CUSTOM_GRADIANT_ON _RAINBOW_ON
            #pragma shader_feature_local _SMOOTH_ON
            #pragma vertex CustomRenderTextureVertexShader
            #pragma fragment frag
            #pragma target 3.0

            #define AL_WRAP_TIME 86400

            float4 _Color;
            float4 _Color2;
            float _RecordTime;
            float _Intensity;
            int _Channel;
            
            #if _CUSTOM_GRADIANT_ON
            sampler2D _GradiantTex;
            #elif _RAINBOW_ON
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
                float2 diff = float2(0, AL_WRAP_TIME) + currentTime - lastTime;
                float2 offset = float2((abs(diff.x) < abs(diff.y) ? diff.x : diff.y) / _RecordTime, 0);
                if (offset.x < -0.5) offset.x += 1;
                if (all(IN.localTexcoord.xy >= 1 - 1 / size))
                    return offset.x >= 1 / size.x ? EncodeFloatRGBA(currentTime / AL_WRAP_TIME) : lastTimeRaw;
                if (offset.x < 1 / size.x) offset.x = 0;
                float4 realtime = _Color;
                float4 srcValue;
                if (_Channel > 3)
                    srcValue = AudioLinkLerp(ALPASS_AUTOCORRELATOR + float2(IN.localTexcoord.y * AUDIOLINK_WIDTH, 0));
                else
                    srcValue = AudioLinkLerpMultiline(ALPASS_DFT + float2(IN.localTexcoord.y * AUDIOLINK_ETOTALBINS, 0));
                float value = srcValue[int(fmod(_Channel, 4))] * _Intensity;
                #if _CUSTOM_GRADIANT_ON
                realtime *= tex2Dlod(_GradiantTex, float4(abs(value), (sign(value) + 1.) / 2., 0, 0));
                #elif _RAINBOW_ON
                if (_Channel > 3) {
                    float3 hsv = saturate(float3(frac(0.6 - value / 32), 1, abs(value) * 4));
                    realtime *= float4(hsv2rgb(hsv), hsv.z);
                } else {
                    float3 hsv = saturate(float3(0.6 - value / 2, 1, value * 10));
                    realtime *= float4(hsv2rgb(hsv), hsv.z);
                }
                #else
                if (_Channel > 3)
                    realtime = _Color * max(0, value) + _Color2 * max(0, -value);
                else
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
