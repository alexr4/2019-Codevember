PShader raymarcher;

void initRayMarcher(){
  raymarcher = loadShader("SphereNoise.glsl");
  raymarcher.set("u_resolution", (float) ctx.width, (float) ctx.height);
}
