precision highp float;

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
  vec4 ad = texture2D(uAudioTexture, uv / uResolution);

  vec3 color_a = vec3(1, 0, 0);
  vec3 color_b = vec3(0, 1, 0.5);
  vec3 color_c = vec3(1, 1, 0);

  // float radius = 0.75;
  // float angle = 3.14159 * 0.2 * ad.r;
  // vec2 tc = uv;
  // tc -= vec2(0.5);
  // float dist = length(tc);
  // if (dist < radius) 
  // {
  //   float percent = (radius - dist) / radius;
  //   float theta = percent * percent * angle * 8.0 + ad.g;
  //   float s = sin(theta + uTime);
  //   float c = cos(theta + uTime);
  //   tc = vec2(dot(tc, vec2(c, -s)), dot(tc, vec2(s, c)));
  // }

  float r_inner = 0.5; 
  float r_outer = 0.7;

  // Polar coordinates for sampling
  vec2 x = uv / uResolution - vec2(0.5, 0.5);
  float radius = 1.0 - (length(x) + fract(uTime * (length(x) * 100.0)));
  float angle = atan(x.y, x.x);
  // the new polar texcoords
  vec2 tc_polar; 
  // map radius so that for r=r_inner -> 0 and r=r_outer -> 1
  tc_polar.t = (radius - r_inner) / (r_outer - r_inner);
  // map angle from [-PI,PI] to [0,1]
  tc_polar.s = (angle * 0.2 / PI + 0.49);

  // audioData.r *= smooth_circle;

  // vec3 color = vec3(0.0);
  // color = texture2D(uTexture, uv).rgb;

  //
  // Reaction diffusion
  //
  // float diffusionRateA = uDiffusionSettings.x;
  // float diffusionRateB = uDiffusionSettings.y;
  // float feedRate = uDiffusionSettings.z;
  // float killRate = uDiffusionSettings.w;

  // feedRate += (audioData.r - 0.5) / 500.0;
  // feedRate += smoothstep(0.0, 0.6, d) * audioData.r / 700.0;
  // killRate -= (audioData.r - 0.5) / 700.0;
  // killRate -= smoothstep(0.0, 0.6, d) / 300.0;

  vec4 newState = vec4(0.0);
  /*
  vec4 oldState = texture2D(uTexture, uv);
  newState.b = oldState.b * 0.998;

  diffusionRateA -= oldState.b / 100.0;
  diffusionRateB += oldState.b / 60.0;
  killRate += oldState.b / 300.0;
  feedRate -= oldState.b / 350.0;

  vec2 laplace = vec2(0.0);
  int range = 1;
  for (int x = -range; x <= range; x++) {
    for (int y = -range; y <= range; y++) {
      vec2 offset = vec2(x, y) / uResolution;
      vec2 value = texture2D(uTexture, uv + offset).rg;
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

  // Drawing
  newState.g += circle(uv, uMouse.xy, uBrush.x) * uMouse.z * 0.01;
  float s = (sin(texture2D(uAudioTexture, uv /  3.0).r * 3.14159) / 2.0) * 0.1;
  if (uv.x > 0.3 &&
      uv.x < 0.7 &&
      uv.y + s >= 0.499 && uv.y + s <= 0.505) {
    newState.g += texture2D(uAudioTexture, uv /  2.0).r  * 0.025;
  }

  /*
  float pixelX = mod(float(uFrame), uResolution.x);
  float pixelY = float(uFrame) / uResolution.x;

  vec2 uvS = vec2(uv.x * uResolution.x, (1.0 - uv.y) * uResolution.y);
  if (floor(uvS.x) == floor(pixelX) &&
      floor(uvS.y) == floor(pixelY)) {
    // color = vec3(pixelX / uResolution.x);
    color = vec3(texture2D(uAudioTexture, uv).g);
  }
  */

  //
  // Create a growing spectrum in y direction
  //
  // vec4 oldState = texture2D(uTexture, uv);
  // newState.b = oldState.b * 0.998;
  // float row = mod(float(uFrame), uResolution.y);
  // vec2 uvS = vec2(uv.x * uResolution.x, (1.0 - uv.y) * uResolution.y);
  // if (floor(uvS.y) == float(row)) {
  //   newState.b = texture2D(uAudioTexture, uv).r;
  // }

  vec2 uvs = (uv / uResolution - vec2(0.5)) * 0.975 + 0.5;
  vec4 oldState = texture2D(uTexture, uvs);
  newState.a += oldState.a * 0.995;

  newState *= 0.95;

  float audioSpectrum = texture2D(uAudioTexture, tc_polar).r;

  // Create a smoothed circle mask
  // vec2 uvc = (uv - vec2(0.5));
  // float d = sqrt(dot(uvc, uvc));
  vec2 center = (uResolution * 0.5);
  float d = length(center - uv) - 50.0;
  float di = length(center - uv) - 30.0;
  float t = 1.0 - (smoothstep(0.0, 1.0, d / uResolution.y));
  float smooth_circle = 1.0 - smoothstep(0.0, pow(audioSpectrum, 5.0) * 0.5, d / uResolution.y);

  newState.a += (smooth_circle * audioSpectrum) * 0.2;

  float center_circle = clamp(smoothstep(0.0, pow(audioSpectrum, 10.0) * 0.5, di / uResolution.y), 0.0, 1.0);
  newState.a *= pow(center_circle, 10.0);

  // Background color
  vec3 color_bga = vec3(13, 39, 136) / 255.0;
  vec3 color_bgb = vec3(55, 39, 215) / 255.0;
  vec2 gamma = vec2(6.0);
  vec3 color_background = pillow(color_bga, color_bgb, gamma, uv / uResolution).rgb + rand(uv * 100.0) / 100.0;

  vec3 color_start = mix(color_a, color_b, sin((tc_polar.s * 3.25 * PI) + PI / 1.75));
  vec3 color_mixed = mix(color_start, color_c, cos((tc_polar.s * 5.5 * PI) + PI / 13.0));
  vec3 out_color = mix(color_background, color_mixed , pow(newState.a, 0.25));

  // Grain
  // float amount = 0.5;
  // vec2 uvRandom = uv;
  // uvRandom.y *= grain(vec2(uvRandom.y, amount));
  // color.rgb += grain(uvRandom) * 0.05;

  gl_FragColor = vec4(out_color, clamp(newState.a, 0.0, 1.0));
  // gl_FragColor = vec4(vec3(center_circle), clamp(newState.a, 0.0, 1.0));
}
