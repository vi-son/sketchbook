import * as THREE from "three";
import { OrbitControls } from "three/examples/jsm/controls/OrbitControls.js";
import { BufferGeometryUtils } from "three/examples/jsm/utils/BufferGeometryUtils.js";
import { Noise } from "noisejs";

const noise = new Noise(0);

const size = {
  width: window.innerWidth,
  height: window.innerHeight,
};

const scene = new THREE.Scene();

const renderer = new THREE.WebGLRenderer({
  canvas: document.querySelector("#canvas"),
  antialias: true,
});
renderer.setSize(size.width, size.height);
renderer.setClearColor(0xfafafa);

const fov = 45;
const aspect = size.width / size.height;
const near = 0.1;
const far = 1000;
const camera = new THREE.PerspectiveCamera(fov, aspect, near, far);
camera.position.set(10, 10, 10);
scene.add(camera);

const controls = new OrbitControls(camera, renderer.domElement);

const material = new THREE.MeshNormalMaterial();

const COUNT = 10000;
const geometries = [];
let matrix = new THREE.Matrix4();
let position = new THREE.Vector3();
let rotation = new THREE.Euler(0, 0, 0, "XYZ");
let quaternion = new THREE.Quaternion();
let scale = new THREE.Vector3();
for (let i = 0; i < COUNT; i++) {
  const geometry = new THREE.CylinderBufferGeometry(0.2, 1.0, 0.5, 10);
  position.x = (Math.random() - 0.5) * 5;
  position.y = 0;
  position.z = (Math.random() - 0.5) * 5;
  const perlin = noise.perlin3(
    position.x * 0.5,
    position.y * 0.5,
    position.z * 0.5
  );
  position.y = perlin;
  scale.set(0.05 * perlin, 0.5 * (perlin + 1.0), 0.05 * perlin);
  rotation.set(0, 0, 0);
  quaternion.setFromEuler(rotation, false);
  matrix.compose(position, quaternion, scale);
  geometry.applyMatrix4(matrix);
  geometries.push(geometry);
}
const geometry = BufferGeometryUtils.mergeBufferGeometries(geometries);
const mesh = new THREE.Mesh(geometry, material);
scene.add(mesh);

const renderLoop = () => {
  renderer.render(scene, camera);
  // console.log(renderer.info.render.calls);
};
renderer.setAnimationLoop(renderLoop);
