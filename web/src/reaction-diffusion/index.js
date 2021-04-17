import * as THREE from "three";
import Stats from "three/examples/jsm/libs/stats.module.js";
import * as dat from "dat.gui";
import noisejs from "noisejs";

// Noise
const noise = new noisejs.Noise(1337);

// Stats
const stats = new Stats();
stats.dom.className = "stats";
document.body.appendChild(stats.dom);

//
const canvas = document.querySelector("#canvas");
let size = canvas.getBoundingClientRect();
const pixelRatio = 1.0;
const reactionDiffusionSettings = {
  diffusionRateA: 0.99,
  diffusionRateB: 0.28,
  feedRate: 0.0481,
  killRate: 0.0512,
  brushSize: 0.01,
};

//
let frameCount = 0;
let uFrameCounter = 0;
let freqData = [];

// Audio setup
const listener = new THREE.AudioListener();
// const sound = new THREE.Audio(listener);
// const audioLoader = new THREE.AudioLoader();
// audioLoader.load("patterns_20200628.mp3", function (buffer) {
//   sound.setBuffer(buffer);
//   sound.setLoop(true);
//   sound.setVolume(0.5);
//   sound.play();
// });
// const audioAnalyser = new THREE.AudioAnalyser(sound, 128);

// Camera
const camera = new THREE.OrthographicCamera(
  -2 / size.width,
  +2 / size.width,
  +2 / size.width,
  -2 / size.width,
  -1,
  100
);
camera.add(listener);

// Scenes
const scene = new THREE.Scene();
const offscreenScene = new THREE.Scene();

// Geometry
const planeGeometry = new THREE.PlaneGeometry(2, 2);

// Renderer
const renderer = new THREE.WebGLRenderer({
  canvas: canvas,
  antialias: true,
});
renderer.setSize(size.width, size.height);
renderer.setClearColor(0x9d9d94, 1.0);
renderer.setPixelRatio(pixelRatio);

// Render targets
const textureTargetScale = 0.25;
const renderTargetSize = new THREE.Vector2(
  size.width * textureTargetScale,
  size.height * textureTargetScale
);
const renderTargets = [0, 1].map(
  () =>
    new THREE.WebGLRenderTarget(renderTargetSize.x, renderTargetSize.y, {
      wrapS: THREE.RepeatWrapping,
      wrapT: THREE.RepeatWrapping,
      format: THREE.RGBAFormat,
      type: THREE.FloatType,
      stencilBuffer: false,
    })
);

// Interaction
const mousePosition = new THREE.Vector2(0, 0);
let mouseDown = false;

const screenToShader = (x, y) => {
  const _x = +((x - size.x) / size.width) * pixelRatio;
  const _y = ((size.height - (y - size.y)) / size.height) * pixelRatio;
  mousePosition.set(_x, _y);
};

window.addEventListener("pointermove", (e) => {
  const screenX = e.clientX;
  const screenY = e.clientY;
  screenToShader(screenX, screenY);
});

window.addEventListener("pointerdown", () => {
  mouseDown = true;
});

window.addEventListener("pointerup", () => {
  mouseDown = false;
});

window.addEventListener("resize", (e) => {
  // size = {
  //   width: document.body.scrollWidth,
  //   height: document.body.scrollHeight,
  // };
  // camera.aspect = size.width / size.height;
  // camera.updateProjectionMatrix();
  // renderer.setSize(size.width, size.height);
});

// Shader materials
const feedbackMaterial = new THREE.ShaderMaterial({
  uniforms: {
    uBrush: {
      value: new THREE.Vector4(reactionDiffusionSettings.brushSize, 0, 0, 0),
    },
    uDiffusionSettings: {
      value: new THREE.Vector4(
        reactionDiffusionSettings.diffusionRateA,
        reactionDiffusionSettings.diffusionRateB,
        reactionDiffusionSettings.feedRate,
        reactionDiffusionSettings.killRate
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
  },
  vertexShader: require("./glsl/basic.vs.glsl"),
  fragmentShader: require("./glsl/reaction-diffusion.fs.glsl"),
});
const pingPlane = new THREE.Mesh(planeGeometry, feedbackMaterial);
offscreenScene.add(pingPlane);

const displayMaterial = new THREE.ShaderMaterial({
  uniforms: {
    uFrame: { value: 0 },
    uTime: {
      value: 0,
    },
    uResolution: {
      value: new THREE.Vector2(size.width, size.height),
    },
    uTexture: { value: renderTargets[1].texture },
  },
  vertexShader: require("./glsl/basic.vs.glsl"),
  fragmentShader: require("./glsl/display.fs.glsl"),
});
const displayPlane = new THREE.Mesh(planeGeometry, displayMaterial);
scene.add(displayPlane);

// Timing
const clock = new THREE.Clock(true);
clock.start();

const renderLoop = () => {
  for (let i = 0; i < 4; i++) {
    const $t = clock.getElapsedTime();

    // Update uniforms
    feedbackMaterial.uniforms.uFrame.value = uFrameCounter;
    feedbackMaterial.uniforms.uTime.value = $t;
    feedbackMaterial.uniforms.uMouse.value.set(
      mousePosition.x,
      mousePosition.y,
      mouseDown
    );

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
      pingPlane.material.uniforms.uTexture.value = renderTargets[0].texture;
    }

    // mouseDown = true;
    // const perlin = noise.perlin2(
    //   mousePosition.x * 54.3,
    //   mousePosition.y * 70.0
    // );
    // const x = size.width * ((Math.sin($t * 0.3) + 1.0) / 2.0);
    // const y = size.height / 2 + perlin * (size.height / 2);
    // reactionDiffusionSettings.brushSize +=
    //   perlin * 0.2 * ((Math.sin((x / size.width) * Math.PI * 2.0) + 1.0) / 2.0);

    frameCount++;
  }
  stats.update();
};

renderer.setAnimationLoop(renderLoop);
