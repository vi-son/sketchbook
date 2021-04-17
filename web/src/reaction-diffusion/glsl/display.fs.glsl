precision highp float;

uniform int uFrame;
uniform float uTime;
uniform vec2 uResolution;
uniform sampler2D uTexture;

varying vec2 vUv;

void main() {
  vec2 uv = gl_FragCoord.xy / uResolution.xy;

  vec3 diffusionState = texture2D(uTexture, uv).rgb;

  vec3 color_a = vec3(25, 15, 93) / 255.0;
  vec3 color_b = vec3(125, 91, 167) / 255.0;
  vec3 color_c = vec3(21, 0, 245) / 255.0;
  vec3 color_d = vec3(0, 0, 0) / 255.0;

  vec3 color_tmp = mix(color_b, color_c, clamp(pow(diffusionState.g, 2.2), 0.0, 1.0));
  vec3 color_fg = vec3(1.0); // mix(color_tmp, color_d, clamp(pow(diffusionState.r - diffusionState.g, 3.5), 0.0, 1.0));
  vec3 color_bg = vec3(0.0);
  vec3 color = mix(color_fg, color_bg, smoothstep(0.1, 0.5, diffusionState.r));


  gl_FragColor = vec4(color, 1.0);
}
