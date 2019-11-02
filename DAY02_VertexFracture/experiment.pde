PBRMat custommat;

Poly3D crystal;
float phi, eta, theta;
boolean showNormal, showPoly, showWireframe;

PGraphics noiseTexture;
PShader noiseShader;

void initExperiment(){
  showPoly = true;
  showWireframe = true;
  showNormal = true;
  initCrystal();

  noiseTexture = createGraphics(1000, 1000, P2D);
  noiseShader = loadShader("fbmDW.glsl");
  noiseShader.set("time", 0.0, 0.0, 0.0);
  noiseShader.set("scale", 1.);// 1.0 + (float) mouseX / 250.0);
  noiseShader.set("cols", 5);
  noiseShader.set("rows", 5);
  noiseShader.set("octave", 8);
  noiseShader.set("amplitude", 0.5);
  noiseShader.set("frequency", 0.25);
  noiseShader.set("lacunarity", 2.0);
  noiseShader.set("gain", 0.5);
  //noiseShader.set("eta", 0.8);
  //noiseShader.set("gamma", 0.5);
  //noiseShader.set("dwInc", 24.6);

  noiseGeneration(noiseTexture, noiseShader);

  custommat = new PBRMat();//MEDIA.matpath);//"Plaster/");
  custommat.setCustomShader("vert.glsl", "frag.glsl");
  custommat.setTexture("displacementMap", noiseTexture);
  //custommat.setTexture("albedoTex", displacementMap);
  custommat.setTexture("mraoc", loadImage("mraocMap.png"));

  float projectionHeight = floor(1080.0 / (1920.0/1080.0));
  float ratio = floor(1920.0/projectionHeight);
  println(ratio);
  custommat.setFloat("textureRatio", (1920.0/1080.0));
  custommat.setVector("viewport", (float)width, (float)height);
}

void initCrystal() {
  phi = HALF_PI + random(-1.0, 1.0) * HALF_PI * 0.2;
  eta = random(-1.0, 1.0) * PI * 0.2;
  theta = random(-1.0, 1.0) * PI * 0.25;
  crystal = new Poly3D(new PVector(0, 0, 0), 100, 250, 100, 10, 10, 3);
}

void noiseGeneration(PGraphics buffer, PShader shader) {
  buffer.beginDraw();
  buffer.shader(shader);
  buffer.rect(0, 0, buffer.width, buffer.height);
  buffer.endDraw();
}
