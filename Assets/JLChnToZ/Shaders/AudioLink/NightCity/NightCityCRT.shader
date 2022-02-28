// Copyright (c) 2021 @yossy222_VRC
// Copyright (c) 2022 JLChnToZ aka. Vistanz
// Released under the MIT license
// https://opensource.org/licenses/mit-license.php

// Original Code by
// <Booth>
// Star Nest Shader HLSL by @Feyris77
// https://voxelgummi.booth.pm/items/1121090
// "Morning City" by Devin | Shadertoy
// https://www.shadertoy.com/view/XsBSRG

Shader "Hidden/NightCityCRT"
{
	Properties
	{
		[Header(Building)]
		[IntRange]_Buildings("Buildings (int)", Range(0, 200)) = 100
		[HDR]_WindowColorNear("Window Color Near", Color) = (3, 2, 1, 1)
		[HDR]_WindowColorFar("Window Color Far", Color) = (3, 3, 6, 1)

		[Header(ViewPoint)]
		_CameraPosition("Camera Position", Vector) = (0, 2.1, 0, 0)
		_CameraDirection("Camera Direction", Range(-3.1416, 3.1416)) = 0
		_Speed("Camera Moving Speed", Vector) = (0.1, 0, 0, 0)

		[Header(Car)]
		[Toggle(_IS_CARS_ON)] _Cars("Cars On", Int) = 1
		_CarColorLeft("Car Color Left", Color) = (0.5, 0.5, 1.0, 1)
		_CarColorRight("Car Color Right", Color) = (1.0, 0.1, 0.1, 1)

		[Header(Star)]
		[Toggle(_IS_STAR_ON)] _Stars("Stars On", Int) = 1
		[HDR]_StarColor("Star Color", Color) = (0.1622019, 0.1740361, 0.4245283, 1)

		[Header(Background)]
		[HDR]_BaseColor("Base Color", Color) = (0, 0, 0.2, 1)

		[Header(Misc Options)]
		_HDRScale("HDR Scale", Float) = 1

		[Header(AudioLink)]
		[Toggle(_AUDIO_LINK_ON)] _AudioLinkOn("Enabled", Int) = 0
		[Enum(Default Color with 4 Bands, 0, Theme Color with 4 Bands, 1, CC Lights with 4 Bands, 2, DFT, 3)] _ALMode("Mode", Int) = 0
		[Toggle(_)] _ALNormalize("Normalize CC / Theme Color", Int) = 0
		_ALSpreadSpeed("Spread Speed", Vector) = (1, 5, 0, 0)
	}

	SubShader
	{
		Tags { "PreviewType" = "SkyBox" }

		Pass
		{

			CGPROGRAM
			#pragma shader_feature_local _IS_CARS_ON
			#pragma shader_feature_local _IS_STAR_ON
			#pragma shader_feature_local _AUDIO_LINK_ON
			#if _AUDIO_LINK_ON
			#define AUDIO_LINK
			#endif
			#include "UnityCustomRenderTexture.cginc"
			#pragma vertex CustomRenderTextureVertexShader
			#pragma fragment frag
			#define VertexOutput v2f_customrendertexture

			#include "NightCity.cginc"
			fixed4 frag(v2f_customrendertexture IN) : SV_Target {
				float3 color = 0;
				color += city(IN.direction, 0.0);

				#ifdef _IS_STAR_ON
				color += star(IN.direction);
				#endif

				return float4(color * _HDRScale, 1.0);
			}
			ENDCG
		}
	}
}
