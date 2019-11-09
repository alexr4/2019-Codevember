import fpstracker.core.*;

PerfTracker pt;
boolean pause;
float loop;


void setup() {
  size(800, 800, P3D);
  smooth(8);

  pt = new PerfTracker(this, 120);
}

void draw() {
  Time.update(this, pause);
  Time.computeTimeAnimation(Time.time, 2000);
  float pingpong = 1.0 - abs((Time.normTime) * 2.0 - 1.0);
  float easedTime = NormalEasing.inoutQuad(pingpong);
  if (loop != Time.timeLoop) {
    println("reinit "+pingpong);
    loop = Time.timeLoop;
    
  }

  background(200);

  pushMatrix();
  translate(width/2, height/2);
  lights();
  rotateY(millis() * 0.000125);
  rotateX(millis() * 0.000025);
  //rotateY(HALF_PI * 0.25);
  //rotateX(HALF_PI * 0.25);
  //noStroke();

  float res = 10;
  float dimX = 20;
  float dimY = 20;
  float heightOffset = 150;
  float noiseScale = .01;
  float noiseStartX = 2500;
  float noiseStartY = 3500;
  
  beginShape(QUADS);
  for(int x=0; x<dimX; x++){
    for(int y=0; y<dimY; y++){
      PVector v0 = new PVector(
        x * res - dimX * res * 0.5,
        y * res - dimY * res * 0.5
      );
      
      PVector v1 = new PVector(
        (x+1) * res - dimX * res * 0.5,
        y * res - dimY * res * 0.5
      );
      
      PVector v2 = new PVector(
        (x+1) * res - dimX * res * 0.5,
        (y+1) * res - dimY * res * 0.5
      );
      
      PVector v3 = new PVector(
        x * res - dimX * res * 0.5,
        (y+1) * res - dimY * res * 0.5
      );
      
      v0.z = noise(noiseStartX + v0.x * noiseScale, noiseStartY + v0.y * noiseScale) * heightOffset;
      v1.z = noise(noiseStartX + v1.x * noiseScale, noiseStartY + v1.y * noiseScale) * heightOffset;
      v2.z = noise(noiseStartX + v2.x * noiseScale, noiseStartY + v2.y * noiseScale) * heightOffset;
      v3.z = noise(noiseStartX + v3.x * noiseScale, noiseStartY + v3.y * noiseScale) * heightOffset;    
  
      vertex(v0.x, v0.y, v0.z);
      vertex(v1.x, v1.y, v1.z);
      vertex(v2.x, v2.y, v2.z);
      vertex(v3.x, v3.y, v3.z);
    }
  }
  endShape();
  
  popMatrix();

  noLights();
  pt.display(0, 0);
}

float smoothstep(float edge0, float edge1, float x) {
  float t = constrain((x - edge0) / (edge1 - edge0), 0.0, 1.0);
  return t * t * (3.0 - 2.0 * t);
}

float pattern(float x, float y, float z, float mult, float inc, int octave){
  float qx = noise(x,y,z);
  float qy = noise(x+5.2*inc,y+1.3*inc,z+2.5*inc);
  float qz = noise (x-5.2*inc,y+2.3*inc,z-3.5*inc);
  randomSeed( 1000 );
  
  for(int i=1;i<octave;i++){
   qx = noise(x+qx*mult,y+qy*mult,z+qz*mult);
   qy = noise(x+qx*mult+random(10)*inc,y+qy*mult+ random(5)*inc,z+qz*mult+random(3)*inc);
   qz = noise (x+qx*mult-random(10)*inc,y+qy*mult-random(5)*inc,z+qz*mult-random(3)*inc);
    
  }
  
  return noise(x+qx*mult,y+qy*mult,z+qz*mult);
}

void keyPressed() {
  pause = !pause;
}
