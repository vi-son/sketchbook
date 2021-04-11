precision highp float;

#pragma glslify: grain = require("../../glsl/shader-library/webgl/grain.glsl")
#pragma glslify: random = require("../../glsl/shader-library/webgl/random.glsl")

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

#define PI 3.14159265358979323844

varying vec2 vUv;

float rand(vec2 n) { 
	return fract(sin(dot(n, vec2(12.9898, 4.1414))) * 43758.5453);
}

vec3 pillow(in vec3 color_a, in vec3 color_b, in vec2 gamma, in vec2 uv)
{
  vec3 color = vec3(0.0);
  color.xy =
    (uv.st * 2.0 - vec2(1.0)) * 0.5 * vec2(-1, 1) * // x
    (uv.st * 2.0 - vec2(1.0)) * 0.5 * vec2(-1, 1) + 0.5; // y

  float fade =
    pow(smoothstep(-1.0, 1.0, 1.0 - 0.5 * (color.x - 0.5)), pow(2.0, gamma.x)) *
    pow(smoothstep(-1.0, 1.0, 1.0 - 0.5 * (color.y - 0.5)), pow(2.0, gamma.y));

  color = mix(color_a, color_b, fade);
  return color;
}

float circle(in vec2 uv, in vec2 position, in float radius) {
  vec2 d = uv - position;
  return 1.0 - smoothstep(radius - (radius * 0.01),
                          radius + (radius * 0.01),
                          dot(d, d) * 4.0);
}

void main() {
  vec2 uv = gl_FragCoord.xy;

  // Grain
  float grain_amount = 5.0;
  vec2 uvRandom = uv;
  uvRandom.y *= grain(vec2(uvRandom.y, grain_amount));

  // Audio texture
  vec4 ad = texture2D(uAudioTexture, uv / uResolution);

  // Colors
  vec3 color_a = vec3(0.83, 0.64, 0.6);
  vec3 color_b = vec3(0.75, 0.95, 0.95);
  vec3 color_c = vec3(0.91, 0.86, 0.3);

  // Polar coordinates for sampling
  float r_inner = 0.5; 
  float r_outer = 0.7;
  vec2 x = uv / uResolution - vec2(0.5, 0.5);
  float radius = 1.0 - (length(x) + fract(uTime * (length(x) * 100.0)));
  float angle = atan(x.y, x.x);
  // the new polar texcoords
  vec2 tc_polar; 
  // map radius so that for r=r_inner -> 0 and r=r_outer -> 1
  tc_polar.t = (radius - r_inner) / (r_outer - r_inner);
  // map angle from [-PI,PI] to [0,1]
  tc_polar.s = (angle / (2.0 * PI) + 0.5);

  vec4 newState = vec4(0.0);

  // Old state
  vec2 uvs = (uv / uResolution - vec2(0.5)) * 0.993 + 0.5;
  vec4 oldState = texture2D(uTexture, uvs + (grain(uvRandom) * 0.001) - 0.0005);
  newState.a += oldState.a * 0.993;

  newState *= 0.96;

  float audioSpectrum = texture2D(uAudioTexture, tc_polar).r;

  vec2 center = (uResolution * 0.5);
  float d = length(center - uv);
  float da = d - 50.0;
  float di = d - 3.0;
  float t = 1.0 - (smoothstep(0.0, 1.0, d / uResolution.y));
  float smooth_circle = 1.0 - smoothstep(0.0, 0.25 * pow(audioSpectrum, 5.0), da / uResolution.y);

  newState.a += (smooth_circle * audioSpectrum);
  newState.a -= 1.0 - smoothstep(0.0, 0.05 * pow(audioSpectrum, 0.5), da / uResolution.y);
  newState.a = clamp(newState.a, 0.0, 1.0);

  // Background color
  vec3 color_bga = vec3(3, 19, 116) / 255.0;
  vec3 color_bgb = vec3(55, 39, 215) / 255.0;
  vec2 gamma = vec2(6.0);
  vec3 color_background = pillow(color_bga, color_bgb, gamma, uv / uResolution).rgb + rand(uv * 100.0) / 100.0;

  tc_polar.s += grain(uv / uResolution.y) * 0.05 * (d / uResolution.y);
  vec3 color_start = mix(color_a, color_b, sin((tc_polar.s * 2.25 * PI) + PI / 8.65));
  vec3 color_mixed = mix(color_start, color_c, cos((tc_polar.s * 7.95 * PI) + PI / 12.23));
  vec3 out_color = mix(color_background, color_mixed , pow(newState.a, 0.25));

  out_color.rgb += grain(uvRandom) * d / uResolution.y * 0.05;

  gl_FragColor = vec4(out_color, clamp(newState.a, 0.0, 1.0));
}
