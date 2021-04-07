import * as THREE from "three";
import Stats from "three/examples/jsm/libs/stats.module.js";
import PoissonDiskSampling from "poisson-disk-sampling";
import { getEnergy } from "./audio.js";
import { remap } from "./utils.js";

let sampleRate = 1;
const listener = new THREE.AudioListener();
const sound = new THREE.Audio(listener);
const audioLoader = new THREE.AudioLoader();
audioLoader.load(
  "/logo.exhibition.20201121.mp3",
  (buffer) => {
    sampleRate = buffer.sampleRate;
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
const audioAnalyser = new THREE.AudioAnalyser(sound, 32);

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

const camera = new THREE.OrthographicCamera(
  -1000000 / size.height,
  +1000000 / size.height,
  +1000000 / size.width,
  -1000000 / size.width,
  -100,
  +100
);

const radius = 15;
const circleCenterRadius = radius;
const poissonWidth = 30 * radius;
const innerRadius = radius;
const outerRadius = innerRadius * 10;
const p = new PoissonDiskSampling({
  shape: [poissonWidth, poissonWidth],
  minDistance: innerRadius,
  maxDistance: outerRadius,
  tries: 10,
});
const points = p.fill();
console.log(points);

// Center
const geometry = new THREE.CircleGeometry(radius / 2.0, 100);
const dotMaterial = new THREE.MeshBasicMaterial({ color: 0xffffff });
const centerCircle = new THREE.Mesh(geometry, dotMaterial);
scene.add(centerCircle);
const outerCircles = [];
// Outer dots
for (var pt = 0; pt < points.length; pt++) {
  var point = points[pt];
  var angle = Math.atan2(
    point[1] - poissonWidth / 2,
    point[0] - poissonWidth / 2
  );
  const spectralIndex = Math.floor(
    (((angle % Math.PI) + Math.PI) / (Math.PI * 2.0)) * 32 // @TODO
  );
  const amp = Math.random() / 5.0;
  const energy = outerRadius * amp;
  const distance = new THREE.Vector2(
    poissonWidth / 2,
    poissonWidth / 2
  ).distanceTo(new THREE.Vector2(point[0], point[1]));
  // if (distance > innerRadius * 40 || distance < circleCenterRadius) continue;
  const wavePoint = new THREE.Vector2(
    (radius + energy) * Math.cos(angle),
    (radius + energy) * Math.sin(angle)
  );
  const distanceWavePoint = new THREE.Vector2(0, 0).distanceTo(wavePoint);
  var distancePointToWavePoint = wavePoint.distanceTo(
    new THREE.Vector2(point[0] - poissonWidth / 2, point[1] - poissonWidth / 2)
  );
  const circleRadius = remap(
    0.5 - distancePointToWavePoint / radius,
    0.3,
    0.5,
    0,
    innerRadius / 2000.0
  );
  if (distance > innerRadius * 15 || distance < circleCenterRadius * 8)
    continue;
  const geometry = new THREE.CircleGeometry(radius, 32);
  geometry.scale(circleRadius, circleRadius, circleRadius);
  const mesh = new THREE.Mesh(geometry, dotMaterial);
  mesh.position.set(point[0] - poissonWidth / 2, point[1] - poissonWidth / 2);
  outerCircles.push(mesh);
  scene.add(mesh);
}

const clock = new THREE.Clock(true);
clock.start();

let time = 0;
let frameCount = 0;
let averageFreqData = 0;
let freqData = [];

function renderLoop() {
  // Data
  time = clock.getElapsedTime();
  averageFreqData = audioAnalyser.getAverageFrequency();
  freqData = audioAnalyser.getFrequencyData();

  const breath = Math.sin(time) * Math.cos(time) + 1.0;
  const insideBreath = 0.65 + breath / 3.0;
  const inverseBreath = 0.75 + (1.0 - breath / 2.0) * 10.0;
  const bass = getEnergy(freqData, sampleRate, "bass");
  const circleCenterRadius = remap(
    Math.pow(bass, 2),
    0,
    512 * 512,
    innerRadius / 6,
    innerRadius
  );

  // Center circle
  centerCircle.scale.set(
    insideBreath + circleCenterRadius,
    insideBreath + circleCenterRadius,
    insideBreath + circleCenterRadius
  );

  // Small circles
  const waveRadius = outerRadius;
  const outerCircleRadius = breath * waveRadius;
  for (let pt = 0; pt < points.length; pt++) {
    const point = points[pt];
    const angle = Math.atan2(
      point[1] - poissonWidth / 2,
      point[0] - poissonWidth / 2
    );
    const spectralIndex = Math.floor(
      ((((angle + time) % Math.PI) + Math.PI) / (Math.PI * 2.0)) *
        freqData.length
    );
    const amp = freqData[spectralIndex] / 512;
    const energy = waveRadius * amp;
    const wavePoint = new THREE.Vector2(
      (radius + energy) * Math.cos(angle),
      (radius + energy) * Math.sin(angle)
    );
    const distanceWavePoint = new THREE.Vector2(0, 0).distanceTo(wavePoint);
    const distancePointToWavePoint = wavePoint.distanceTo(
      new THREE.Vector2(
        point[0] - poissonWidth / 2,
        point[1] - poissonWidth / 2
      )
    );
    const circleRadius = remap(
      0.5 - distancePointToWavePoint / waveRadius,
      0.3,
      0.5,
      0,
      innerRadius
    );
    const outerCircle = outerCircles[pt];
    // outerCircle.position.set(wavePoint.x, wavePoint.y, 0);
  }

  // Render
  renderer.render(scene, camera);

  frameCount++;
  stats.update();
}

renderer.setAnimationLoop(renderLoop);
