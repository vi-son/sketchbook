const remap = (v, a, b, c, d) => {
  const newval = ((v - a) / (b - a)) * (d - c) + c;
  return newval;
};

export { remap };
