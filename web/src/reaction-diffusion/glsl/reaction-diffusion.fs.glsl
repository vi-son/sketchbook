precision highp float;

#pragma glslify: blur = require('glsl-fast-gaussian-blur/13')

uniform int uFrame;
uniform float uTime;
uniform vec2 uResolution;
uniform vec3 uMouse;
uniform vec4 uDiffusionSettings;
// x: diffusionRateA
// y: diffusionRateB
// z: feedRate
// w: killRate
uniform vec4 uBrush;
uniform sampler2D uTexture;
uniform sampler2D uAudioTexture;

varying vec2 vUv;

float circle(in vec2 uv, in vec2 position, in float radius) {
  vec2 d = uv - position;
  d *= vec2(1.0, uResolution.y / uResolution.x);
  return 1.0 - smoothstep(radius - (radius * 0.9),
                          radius + (radius * 0.9),
                          dot(d, d) * 4.0);
}

// Simplex 2D noise
vec3 permute(vec3 x) { return mod(((x*34.0)+1.0)*x, 289.0); }

float snoise(vec2 v){
  const vec4 C = vec4(0.211324865405187, 0.366025403784439,
           -0.577350269189626, 0.024390243902439);
  vec2 i  = floor(v + dot(v, C.yy) );
  vec2 x0 = v -   i + dot(i, C.xx);
  vec2 i1;
  i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
  vec4 x12 = x0.xyxy + C.xxzz;
  x12.xy -= i1;
  i = mod(i, 289.0);
  vec3 p = permute( permute( i.y + vec3(0.0, i1.y, 1.0 ))
  + i.x + vec3(0.0, i1.x, 1.0 ));
  vec3 m = max(0.5 - vec3(dot(x0,x0), dot(x12.xy,x12.xy),
    dot(x12.zw,x12.zw)), 0.0);
  m = m*m ;
  m = m*m ;
  vec3 x = 2.0 * fract(p * C.www) - 1.0;
  vec3 h = abs(x) - 0.5;
  vec3 ox = floor(x + 0.5);
  vec3 a0 = x - ox;
  m *= 1.79284291400159 - 0.85373472095314 * ( a0*a0 + h*h );
  vec3 g;
  g.x  = a0.x  * x0.x  + h.x  * x0.y;
  g.yz = a0.yz * x12.xz + h.yz * x12.yw;
  return 130.0 * dot(m, g);
}

void main() {
  vec2 uv = vUv;

  vec2 nuv = vec2(uv.x + uMouse.x + uTime * 0.1, uv.y + uMouse.y + uTime * 0.1);
  float simplex = snoise(nuv * vec2(uResolution.x, uResolution.y) * 0.0075) * 0.5 + 0.5;
  float simplex2 = snoise(uv * vec2(uResolution.x, uResolution.y) * 0.0075) * 0.5 + 0.5;

  float diffusionRateA = uDiffusionSettings.x;
  float diffusionRateB = uDiffusionSettings.y;
  float feedRate = uDiffusionSettings.z;
  float killRate = uDiffusionSettings.w;

  // Reaction diffusion
  vec2 uvos = vec2(uv.x, uv.y);
  vec4 newState = vec4(0.0);
  vec4 oldState = texture2D(uTexture, uvos);
  newState.b = oldState.b * 0.98;

  newState.a = oldState.a * 0.9998;
  
  diffusionRateA += clamp(1.0 - newState.a, 0.02, 0.05) / 3.0;
  diffusionRateB -= clamp(newState.a, 0.075, 0.12) / 3.0;

  killRate += (1.0 - circle(uv, vec2(0.5, 0.5), 0.2 + 0.17 * pow(sin(uTime * 0.15), 3.0))) * 0.1;
  killRate += sin(uTime * 0.98) * 0.015 * simplex;
  feedRate -= cos(uTime * 1.26) * 0.0375 * simplex2;

  vec3 laplace = vec3(0.0);
  int range = 1;
  for (int x = -range; x <= range; x++) {
    for (int y = -range; y <= range; y++) {
      vec2 offset = vec2(x, y) / uResolution;
      vec3 value = texture2D(uTexture, uv + offset).rgg;
      if (x == 0 && y == 0) {
        laplace += value * -1.0f;
      }
      if (x == 0 && ((y < 0) || (y > 0))) {
        laplace += value * 0.2f;
      }
      if (y == 0 && ((x < 0) || (x > 0))) {
        laplace += value * 0.2f;
      }
      if ((y < 0 && x < 0) ||
          (y > 0 && x < 0) ||
          (y > 0 && x > 0) ||
          (y < 0 && x > 0)) {
        laplace += value * 0.05f;
      }
    }
  }

  newState.r = oldState.r +
               (laplace.r * diffusionRateA) -
               oldState.r * oldState.g * oldState.g +
               feedRate * (1.0 - oldState.r);
  newState.g = oldState.g +
               (laplace.g * diffusionRateB) +
               oldState.r * oldState.g * oldState.g -
               (killRate + feedRate) * oldState.g;
  newState.b = oldState.b +
               (laplace.b * diffusionRateB) +
               oldState.g * oldState.b * oldState.b -
               (killRate + feedRate) * oldState.b;

  // Drawing
  vec2 mouse = uMouse.xy;
  newState.r -= circle(uv, mouse, uBrush.x * 0.05) * uMouse.z * (oldState.r * 0.95) * 0.03;
  newState.g += circle(uv, mouse, uBrush.x * 0.05) * uMouse.z * 0.02 * sin(uv.x * 3.14159);
  newState.b += circle(uv, mouse, uBrush.x * 0.05) * uMouse.z * 0.03;

  gl_FragColor = vec4(newState.rgb, newState.a);
}
