import * as THREE from "three";
import Stats from "three/examples/jsm/libs/stats.module.js";

// Shader
const vertexShader = require("./glsl/basic.vert.glsl");
const fragmentShader = require("./glsl/raymarch.frag.glsl");

// Stats
const stats = new Stats();
document.body.appendChild(stats.dom);

// Scene
const scene = new THREE.Scene();

// Renderer
const pixelRatio = 1.0;
const size = document.querySelector("#canvas").getBoundingClientRect();
const renderer = new THREE.WebGLRenderer({
  canvas: document.querySelector("#canvas"),
  antialias: true,
});
renderer.setSize(size.width, size.height);
renderer.setClearColor(0x9d9d94, 1.0);
renderer.setPixelRatio(pixelRatio);

// Camera
const camera = new THREE.OrthographicCamera(
  -1 / size.width,
  +1 / size.width,
  +1 / size.height,
  -1 / size.height,
  -1,
  100
);

// Clock
const clock = new THREE.Clock(true);
clock.start();

// Geometry
const raymarchMaterial = new THREE.ShaderMaterial({
  extensions: {
    derivatives: "#extensions GL_OES_standard_derivatives : enable",
  },
  side: THREE.DoubleSide,
  uniforms: {
    uTime: { value: 0 },
    uResolution: {
      value: new THREE.Vector2(size.width, size.height),
    },
    uMatcap: {
      value: new THREE.TextureLoader().load(
        "/textures/857B61_ACE5D4_593D28_5B4334.png"
      ),
    },
  },
  vertexShader: vertexShader,
  fragmentShader: fragmentShader,
});
const planeGeometry = new THREE.PlaneGeometry(2, 2);
const fullscreenQuad = new THREE.Mesh(planeGeometry, raymarchMaterial);
scene.add(fullscreenQuad);

let time = clock.getElapsedTime();
function renderLoop() {
  raymarchMaterial.uniforms.uTime.value = time;

  renderer.render(scene, camera);

  stats.update();
  time = clock.getElapsedTime();
}

renderer.setAnimationLoop(renderLoop);
