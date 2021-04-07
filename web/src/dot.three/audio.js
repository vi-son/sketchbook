const getEnergy = function (spectrum, sampleRate, frequency1, frequency2) {
  const nyquist = sampleRate / 2;

  const bass = [20, 140];
  const lowMid = [140, 400];
  const mid = [400, 2600];
  const highMid = [2600, 5200];
  const treble = [5200, 14000];

  if (frequency1 === "bass") {
    frequency1 = bass[0];
    frequency2 = bass[1];
  } else if (frequency1 === "lowMid") {
    frequency1 = lowMid[0];
    frequency2 = lowMid[1];
  } else if (frequency1 === "mid") {
    frequency1 = mid[0];
    frequency2 = mid[1];
  } else if (frequency1 === "highMid") {
    frequency1 = highMid[0];
    frequency2 = highMid[1];
  } else if (frequency1 === "treble") {
    frequency1 = treble[0];
    frequency2 = treble[1];
  }

  if (typeof frequency1 !== "number") {
    throw "invalid input for getEnergy()";
  } else if (!frequency2) {
    const index = Math.round((frequency1 / nyquist) * spectrum.length);
    return spectrum[index];
  } else if (frequency1 && frequency2) {
    if (frequency1 > frequency2) {
      const swap = frequency2;
      frequency2 = frequency1;
      frequency1 = swap;
    }

    const lowIndex = Math.round((frequency1 / nyquist) * spectrum.length);
    const highIndex = Math.round((frequency2 / nyquist) * spectrum.length);
    let total = 0;
    let numFrequencies = 0;
    for (let i = lowIndex; i <= highIndex; i++) {
      total += spectrum[i];
      numFrequencies += 1;
    }
    const toReturn = total / numFrequencies;
    return toReturn;
  } else {
    throw "invalid input for getEnergy()";
  }
};

export { getEnergy };
