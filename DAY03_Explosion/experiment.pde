color HSBtoRGB(float h, float s, float b) {
  //Color.HSBtoRGB(h, s, b) où h, s et b sont comrpis entre 0 et 1f;
  return Color.HSBtoRGB(h, s, b);// où h, s et b sont comrpis entre 0 et 1f;
}

color RGBtoHSB(color rgb) {
  int r = (rgb >> 16) & 0xFF;
  int g = (rgb >> 8) & 0xFF;
  int b = (rgb) & 0xFF;
  float[] hsb = Color.RGBtoHSB(r, g, b, null);
  return color(hsb[0], hsb[1], hsb[2]);
}
