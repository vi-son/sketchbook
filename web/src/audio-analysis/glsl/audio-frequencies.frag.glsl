varying vec2 vUv;

uniform int uFrame;
uniform float uAverageFrequency;
uniform float uFrequencies[64];
uniform vec2 uResolution;

float MAX_LOG = 5.541263545158426;

void main() {
  vec3 color = vec3(0.0);
  vec2 uv = vUv;
  ivec2 iuv = ivec2(uv * 64.0);
  float spectrum = clamp(log(uFrequencies[iuv.x]) / MAX_LOG, 0.0, MAX_LOG);
  float average = clamp(log(uAverageFrequency) / MAX_LOG, 0.0, MAX_LOG);
  gl_FragColor = vec4(spectrum, average, 0, 1.0);
}
