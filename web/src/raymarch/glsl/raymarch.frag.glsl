precision highp float;

#pragma glslify: PI = require("../../glsl/shader-library/webgl/pi.glsl")
#pragma glslify: TWO_PI = require("../../glsl/shader-library/webgl/pi.glsl")
#pragma glslify: pillow = require("../../glsl/shader-library/webgl/pillow.glsl")
#pragma glslify: grain = require("../../glsl/shader-library/webgl/grain.glsl")
#pragma glslify: matcap = require("../../glsl/shader-library/webgl/raymarching/matcap.glsl") 
#pragma glslify: axisAngleRotationMatrix = require("../../glsl/shader-library/webgl/transformations/rotate3d.glsl")

uniform float uTime;
uniform vec4 uResolution;
uniform sampler2D uMatcap;

varying vec2 vUv;

float op_twist(in vec3 p) {
  float k = 0.5;
  float c = cos(k * p.x);
  float s = sin(k * p.x);
  mat2 m = mat2(c, -s, s, c);
  vec3 q = vec3(m * p.yz, p.z);
  
  float radius = 0.8; //((cos(time) / 4.0 + 1.0) * 0.5) + 0.2;
  float dist = 0.0; //distance_from_sphere(reflect(p, q), vec3(0.25), radius);
  return dist;
}

float op_smooth_union(in float d1, in float d2, in float k) {
  float h = clamp(0.5 + 0.5 * (d2-d1) / k, 0.0, 1.0);
  return mix(d2, d1, h) - k * h * (1.0 - h);
}

// polynomial smooth min (k = 0.1);
float op_min(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b-a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

vec3 rotate(in vec3 p, in vec3 axis, in float angle) {
  mat4 r = axisAngleRotationMatrix(normalize(axis), angle);
  return (r * vec4(p, 1.0)).xyz;
}

float sdSphere(vec3 p, float r) {
  return length(p) - r;
}

float sdBox(in vec3 p, vec3 box) {
  vec3 q = abs(p) - box;
  return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

float sdf(vec3 p) {
  p = rotate(p, vec3(0, 1, 1), uTime);

  float box = sdBox(p, vec3(0.3));
  float sphere = sdSphere(p, 0.4);

  float united = op_min(box, sphere, 0.1);
  return united;
}

vec3 calculateNormals(in vec3 p) {
  const float epsilon = 0.0001;
  const vec2 h = vec2(epsilon, 0.0);
  return normalize(vec3(sdf(p + h.xyy) - sdf(p - h.xyy),
                        sdf(p + h.yxy) - sdf(p - h.yxy),
                        sdf(p + h.yyx) - sdf(p - h.yyx)));
}

void main() {
  float aspect = uResolution.y / uResolution.x;
  vec2 uv = (vUv - vec2(0.5)) * vec2(1.0, aspect);

  vec3 color = vec3(0.0);

  // Background
  vec4 color_a = vec4(9.0, 3.0, 3.0, 1.0) / 255.0;
  vec4 color_b = vec4(46.0, 39.0, 39.0, 1.0) / 255.0;
  vec2 gamma = vec2(5.0);
  vec3 background = pillow(color_a, color_b, gamma, vUv).rgb;
  color = background;

  // Raymarching
  vec3 cameraPosition = vec3(0.0, 0.0, 2.0);
  vec3 ray = normalize(vec3(uv, -1));

  float t = 0.0;
  float tMax = 5.0;
  for (int i=0; i < 255; i++) {
    vec3 position = cameraPosition + t * ray;
    float h = sdf(position);
    if (h < 0.0001 || t > tMax) {
      break;
    }
    t += h;
  }

  if (t < tMax) {
    vec3 position = cameraPosition + t * ray;
    vec3 normal = calculateNormals(position);

    vec2 matcap_uv = matcap(ray, normal);
    color = texture(uMatcap, matcap_uv).rgb;

    float fresnel = pow(1.0 + dot(ray, normal), sin(uTime * 2.0) * 2.0);

    color = mix(color, background, 1.0 - fresnel);
  }

  gl_FragColor = vec4(color, 1.0);
}
