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

float circle(in vec2 uv, in vec2 position, in float radius) {
  vec2 d = uv - position;
  return 1.0 - smoothstep(radius - (radius * 0.01),
                          radius + (radius * 0.01),
                          dot(d, d) * 4.0);
}

void main() {
  vec2 uv = vUv;
  vec4 ad = texture2D(uAudioTexture, uv);

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
  vec2 x = uv - vec2(0.5);
  float radius = 1.0 - (length(x) + fract(uTime));
  float angle = atan(x.y, x.x);
  // the new polar texcoords
  vec2 tc_polar; 
  // map radius so that for r=r_inner -> 0 and r=r_outer -> 1
  tc_polar.s = (radius - r_inner) / (r_outer - r_inner);
  // map angle from [-PI,PI] to [0,1]
  tc_polar.t = (angle * 0.2 / PI + 0.5);
  tc_polar.st = tc_polar.ts;

  // audioData.r *= smooth_circle;

  // vec3 color = vec3(0.0);
  // color = texture2D(uTexture, uv).rgb;

  //
  // Reaction diffusion
  //
  float diffusionRateA = uDiffusionSettings.x;
  float diffusionRateB = uDiffusionSettings.y;
  float feedRate = uDiffusionSettings.z;
  float killRate = uDiffusionSettings.w;

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

  vec2 uvs = (uv - vec2(0.5)) * 0.975 + 0.5;
  vec4 oldState = texture2D(uTexture, uvs);
  newState.b += oldState.b * 0.995;

  newState *= 0.98;

  float audioSpectrum = texture2D(uAudioTexture, tc_polar).r;

  // Create a smoothed circle mask
  vec2 uvc = (uv - vec2(0.5)) * 1.5;
  float d = sqrt(dot(uvc, uvc));
  float t = 1.0 - smoothstep(0.0, 1.0, d);
  float smooth_circle = 1.0 - smoothstep(0.0, pow(audioSpectrum, 5.0) * 0.2, d);

  newState.b += (smooth_circle * audioSpectrum) * 0.2;
  newState.b -= smooth_circle * 0.1;

  vec3 out_color = vec3(newState.b);
  gl_FragColor = vec4(out_color, 1.0);
}
