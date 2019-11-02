import fpstracker.core.*;

PerfTracker pt;
boolean pause;
float loop;
int seed = 1000;
float baseEta, baseTheta, basePhi;
float rndStart;

void setup() {
  size(800, 800, P3D);
  smooth(8);

  pt = new PerfTracker(this, 120);
  randomSeed(seed);
}

void draw() {
  Time.update(this, pause);
  Time.computeTimeAnimation(Time.time, 2000);
  float pingpong = 1.0 - abs((Time.normTime) * 2.0 - 1.0);
  float easedTime = NormalEasing.inoutQuad(pingpong);
  if (loop != Time.timeLoop) {
    println("reinit "+pingpong);
    loop = Time.timeLoop;
    seed = frameCount;
    rndStart = random(1000 + frameCount);
   // baseEta = random(TWO_PI);
   // baseTheta = random(PI);
    //basePhi = random(TWO_PI);
  }
  randomSeed(seed);//

  background(200);

  pushMatrix();
  translate(width/2, height/2);
  lights();
  rotateY(baseTheta + millis() * 0.000125);
  rotateX(baseEta + millis() * 0.000025);
  rotateZ(basePhi);
  noStroke();

  int dimXYZ = 25;
  int dimX = round(random(6, 8));
  int dimZ = round(random(6, 8));
  int dimY = round(random(8, 14));

  float offset = dimXYZ * 6.0;
  color based = color(255);
  color end = color(140, 75, 255);
  for (int x=0; x<dimX; x++) {
    float px = x * dimXYZ - dimX * dimXYZ * .5;
    float normX = (float)x/(float)dimX;
    float ssnx = smoothstep(0.25, 1.0, normX);
    for (int y=0; y<dimY; y++) { 
      float py = y * dimXYZ - dimY * dimXYZ *  .5;
      float normY = (float)y/(float)dimY;
      float ssny = smoothstep(0.0, .5, normY);
      float ssny2 = smoothstep(0.45, .75, normY);
      for (int z=0; z<dimZ; z++) {
        float pz = z * dimXYZ - dimZ * dimXYZ *  .5;
        float normZ = (float)z/(float)dimZ;
        float ssnz = smoothstep(0.25, 1.0, normZ);

        float easing = NormalEasing.inCirc(ssny);
        float easing2 = NormalEasing.inCirc(ssny2);
        float easingScale = map(easing * easedTime, 0, 1, 0.98, 0.65);

        //float eta   = random(PI * .5) * easing * easedTime;
        //float theta = random(PI * .5) * easing * easedTime;
        //float phi   = random(PI * .5) * easing * easedTime;
        float noiseAngle = 2.75;
        float eta   = noise(normX * noiseAngle) * PI * 1. * easing * easedTime;
        float theta = noise(normY * noiseAngle) * PI * 1. * easing * easedTime;
        float phi   = noise(normZ * noiseAngle) * PI * 1. * easing * easedTime;
        PVector rnd = PVector.random3D(this);
        rnd.mult(easing * offset * easedTime);
        
        float offsetX = random(-1, 1) * easing * offset * easedTime;
        float offsetY = random(-1, 1) * easing * offset * easedTime;
        float offsetZ = random(-1, 1) * easing * offset * easedTime;
        
        float noiseScale = 1.75;
        float noiseEta   = noise(rndStart + normX * noiseScale, rndStart + normY * noiseScale, rndStart + normZ * noiseScale) * PI;
        float noiseTheta = noise(rndStart + normZ * noiseScale, rndStart + normX * noiseScale, rndStart + normY * noiseScale) * TWO_PI;
        PVector noiseOffset = new PVector(
          sin(noiseEta) * cos(noiseTheta),
          sin(noiseEta) * sin(noiseTheta),
          cos(noiseEta)
        );
        noiseOffset.mult(easing * offset * easedTime);
        
        color col = lerpColor(based, end, easing2 * easedTime);

        pushMatrix();
        translate(px + noiseOffset.x, py + noiseOffset.y, pz + noiseOffset.z);
        rotateX(theta);
        rotateY(eta);
        rotateZ(phi);
        fill(col);
        box(dimXYZ * easingScale);
        popMatrix();
      }
    }
  }

  popMatrix();

  noLights();
  pt.display(0, 0);
}

float smoothstep(float edge0, float edge1, float x) {
  float t = constrain((x - edge0) / (edge1 - edge0), 0.0, 1.0);
  return t * t * (3.0 - 2.0 * t);
}

void keyPressed() {
  pause = !pause;
}
