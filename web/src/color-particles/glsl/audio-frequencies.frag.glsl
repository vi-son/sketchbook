varying vec2 vUv;

uniform int uFrame;
uniform float uTime;
uniform float uAverageFrequency;
uniform vec2 uResolution;
uniform sampler2D uAudioTexture;

float MAX_LOG = 5.541263545158426;

void main() {
  vec2 uv = vUv;
  uv = vec2(fract(uv.x + uTime / uAverageFrequency * 0.03), uv.y);
  vec4 audioData = texture2D(uAudioTexture, uv);
  float spectrum = clamp(log(audioData.r * 255.0) / MAX_LOG, 0.0, 1.0);
  gl_FragColor = vec4(spectrum, 0.0, 0.0, 1.0);
}
