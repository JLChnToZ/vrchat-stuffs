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

#ifdef AUDIO_LINK
#include "Assets/AudioLink/Shaders/AudioLink.cginc"
#endif

int _Buildings;
float4 _WindowColorNear;
float4 _WindowColorFar;
float3 _CameraPosition;
float _CameraDirection;
float4 _CarColorLeft;
float4 _CarColorRight;
int _Stars;
float4 _StarColor;
float4 _BaseColor;
float _HDRScale;
float4 _Speed;
#ifdef AUDIO_LINK
float4 _ALSpreadSpeed;
int _ALNormalize;
int _ALMode;
#endif

float3 normalizeColor(float3 c) {
  float m = max(max(c.r, c.g), c.b);
  return m > 0 ? c / m : 1;
}

float rand(float2 n) {
  return frac(sin((n.x * 1e2 + n.y * 1e4 + 1475.4526) * 1e-4) * 1e6);
}

float noise(float2 p) {
  p = floor(p * 200.0);
  return rand(p);
}

float3 polygonXY(float z, float2 vert1, float2 vert2, float3 camPos, float3 rayDir) {
  float t =  - (camPos.z - z) / rayDir.z;
  float2 cross = camPos.xy + rayDir.xy * t;
  if (cross.x > min(vert1.x, vert2.x) && 
  cross.x < max(vert1.x, vert2.x) && 
  cross.y > min(vert1.y, vert2.y) && 
  cross.y < max(vert1.y, vert2.y) && 
  dot(rayDir, float3(cross, z) - camPos) > 0.0) {
    float dist = length(camPos - float3(cross, z));
    return float3(dist, cross.x - min(vert1.x, vert2.x), cross.y - min(vert1.y, vert2.y));
  }

  return float3(101.0, 0.0, 0.0);
}

float3 polygonYZ(float x, float2 vert1, float2 vert2, float3 camPos, float3 rayDir) {
  float t =  - (camPos.x - x) / rayDir.x;
  float2 cross1 = camPos.yz + rayDir.yz * t;
  if (cross1.x > min(vert1.x, vert2.x) && 
  cross1.x < max(vert1.x, vert2.x) && 
  cross1.y > min(vert1.y, vert2.y) && 
  cross1.y < max(vert1.y, vert2.y) && 
  dot(rayDir, float3(x, cross1) - camPos) > 0.0) {
    float dist = length(camPos - float3(x, cross1));
    return float3(dist, cross1.x - min(vert1.x, vert2.x), cross1.y - min(vert1.y, vert2.y));
  }

  return float3(101.0, 0.0, 0.0);
}

float3 polygonXZ(float y, float2 vert1, float2 vert2, float3 camPos, float3 rayDir) {
  float t =  - (camPos.y - y) / rayDir.y;
  float2 cross1 = camPos.xz + rayDir.xz * t;
  if (cross1.x > min(vert1.x, vert2.x) && 
  cross1.x < max(vert1.x, vert2.x) && 
  cross1.y > min(vert1.y, vert2.y) && 
  cross1.y < max(vert1.y, vert2.y) && 
  dot(rayDir, float3(cross1.x, y, cross1.y) - camPos) > 0.0) {
    float dist = length(camPos - float3(cross1.x, y, cross1.y));
    return float3(dist, cross1.x - min(vert1.x, vert2.x), cross1.y - min(vert1.y, vert2.y));
  }

  return float3(101.0, 0.0, 0.0);
}

float3 tex2DWall(float2 pos, float2 maxPos, float2 squarer, float s, float height, float dist, float3 rayDir, float3 norm) {
  float randB = rand(squarer * 2.0);
  #ifdef AUDIO_LINK
  float3 alThemeColor = 0;
  if (_ALMode == 3) {
    float note = randB * AUDIOLINK_ETOTALBINS;
    float2 val = AudioLinkLerpMultiline(ALPASS_DFT + float2(note, 0)).xy;
    alThemeColor = AudioLinkCCtoRGB(note, lerp(val.x, val.y, pos.y * _ALSpreadSpeed.y), 0);
  } else {
    if (_ALMode == 0) alThemeColor = 1;
    if (_ALMode == 1) {
      if (randB < 0.25) alThemeColor = AudioLinkData(ALPASS_THEME_COLOR0);
      else if (randB >= 0.25 && randB < 0.5) alThemeColor = AudioLinkData(ALPASS_THEME_COLOR1);
      else if (randB >= 0.5 && randB < 0.75) alThemeColor = AudioLinkData(ALPASS_THEME_COLOR2);
      else alThemeColor = AudioLinkData(ALPASS_THEME_COLOR3);
      if (all(alThemeColor < 0.04)) alThemeColor = AudioLinkData(ALPASS_THEME_COLOR0);
      if (all(alThemeColor < 0.04)) alThemeColor = AudioLinkData(ALPASS_THEME_COLOR1);
      if (all(alThemeColor < 0.04)) alThemeColor = AudioLinkData(ALPASS_THEME_COLOR2);
      if (all(alThemeColor < 0.04)) alThemeColor = AudioLinkData(ALPASS_THEME_COLOR3);
    } else if (_ALMode == 2) alThemeColor = AudioLinkData(ALPASS_CCLIGHTS + uint2(randB * AUDIOLINK_WIDTH, 0));
    if (_ALNormalize != 0) alThemeColor = normalizeColor(alThemeColor);
    alThemeColor *= AudioLinkLerp(ALPASS_AUDIOLINK + float2(fmod(dist * _ALSpreadSpeed.x + pos.y * _ALSpreadSpeed.y, AUDIOLINK_WIDTH), floor(frac(randB * 4.0) * 4.0))).r;
  }
  #endif
  float3 windowColor = (-0.4 + randB * 0.8) * float3(0.3, 0.3, 0.0) + (-0.4 + frac(randB * 10.0) * 0.8) * float3(0.0, 0.0, 0.3) + (-0.4 + frac(randB * 10000.0) * 0.8) * float3(0.3, 0.0, 0.0);
  float floorFactor = 1.0;
  float2 windowSize = float2(0.65, 0.35);
  float3 wallColor = s * (0.3 + 1.4 * frac(randB * 100.0)) * float3(0.1, 0.1, 0.1) + (-0.7 + 1.4 * frac(randB * 1000.0)) * float3(0.02, 0., 0.);
  wallColor *= 1.3;

  float3 color = 0.0;
  float3 conturColor = wallColor / 1.5;
  if (height < 0.51) {
  #ifdef AUDIO_LINK
    windowColor += _WindowColorNear.xyz * alThemeColor;
  #else
    windowColor += _WindowColorNear.xyz;
  #endif
    windowSize = float2(0.4, 0.4);
    floorFactor = 0.0;

  }
  if (height <= 0.85) {
  #ifdef AUDIO_LINK
    windowColor += (_WindowColorNear.xyz - 0.1) * alThemeColor;
  #else
    windowColor += _WindowColorNear.xyz - 0.1;
  #endif
    windowSize = 0.3;
    floorFactor = 0.0;
  }
  if (height < 0.6) { floorFactor = 1.0; }
  if (height > 0.85) {
  #ifdef AUDIO_LINK
    windowColor += _WindowColorFar.xyz * alThemeColor;
  #else
    windowColor += _WindowColorFar.xyz;
  #endif
  }
  windowColor *= 3.5;
  float wsize = 0.02;
  wsize +=  - 0.007 + 0.014 * frac(randB * 75389.9365);
  windowSize += float2(0.34 * frac(randB * 45696.9365), 0.50 * frac(randB * 853993.5783));

  float2 contur = 0.0 + (frac(maxPos / 2.0 / wsize)) * wsize;
  if (contur.x < wsize) { contur.x += wsize; }
  if (contur.y < wsize) { contur.y += wsize; }

  float2 winPos = (pos - contur) / wsize / 2.0 - floor((pos - contur) / wsize / 2.0);

  float numWin = floor((maxPos - contur) / wsize / 2.0).x;

  if ((maxPos.x > 0.5 && maxPos.x < 0.6) && (((pos - contur).x > wsize * 2.0 * floor(numWin / 2.0)) && ((pos - contur).x < wsize * 2.0 + wsize * 2.0 * floor(numWin / 2.0)))) {
    return (0.9 + 0.2 * noise(pos)) * conturColor;
  }

  if ((maxPos.x > 0.6 && maxPos.x < 0.7) && ((((pos - contur).x > wsize * 2.0 * floor(numWin / 3.0)) && ((pos - contur).x < wsize * 2.0 + wsize * 2.0 * floor(numWin / 3.0))) || 
  (((pos - contur).x > wsize * 2.0 * floor(numWin * 2.0 / 3.0)) && ((pos - contur).x < wsize * 2.0 + wsize * 2.0 * floor(numWin * 2.0 / 3.0))))) {
    return (0.9 + 0.2 * noise(pos)) * conturColor;
  }

  if ((maxPos.x > 0.7) && ((((pos - contur).x > wsize * 2.0 * floor(numWin / 4.0)) && ((pos - contur).x < wsize * 2.0 + wsize * 2.0 * floor(numWin / 4.0))) || 
  (((pos - contur).x > wsize * 2.0 * floor(numWin * 2.0 / 4.0)) && ((pos - contur).x < wsize * 2.0 + wsize * 2.0 * floor(numWin * 2.0 / 4.0))) || 
  (((pos - contur).x > wsize * 2.0 * floor(numWin * 3.0 / 4.0)) && ((pos - contur).x < wsize * 2.0 + wsize * 2.0 * floor(numWin * 3.0 / 4.0))))) {
    return (0.9 + 0.2 * noise(pos)) * conturColor;
  }
  if ((maxPos.x - pos.x < contur.x) || (maxPos.y - pos.y < contur.y + 2.0 * wsize) || (pos.x < contur.x) || (pos.y < contur.y)) {
    return (0.9 + 0.2 * noise(pos)) * conturColor;

  }
  if (maxPos.x < 0.14) {
    return (0.9 + 0.2 * noise(pos)) * wallColor;
  }

  float2 window = floor((pos - contur) / wsize / 2.0);
  float random = rand(squarer * s * maxPos.y + window);
  float randomZ = rand(squarer * s * maxPos.y + floor(float2((pos - contur).y, (pos - contur).y) / wsize / 2.0));
  float windows = floorFactor * sin(randomZ * 5342.475379 + (frac(975.568 * randomZ) * 0.15 + 0.05) * window.x);

  float blH = 0.06 * dist * 600.0 / 1 / abs(dot(normalize(rayDir.xy), normalize(norm.xy)));
  float blV = 0.06 * dist * 600.0 / 1 / sqrt(abs(1.0 - pow(abs(rayDir.z), 2.0)));

  windowColor += 1.0;
  windowColor += dist + float3(rand(squarer * 20), rand(squarer * 20), rand(squarer * 20)); // adjust
  windowColor *= smoothstep(0.5 - windowSize.x / 2.0 - blH, 0.5 - windowSize.x / 2.0 + blH, winPos.x);
  windowColor *= smoothstep(0.5 + windowSize.x / 2.0 + blH, 0.5 + windowSize.x / 2.0 - blH, winPos.x);
  windowColor *= smoothstep(0.5 - windowSize.y / 2.0 - blV, 0.5 - windowSize.y / 2.0 + blV, winPos.y);
  windowColor *= smoothstep(0.5 + windowSize.y / 2.0 + blV, 0.5 + windowSize.y / 2.0 - blV, winPos.y);

  if ((random < 0.05 * (3.5 - 2.5 * floorFactor)) || (windows > 0.65)) {
    if (winPos.y < 0.5) { windowColor *= (1.0 - 0.4 * frac(random * 100.0)); }
    if ((winPos.y > 0.5) && (winPos.x < 0.5)) { windowColor *= (1.0 - 0.4 * frac(random * 10.0)); }
    return (0.9 + 0.2 * noise(pos)) * wallColor + (0.9 + 0.2 * noise(pos)) * windowColor;


  }
  else {
    windowColor *= 0.08 * frac(10.0 * random);
  }
  return (0.9 + 0.2 * noise(pos)) * wallColor * windowColor;
}
 // tex2DWall()


float3 tex2DRoof(float2 pos, float2 maxPos, float2 squarer, float dist) {
  float wsize = 0.025;
  float randB = rand(squarer * 2.0);
  float3 wallColor = (0.3 + 1.4 * frac(randB * 100.0)) * float3(0.1, 0.1, 0.1) + (-0.7 + 1.4 * frac(randB * 1000.0)) * float3(0.02, 0., 0.);
  float3 conturColor = wallColor * 1.5 / 2.5;
  float2 contur = 0.02;
  if ((maxPos.x - pos.x < contur.x) || (maxPos.y - pos.y < contur.y) || (pos.x < contur.x) || (pos.y < contur.y)) {
    return (0.9 + 0.2 * noise(pos)) * conturColor;

  }
  float step1 = 0.06 + 0.12 * frac(randB * 562526.2865);
  pos -= step1;
  maxPos -= step1 * 2.0;
  if ((pos.x > 0.0 && pos.y > 0.0 && pos.x < maxPos.x && pos.y < maxPos.y) && ((abs(maxPos.x - pos.x) < contur.x) || (abs(maxPos.y - pos.y) < contur.y) || (abs(pos.x) < contur.x) || (abs(pos.y) < contur.y))) {
    return (0.9 + 0.2 * noise(pos)) * conturColor;

  }
  pos -= step1;
  maxPos -= step1 * 2.0;
  if ((pos.x > 0.0 && pos.y > 0.0 && pos.x < maxPos.x && pos.y < maxPos.y) && ((abs(maxPos.x - pos.x) < contur.x) || (abs(maxPos.y - pos.y) < contur.y) || (abs(pos.x) < contur.x) || (abs(pos.y) < contur.y))) {
    return (0.9 + 0.2 * noise(pos)) * conturColor;

  }
  pos -= step1;
  maxPos -= step1 * 2.0;
  if ((pos.x > 0.0 && pos.y > 0.0 && pos.x < maxPos.x && pos.y < maxPos.y) && ((abs(maxPos.x - pos.x) < contur.x) || (abs(maxPos.y - pos.y) < contur.y) || (abs(pos.x) < contur.x) || (abs(pos.y) < contur.y))) {
    return (0.9 + 0.2 * noise(pos)) * conturColor;

  }

  return (0.9 + 0.2 * noise(pos)) * wallColor;
}
 // tex2DRoof()


float3 cars(float2 squarer, float2 pos, float dist, float level) {
  float3 color = 0;
  float carInten = 3.5 / sqrt(dist);
  float carRadis = 0.01;
  if (dist > 2.0) { carRadis *= sqrt(dist / 2.0); }
  float3 car1 = _CarColorLeft.rgb;
  float3 car2 = _CarColorRight.rgb;
  float carNumber = 0.5;

  float random = noise((level + 1.0) * squarer * 1.24435824);
  #ifdef AUDIO_LINK
  float time = (AudioLinkIsAvailable() ? AudioLinkDecodeDataAsSeconds(ALPASS_GENERALVU_INSTANCE_TIME) : _Time.y) / 4.0;
  #else
  float time = _Time.y / 4.0;
  #endif
  for (int j = 0;j < 10; j++) {
    float i = 0.03 + float(j) * 0.094;
    if (frac(random * 5.0 / i) > carNumber) { color += car1 * carInten * smoothstep(carRadis, 0.0, length(pos - float2(frac(i + time), 0.025))); }

    if (frac(random * 10.0 / i) > carNumber) { color += car2 * carInten * smoothstep(carRadis, 0.0, length(pos - float2(frac(i - time), 0.975))); }
    if (color.x > 0.0) break;
  }
  for (int k = 0;k < 10; k++) {
    float i = 0.03 + float(k) * 0.094;
    if (frac(random * 5.0 / i) > carNumber) { color += car2 * carInten * smoothstep(carRadis, 0.0, length(pos - float2(0.025, frac(i + time)))); }
    if (frac(random * 10.0 / i) > carNumber) { color += car1 * carInten * smoothstep(carRadis, 0.0, length(pos - float2(0.975, frac(i - time)))); }
    if (color.x > 0.0) break;

  }
  for (int l = 0;l < 10; l++) {
    float i = 0.03 + 0.047 + float(l) * 0.094;
    if (frac(random * 100.0 / i) > carNumber) { color += car1 * carInten * smoothstep(carRadis, 0.0, length(pos - float2(frac(i + time), 0.045))); }
    if (frac(random * 1000.0 / i) > carNumber) { color += car2 * carInten * smoothstep(carRadis, 0.0, length(pos - float2(frac(i - time), 0.955))); }
    if (color.x > 0.0) break;

  }
  for (int m = 0;m < 10; m++) {
    float i = 0.03 + 0.047 + float(m) * 0.094;
    if (frac(random * 100.0 / i) > carNumber) { color += car2 * carInten * smoothstep(carRadis, 0.0, length(pos - float2(0.045, frac(i + time)))); }
    if (frac(random * 1000.0 / i) > carNumber) { color += car1 * carInten * smoothstep(carRadis, 0.0, length(pos - float2(0.955, frac(i - time)))); }
    if (color.x > 0.0) break;

  }
  return color;
}
 // cars()


float3 tex2DGround(float2 squarer, float2 pos, float2 vert1, float2 vert2, float dist) {
  float3 color = (0.9 + 0.2 * noise(pos)) * float3(0.1, 0.15, 0.1);
  float randB = rand(squarer * 2.0);

  float3 wallColor = (0.3 + 1.4 * frac(randB * 100.0)) * float3(0.1, 0.1, 0.1) + (-0.7 + 1.4 * frac(randB * 1000.0)) * float3(0.02, 0., 0.);
  float fund = 0.03;
  float bl = 0.01;
  float f = smoothstep(vert1.x - fund - bl, vert1.x - fund, pos.x);
  f *= smoothstep(vert1.y - fund - bl, vert1.y - fund, pos.y);
  f *= smoothstep(vert2.y + fund + bl, vert2.y + fund, pos.y);
  f *= smoothstep(vert2.x + fund + bl, vert2.x + fund, pos.x);

  pos -= 0.0;
  float2 maxPos = 1.;
  float2 contur = 0.06;
  if ((pos.x > 0.0 && pos.y > 0.0 && pos.x < maxPos.x && pos.y < maxPos.y) && ((abs(maxPos.x - pos.x) < contur.x) || (abs(maxPos.y - pos.y) < contur.y) || (abs(pos.x) < contur.x) || (abs(pos.y) < contur.y))) {
    color = 0.1 * (0.9 + 0.2 * noise(pos));

  }
  pos -= 0.06;
  maxPos = 0.88;
  contur = 0.01;
  if ((pos.x > 0.0 && pos.y > 0.0 && pos.x < maxPos.x && pos.y < maxPos.y) && ((abs(maxPos.x - pos.x) < contur.x) || (abs(maxPos.y - pos.y) < contur.y) || (abs(pos.x) < contur.x) || (abs(pos.y) < contur.y))) {
    color = 0.;

  }
  color = lerp(color, (0.9 + 0.2 * noise(pos)) * wallColor * 1.5 / 2.5, f);

  pos += 0.06;

  #ifdef _IS_CARS_ON
    if (pos.x < 0.07 || pos.x > 0.93 || pos.y < 0.07 || pos.y > 0.93) {
      color += cars(squarer, pos, dist, 0.0);
    }
  #endif

  return color;
}
 // tex2DGround()

float3 city(float3 rayDir, float3 cameraPos) {
 // http://wordpress.notargs.com/blog/blog/2015/11/08/unity%E8%87%AA%E4%BD%9C%E3%81%AEskybox%E3%81%A7%E3%82%B8%E3%83%A5%E3%83%AA%E3%82%A2%E9%9B%86%E5%90%88%E3%81%AB%E5%9B%B2%E3%81%BE%E3%82%8C%E3%82%8B/
  rayDir = rayDir.zxy;
  cameraPos = cameraPos.zxy;
#ifdef AUDIO_LINK
  float2 speed = 0;
  if (AudioLinkIsAvailable()) {
    speed = AudioLinkDecodeDataAsSeconds(ALPASS_GENERALVU_INSTANCE_TIME);
  } else {
    speed = _Time.y;
  }
  speed *= _Speed.xy;
#else
  float2 speed = _Time.y * _Speed.xy;
#endif
  float2 rot;
  sincos(_CameraDirection, rot.x, rot.y);
  rayDir.xy = rayDir.x * rot.yx + rayDir.y * rot.xy * float2(-1, 1);
  cameraPos.xy = cameraPos.x * rot.yx + cameraPos.y * rot.xy * float2(-1, 1);
  float3 camPos = _CameraPosition.zxy + float3(speed.xy, 1) + cameraPos;
  float angle = 0.03 * pow(abs(acos(rayDir.x)), 4.0);
  float3 color = 0.0;
  float2 square = floor(camPos.xy);
  square.x += 0.5 - 0.5 * sign(rayDir.x);
  square.y += 0.5 - 0.5 * sign(rayDir.y);
  float mind = 100.0;
  float fog = 0;
  int k = 0;
  float3 pol;
  float2 maxPos;
  float2 crossG;
  float tSky =  - (camPos.z - 3.9) / rayDir.z;
  float2 crossSky = floor(camPos.xy + rayDir.xy * tSky);

  for (int i = 1; i < _Buildings; i++) {

    float2 squarer = square - float2(0.5, 0.5) + 0.5 * sign(rayDir.xy);

    if ((crossSky.x == squarer.x && crossSky.y == squarer.y) && (crossSky.x != floor(camPos.x) || crossSky.y != floor(camPos.y))) {
      break;
    }
    float t;
    float random = rand(squarer);
    float height = 0.0;
    float quartalR = rand(floor(squarer / 10.0));
    if (floor(squarer.x / 10.0) == 0.0 && floor(squarer.y / 10.0) == 0.0) { quartalR = 0.399; }
    if (quartalR < 0.4) {
      height = -0.15 + 0.4 * random + smoothstep(12.0, 7.0, length(frac(squarer / 10.0) * 10.0 - float2(5.0, 5.0))) * 0.8 * random + 0.9 * smoothstep(10.0, 0.0, length(frac(squarer / 10.0) * 10.0 - float2(5.0, 5.0)));
      height *= quartalR / 0.4;
    }
    float maxJ = 2.0;
    float roof = 1.0;
    if (height < 0.3) {
      height = 0.3 * (0.7 + 1.8 * frac(random * 100.543264));maxJ = 2.0;
      if (frac(height * 1000.0) < 0.04) height *= 1.3;
    }
    if (height > 0.5) { maxJ = 3.0; }
    if (height > 0.85) { maxJ = 4.0; }
    if (frac(height * 100.0) < 0.15) { height = pow(maxJ - 1.0, 0.3) * height; maxJ = 2.0; roof = 0.0; }

    float maxheight = 1.5 * pow((maxJ - 1.0), 0.3) * height + roof * 0.07;
    if (camPos.z + rayDir.z * (length(camPos.xy - square) + 0.71 - sign(rayDir.z) * 0.71) / length(rayDir.xy) < maxheight) {
      float2 vert1r;
      float2 vert2r;
      float zz = 0.0;
      float prevZZ = 0.0;
      [unroll(100)]
      for (int nf = 1; nf < 8; nf++) {
        float j = float(nf);
        if (j > maxJ) { break; }
        prevZZ = zz;
        zz = 1.5 * pow(j, 0.3) * height;
 // prevZZ = zz - 0.8;

        float dia = 1.0 / pow(j, 0.3);
        if (j == maxJ) {
          if (roof == 0.0) { break; }
          zz = 1.5 * pow((j - 1.0), 0.3) * height + 0.03 + 0.04 * frac(random * 1535.347);
          dia = 1.0 / float(pow((j - 1.0), 0.3) - 0.2 - 0.2 * frac(random * 10000.0));
        }

        float2 v1 = 0.0; // float2(random * 10.0, random * 1.0);
        float2 v2 = 0.0; // float2(random * 1000.0, random * 100.0);
        float randomF = frac(random * 10.0);
        if (randomF < 0.25) { v1 = float2(frac(random * 1000.0), frac(random * 100.0)); }
        if (randomF > 0.25 && randomF < 0.5) { v1 = float2(frac(random * 100.0), 0.0); v2 = float2(0.0, frac(random * 1000.0)); }
        if (randomF > 0.5 && randomF < 0.75) { v2 = float2(frac(random * 1000.0), frac(random * 100.0)); }
        if (randomF > 0.75) { v1 = float2(0.0, frac(random * 1000.0)); v2 = float2(frac(random * 100.0), 0.0); }
        if (rayDir.y < 0.0) {
          float y = v1.y;
          v1.y = v2.y;
          v2.y = y;
        }
        if (rayDir.x < 0.0) {
          float x = v1.x;
          v1.x = v2.x;
          v2.x = x;
        }

        float2 vert1 = square + sign(rayDir.xy) * (0.5 - 0.37 * (dia * 1.0 - 1.0 * v1));
        float2 vert2 = square + sign(rayDir.xy) * (0.5 + 0.37 * (dia * 1.0 - 1.0 * v2));
        if (j == 1.0) {
          vert1r = float2(min(vert1.x, vert2.x), min(vert1.y, vert2.y));
          vert2r = float2(max(vert1.x, vert2.x), max(vert1.y, vert2.y));
        }

        float3 pxy = polygonXY(zz, vert1, vert2, camPos, rayDir);
        if (pxy.x < mind) { mind = pxy.x; pol = pxy; k = 1; maxPos = float2(abs(vert1.x - vert2.x), abs(vert1.y - vert2.y)); }

        float3 pyz = polygonYZ(vert1.x, float2(vert1.y, prevZZ), float2(vert2.y, zz), camPos, rayDir);
        if (pyz.x < mind) { mind = pyz.x; pol = pyz; k = 2; maxPos = float2(abs(vert1.y - vert2.y), zz - prevZZ); }

        float3 pxz = polygonXZ(vert1.y, float2(vert1.x, prevZZ), float2(vert2.x, zz), camPos, rayDir);
        if (pxz.x < mind) { mind = pxz.x; pol = pxz; k = 3; maxPos = float2(abs(vert1.x - vert2.x), zz - prevZZ); }
      }

      if ((mind < 100.0) && (k == 1)) {
        color += tex2DRoof(float2(pol.y, pol.z), maxPos, squarer, mind);
        // if (mind > 3.0) { color *= sqrt(3.0 / mind); }
        fog = sqrt(saturate(1 - mind / float(_Buildings) * 3));
        break;
      }
      if ((mind < 100.0) && (k == 2)) {
        color += tex2DWall(float2(pol.y, pol.z), maxPos, squarer, 1.2075624928, height, mind, rayDir, float3(1.0, 0.0, 0.0));
        // if (mind > 3.0) { color *= sqrt(3.0 / mind); }
        fog = sqrt(saturate(1 - mind / float(_Buildings) * 3));
        break;
      }

      if ((mind < 100.0) && (k == 3)) {
        color += tex2DWall(float2(pol.y, pol.z), maxPos, squarer, 0.8093856205, height, mind, rayDir, float3(0.0, 1.0, 0.0));
        // if (mind > 3.0) { color *= sqrt(3.0 / mind); }
        fog = sqrt(saturate(1 - mind / float(_Buildings) * 3));
        break;
      }
      t =  - camPos.z / rayDir.z;
      crossG = camPos.xy + rayDir.xy * t;
      if (floor(crossG.x) == squarer.x && floor(crossG.y) == squarer.y) {
        mind = length(float3(crossG, 0.0) - camPos);
        color += tex2DGround(squarer, frac(crossG), frac(vert1r), frac(vert2r), mind);
        // if (mind > 3.0) { color *= sqrt(3.0 / mind); }
        fog = sqrt(saturate(1 - mind / float(_Buildings) * 3));
        break;
      }

    }

    if ((square.x + sign(rayDir.x) - camPos.x) / rayDir.x < (square.y + sign(rayDir.y) - camPos.y) / rayDir.y) {
      square.x += sign(rayDir.x) * 1.0;
    } else {
      square.y += sign(rayDir.y) * 1.0;
    }

    if (i == _Buildings - 1 && rayDir.z > - 0.1) {
      fog = 0;
    }

  }

  return lerp(float3((0.0 * abs(angle) * exp(-rayDir.z * rayDir.z * 30.0)).xx, 0.0) + _BaseColor, color, fog);
}

fixed3 star(float3 pos) {
  if (pos.y <  - 0.2) {
    return 0;
  }

  #ifdef AUDIO_LINK
  float time = AudioLinkIsAvailable() ? AudioLinkDecodeDataAsSeconds(ALPASS_GENERALVU_INSTANCE_TIME) / 20.0 : _Time.x;
  #else
  float time = _Time.x;
  #endif
  float3 from = float3(46, 487, 3534) + time * float3(0.05, 0.05, 0.2);
  float s = .1, fade = 0.116;
  float3 col;

  [loop]
  for (int r = 0; r < 4; r++) {
    float3 p = from + s * pos * 3;
    p = abs(1 - fmod(p, 1 * 2));
    float pa, a;
    [loop]
    for (int l = 0; l < 9; l++) {
      p = abs(p) / dot(p, p) - 0.679;
      a += abs(length(p) - pa);
      pa = length(p);
    }
    float dm = max(0, 0.33 - pow(a, 2) * .001);
    a *= pow(a, 2);
    fade *= r > 6 ? 1 - dm : 1;
    #ifdef AUDIO_LINK
    a *= AudioLinkLerp(ALPASS_AUDIOLINK + float2(frac(s * 4.0) * AUDIOLINK_WIDTH, floor(s * 4.0))).r;
    #endif

    col += float3(s, pow(s, 2), pow(s, 4)) * a * 0.01 * fade;
    fade *= 0.445;
    s += 0.205;
  }
  col = lerp(length(col), col, 0.744) * _StarColor * .02;
  return col;

} // star()
