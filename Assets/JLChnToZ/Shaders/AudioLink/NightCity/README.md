# Night City (AudioLink) Skybox Shader

This is a modified Night City Skybox Shader, which is from ["Night City Skybox Shader" by yossy222](https://yossy222.booth.pm/items/2954980), ["Morning City" by Devin](https://www.shadertoy.com/view/XsBSRG) and ["Star Nest Shader HLSL" by @Feyris77](https://voxelgummi.booth.pm/items/1121090).

Here is the differences compared to the original:
1. The rendering angle is more respect to the viewport.
2. The origin position can be configurated to move along a direction with defined speed.
3. Fog is added to fade out far buildings.
4. It can be added to any mesh renderers, not just the skybox material.
5. It can be used as a material of CustomRenderTexture in Cube dimension (With the CRT variant).
6. AudioLink support is added. It is capable to react with AudioLink's 4 band values, ColorChord lights, theme colors and DFT values depend on the settings.

## License

Copyright (c) 2021 @yossy222_VRC  
Copyright (c) 2022 JLChnToZ aka. Vistanz  
Released under the [MIT license](https://opensource.org/licenses/mit-license.php)

Original Code by
- [Star Nest Shader HLSL by @Feyris77](https://voxelgummi.booth.pm/items/1121090)
- ["Morning City" by Devin | Shadertoy](https://www.shadertoy.com/view/XsBSRG)