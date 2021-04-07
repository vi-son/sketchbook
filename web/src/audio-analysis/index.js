import * as THREE from "three";
import Stats from "three/examples/jsm/libs/stats.module.js";
import PoissonDiskSampling from "poisson-disk-sampling";

// Shader
const vertexShader = require("./glsl/basic.vert.glsl");

const settings = {
  diffusionRateA: 1.0,
  diffusionRateB: 0.49,
  feedRate: 0.0545,
  killRate: 0.062,
  brushSize: 0.01,
};

const listener = new THREE.AudioListener();
const sound = new THREE.Audio(listener);
const audioLoader = new THREE.AudioLoader();
audioLoader.load(
  "/logo.exhibition.20201121.mp3",
  (buffer) => {
    sound.setBuffer(buffer);
    sound.setLoop(true);
    sound.setVolume(0.5);
    sound.play();
  },
  () => {},
  (err) => {
    console.error(err);
  }
);
const audioAnalyser = new THREE.AudioAnalyser(sound, 128);

const stats = new Stats();
document.body.appendChild(stats.dom);

const size = document.querySelector("#canvas").getBoundingClientRect();
const pixelRatio = 1.0;

var scene = new THREE.Scene();
var offscreenScene = new THREE.Scene();
var audioScene = new THREE.Scene();

var renderer = new THREE.WebGLRenderer({
  canvas: document.querySelector("#canvas"),
  antialias: true,
});
renderer.setSize(size.width, size.height);
renderer.setClearColor(0x9d9d94, 1.0);
renderer.setPixelRatio(pixelRatio);
const renderTargetSize = new THREE.Vector2(size.width, size.height);
const renderTargets = [0, 1].map(
  () =>
    new THREE.WebGLRenderTarget(renderTargetSize.x, renderTargetSize.y, {
      // wrapS: THREE.RepeatWrapping,
      // wrapT: THREE.RepeatWrapping,
      // minFilter: THREE.NearestFilter,
      // magFilter: THREE.NearestFilter,
      format: THREE.RGBFormat,
      type: THREE.FloatType,
      stencilBuffer: false,
    })
);

const camera = new THREE.OrthographicCamera(
  -2 / size.width,
  +2 / size.width,
  +2 / size.width,
  -2 / size.width,
  -1,
  100
);
camera.add(listener);
// const camera = new THREE.PerspectiveCamera(45, width / height, 0.1, 1000);
// camera.position.z = 3;
// scene.add(camera);

// const icoGeometry = new THREE.IcosahedronGeometry(1.0, 1);
// const icoMaterial = new THREE.MeshBasicMaterial({ color: 0xe4871d });
// const mesh = new THREE.Mesh(icoGeometry, icoMaterial);
// var geo = new THREE.WireframeGeometry(mesh.planeGeometry);
// var mat = new THREE.LineBasicMaterial({ color: 0x000000 });
// var wireframe = new THREE.LineSegments(geo, mat);
// mesh.add(wireframe);
// scene.add(mesh);

const mousePosition = new THREE.Vector2(0, 0);
let mouseDown = false;

window.addEventListener("pointermove", (e) => {
  const x = +((e.clientX - size.x) / size.width) * pixelRatio;
  const y = ((size.height - (e.clientY - size.y)) / size.height) * pixelRatio;
  mousePosition.set(x, y);
});

window.addEventListener("pointerdown", () => {
  mouseDown = true;
});
window.addEventListener("pointerup", () => {
  mouseDown = false;
});

const planeGeometry = new THREE.PlaneGeometry(2, 2);

const audioDataRenderTarget = new THREE.WebGLRenderTarget(
  size.width,
  size.height,
  {
    type: THREE.FloatType,
  }
);
console.log("Render Target Size", audioDataRenderTarget);
const audioDataMaterial = new THREE.ShaderMaterial({
  uniforms: {
    uFrame: { value: 0 },
    uFrequencies: { value: [] },
    uAverageFrequency: { value: 0.0 },
    uResolution: {
      value: new THREE.Vector2(size.width, size.height),
    },
  },
  vertexShader: vertexShader,
  fragmentShader: require("./glsl/audio-frequencies.frag.glsl"),
});
const audioPlane = new THREE.Mesh(planeGeometry, audioDataMaterial);
audioScene.add(audioPlane);

const feedbackMaterial = new THREE.ShaderMaterial({
  uniforms: {
    uBrush: {
      value: new THREE.Vector4(settings.brushSize, 0, 0, 0),
    },
    uDiffusionSettings: {
      value: new THREE.Vector4(
        settings.diffusionRateA,
        settings.diffusionRateB,
        settings.feedRate,
        settings.killRate
      ),
    },
    uFrame: { value: 0 },
    uTime: {
      value: 0,
    },
    uMouse: {
      value: new THREE.Vector3(mousePosition.x, mousePosition.y, mouseDown),
    },
    uResolution: {
      value: renderTargetSize,
    },
    uTexture: { value: renderTargets[0].texture },
    uAudioTexture: { value: audioDataRenderTarget.texture },
  },
  vertexShader: vertexShader,
  fragmentShader: require("./glsl/feedback.frag.glsl"),
});
const pingPlane = new THREE.Mesh(planeGeometry, feedbackMaterial);
offscreenScene.add(pingPlane);

const pongPlane = new THREE.Mesh(planeGeometry, feedbackMaterial);
scene.add(pongPlane);

const clock = new THREE.Clock(true);
clock.start();

let frameCount = 0;
let uFrameCounter = 0;

let averageFreqData = 0;
let freqData = [];

function renderLoop() {
  for (let i = 0; i < 5; i++) {
    averageFreqData = audioAnalyser.getAverageFrequency();
    freqData = audioAnalyser.getFrequencyData();

    // Render audio data
    audioDataMaterial.uniforms.uAverageFrequency.value = averageFreqData;
    audioDataMaterial.uniforms.uFrequencies.value = freqData;
    audioDataMaterial.uniforms.uFrame.value = uFrameCounter;

    renderer.setRenderTarget(audioDataRenderTarget);
    renderer.render(audioScene, camera);
    renderer.setRenderTarget(null);

    // Update uniforms
    feedbackMaterial.uniforms.uFrame.value = uFrameCounter;
    feedbackMaterial.uniforms.uTime.value = clock.getElapsedTime();
    feedbackMaterial.uniforms.uMouse.value.set(
      mousePosition.x,
      mousePosition.y,
      mouseDown
    );
    feedbackMaterial.uniforms.uAudioTexture.value =
      audioDataRenderTarget.texture;

    // 1. Render off screen
    renderer.setRenderTarget(renderTargets[(frameCount + 1) % 2]);
    renderer.render(offscreenScene, camera);
    renderer.setRenderTarget(null);

    // 2. Render on screen
    renderer.render(scene, camera);

    // 3. Swap
    if (frameCount % 2 === 0) {
      pingPlane.material.uniforms.uTexture.value = renderTargets[1].texture;
    } else {
      pongPlane.material.uniforms.uTexture.value = renderTargets[0].texture;
    }
    frameCount++;
    if (sound.isPlaying) {
      uFrameCounter++;
    }
  }

  stats.update();
}

renderer.setAnimationLoop(renderLoop);
