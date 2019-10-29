import fpstracker.core.*;
import estudiolumen.simplepbr.*;

PerfTracker pt;

PBRMat custommat;
PImage displacementMap;

Poly3D crystal;
float phi, eta, theta;
boolean showNormal, showPoly, showWireframe;

void settings() {
  size(1280, 720, P3D);
  smooth(8);
}

void setup() {
  pt = new PerfTracker(this, 120);
  showPoly = true;
  showWireframe = true;
  showNormal = true;
  initCrystal();

  displacementMap = loadImage("noiseTexture.jpg");
  SimplePBR.init(this, "cubemap/Zion_Sunsetpeek");
  SimplePBR.setExposure(1.2f); // simple exposure control

  custommat = new PBRMat();//"Plaster/");
  custommat.setCustomShader("vert.glsl", "frag.glsl");
  custommat.setTexture("displacementMap", displacementMap);
  custommat.setTexture("albedoTex", displacementMap);
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

void draw() {
  background(20);
  custommat.setVector("mouse", mouseX/(float)width, mouseY/(float)height);

  SimplePBR.setDiffuseAttenuation(custommat.getShader(), 1.0f);
  SimplePBR.setReflectionAttenuation(custommat.getShader(), 0.25f);


  pushMatrix();
  //camera(0, 0, 500, 0, 0, 0, 0, -1.0, 0);
  translate(width/2, height/2, -0);
  rotateY(phi + millis() * 0.001);
  rotateX(eta);
  rotateZ(theta);
  lights();

  custommat.setRim(0.15f);
  custommat.setFloat("displacementFactor", 100.0);
  custommat.setFloat("time", millis() * 0.0001);
  custommat.setNormalIntensity(0.5f);
  custommat.setRougness(0.85f);
  custommat.setMetallic(0.9f);
  if (showPoly) {
    custommat.bind();
    shape(crystal.poly);
  }
  //resetShader();
  if (showWireframe) shape(crystal.wireframedHighPoly);

  if (showNormal) shape(crystal.polyNormal);

  popMatrix();

  noLights();
  resetShader();
  image(displacementMap, 0, 60, displacementMap.width * 0.25, displacementMap.height * 0.25);
  pt.display(0, 0);
}

void keyPressed() {
  switch(key) {
  case 'p' : 
    showPoly = !showPoly;
    break;
  case 'n' : 
    showNormal = !showNormal;
    break;
  case 'w' : 
    showWireframe = ! showWireframe;
    break;
  case 'r' : 
    initCrystal();
    break;
  }
}
