precision highp float;

#pragma glslify: PI = require("../../glsl/shader-library/webgl/pi.glsl")
#pragma glslify: TWO_PI = require("../../glsl/shader-library/webgl/pi.glsl")
#pragma glslify: pillow = require("../../glsl/shader-library/webgl/pillow.glsl")
#pragma glslify: random = require("../../glsl/shader-library/webgl/random.glsl")
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

float sd_sphere(in vec3 p, in float radius) {
  return length(p) - radius;
}

float sd_box(in vec3 p, in vec3 box) {
  vec3 q = abs(p) - box;
  return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

float sd_roundBox(in vec3 p, in vec3 box, in float cornerRadius) {
  vec3 q = abs(p) - box;
  return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0) - cornerRadius;
}

float sd_torus(in vec3 p, in vec2 torus) {
  vec2 q = vec2(length(p.xz) - torus.x, p.y);
  return length(q) - torus.y;
}

float sd_cone(in vec3 p, in vec2 cone, in float height) {
  // c is the sin/cos of the angle, h is height
  // Alternatively pass q instead of (c,h),
  // which is the point at the base in 2D
  vec2 q = height * vec2(cone.x / cone.y, -1.0);
  vec2 w = vec2(length(p.xz), p.y);
  vec2 a = w - q * clamp(dot(w, q) / dot(q, q), 0.0, 1.0);
  vec2 b = w - q * vec2(clamp(w.x / q.x, 0.0, 1.0), 1.0);
  float k = sign(q.y);
  float d = min(dot(a, a), dot(b, b));
  float s = max(k * (w.x * q.y - w.y * q.x), k * (w.y - q.y));
  return sqrt(d) * sign(s);
}

float sd_octahedron(in vec3 p, in float s)
{
  p = abs(p);
  float m = p.x + p.y + p.z - s;
  vec3 q;
  if (3.0 * p.x < m) q = p.xyz;
  else if (3.0 * p.y < m) q = p.yzx;
  else if (3.0 * p.z < m) q = p.zxy;
  else return m * 0.57735027;
  float k = clamp(0.5 * (q.z - q.y + s), 0.0, s); 
  return length(vec3(q.x, q.y - s + k, q.z - k)); 
}

float sdf(vec3 p) {
  p = rotate(p, vec3(sin(uTime * 0.7), sin(uTime * 0.9), cos(uTime * 1.1)), uTime);
  float box = sd_roundBox(p, vec3(0.3), 0.05);
  float sphere = sd_sphere(p, 0.3);
  float torus = sd_torus(p, vec2(0.2, 0.05));
  float cone = sd_cone(p, vec2(0.5, 0.5), 0.3 + cos(uTime + 2.0) / 10.0);
  float octahedron = sd_octahedron(p, clamp(0.4 + sin(uTime + 1.0) / 2.0, 0.4, 0.5));
  float united = op_min(sphere, cone, 0.5);
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
  vec4 color_a = vec4(30.0, 30.0, 30.0, 1.0) / 255.0;
  vec4 color_b = vec4(106.0, 106.0, 106.0, 1.0) / 255.0;
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

    float fresnel = pow(1.0 + dot(ray, normal), 3.0);

    color = mix(background, color, fresnel);
  }

  gl_FragColor = vec4(color, 1.0);
}
