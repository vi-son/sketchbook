precision highp float;

uniform int uFrame;
uniform float uTime;
uniform vec2 uResolution;
uniform sampler2D uTexture;

varying vec2 vUv;

float circle(in vec2 uv, in vec2 position, in float radius) {
  vec2 d = uv - position;
  d *= vec2(1.0, uResolution.y / uResolution.x);
  return 1.0 - smoothstep(radius - (radius * 0.9),
                          radius + (radius * 0.9),
                          dot(d, d) * 4.0);
}

void main() {
  vec2 uv = gl_FragCoord.xy / uResolution.xy;

  vec3 diffusionState = texture2D(uTexture, uv).rgb;

  vec3 color_a = vec3(245, 135, 33) / 255.0;
  vec3 color_b = vec3(64, 132, 163) / 255.0;
  vec3 color_c = vec3(21, 0, 25) / 255.0;
  vec3 color_d = vec3(4, 3, 3) / 255.0;

  float circle = circle(uv, vec2(0.5), 0.1);

  // vec3 color_tmp = mix(color_b, color_c, clamp(pow(diffusionState.g, 0.02), 0.0, 1.0));
  vec3 color_tmp = mix(color_b, color_c, circle);
  vec3 color_fg = mix(color_tmp, color_d, clamp(pow(diffusionState.r - diffusionState.g, 3.5), 0.0, 1.0));
  vec3 color_bg = color_a;
  vec3 color = mix(color_fg, color_bg, smoothstep(0.1, 0.5, diffusionState.g));

  color *= 2.0;


  gl_FragColor = vec4(color, 1.0);
}
