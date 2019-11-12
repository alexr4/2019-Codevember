import fpstracker.core.*;
import processing.svg.*;

PerfTracker pt;

Rectangle aabb;
QuadTree quadtree;

PGraphics dataBuffer;
float resScreen= 50.0 / 70.0; 
boolean isComputed;
boolean debug = true;

//DIFFERENTIAL GROWTH SIMULATION
ArrayList<DGS> dgsdays;


void settings() {
  float res = 1.0;
  int w = 700;
  int h = floor(w / resScreen);
  size(w, h, P3D);
  smooth(8);
}

void setup() {
  pt = new PerfTracker(this, 100);


  aabb = new Rectangle(width * 0.5, height * 0.5, width * 0.5, height * 0.5);
  quadtree = new QuadTree(aabb, 8);

  dgsdays = new ArrayList<DGS>();
  int nbDay = 1;
  float x = width/2;
  float res = height;
  float resX = 200;
  
  float offset = (resX * nbDay) / 2; 
  for (int i=0; i<nbDay; i++) {
    DGS dgs = new DGS(quadtree);
    //dgs.initAsLine(x + i * 40 - offset * .5, 0, x + i * 40 - offset * .5, height);
    dgs.initAsCircle();
    //dgs.initAsSpiral();
    dgsdays.add(dgs);
  }

  frameRate(300);
  background(0.1);
  surface.setLocation(10, 10);
}

void draw() {
  int nbElem = 8000;
  for (int i=0; i<dgsdays.size(); i++) {
    DGS dgs = dgsdays.get(i);
    float normindex = (float) i / (float) dgsdays.size();
    int nbElement = dgs.getNumberOfNode(); 
    if (nbElement < nbElem) {
      dgs.run();
      dgs.addRandomNode();
    }

    //dgs.displayDebug(g, normindex, 1.0);
  }

  background(20);
  pushMatrix();
  float theta = millis() * 0.001;
  float radius = 500;
  float cx = cos(theta) * radius + width/2;
  float cz = sin(theta) * radius;
  float cy = height/2;
  camera(cx, cy, cz, width/2, height/2, 0, 0, 1, 0);
  lights();
  
  float offset = 250;
  //ambientLight(40, 40, 40);
  pointLight(240, 240, 240, width/2-offset, height/2, 0);
 // pointLight(240, 240, 240, width/2+offset, height/2, 0);

  stroke(255);
  strokeWeight(10);
  point(width/2-offset, height/2, 0);
  //point(width/2+offset, height/2, 0);
  strokeWeight(1);


  float len = 10;
  float len2 = 100;
  PVector extrude = new PVector(0, 0, len);
  //translate(width/2, height/2);
  fill(255);
  noStroke();
  for (int i=0; i<dgsdays.size(); i++) {
    DGS dgs = dgsdays.get(i);

    beginShape(TRIANGLES);
    for (int j=0; j<dgs.nodeList.size()-1; j++) {
      Node nodeJ = dgs.nodeList.get(j);
      Node nodeJN = dgs.nodeList.get(j+1);
      
      int nextIndex = i+2;
      if(nextIndex >= dgs.nodeList.size()-1){
        nextIndex = i-1;
      }
      
      float normi = (float)j/(float)dgs.nodeList.size();
      float noiseRed = noise(normi * 50., millis() *0.001) * 255;
      float noiseGreen = noise(normi * 50. + 0.25 * 50, millis() *0.001) * 255;
      float noiseBlue = noise(normi * 50. + 0.5 * 50, millis() *0.001) * 255;

      PVector vert0 = nodeJ.location.copy();//.sub(extrude);
      PVector vert1 = nodeJ.location.copy().add(extrude);
      PVector vert2 = nodeJN.location.copy();//.sub(extrude);
      PVector vert3 = nodeJN.location.copy().add(extrude);
      
      
      PVector v0v1 = PVector.sub(vert0, vert1);
      PVector v0v2 = PVector.sub(vert0, vert2);
      PVector normABC = v0v1.cross(v0v2).normalize();
      
      PVector v2v3 = PVector.sub(vert2, vert3);
      PVector v2v1 = PVector.sub(vert2, vert1);
      PVector normCDB = v2v3.cross(v2v1).normalize();
      
      //fill(normi, 1, 1);
      fill(noiseRed, noiseGreen, noiseBlue);
      normal(normABC.x, normABC.y, normABC.z);
      vertex(vert0.x, vert0.y, vert0.z);
      normal(normABC.x, normABC.y, normABC.z);
      vertex(vert1.x, vert1.y, vert1.z);
      normal(normABC.x, normABC.y, normABC.z);
      vertex(vert2.x, vert2.y, vert2.z);

      normal(normCDB.x, normCDB.y, normCDB.z);
      vertex(vert2.x, vert2.y, vert2.z);
      normal(normCDB.x, normCDB.y, normCDB.z);
      vertex(vert3.x, vert3.y, vert3.z);
      normal(normCDB.x, normCDB.y, normCDB.z);
      vertex(vert1.x, vert1.y, vert1.z);
      
      fill(140);
      normal(normABC.x, normABC.y, normABC.z);
      vertex(vert0.x, vert0.y, vert0.z + len);
      normal(normABC.x, normABC.y, normABC.z);
      vertex(vert1.x, vert1.y, vert1.z + len2);
      normal(normABC.x, normABC.y, normABC.z);
      vertex(vert2.x, vert2.y, vert2.z + len);

      normal(normCDB.x, normCDB.y, normCDB.z);
      vertex(vert2.x, vert2.y, vert2.z + len);
      normal(normCDB.x, normCDB.y, normCDB.z);
      vertex(vert3.x, vert3.y, vert3.z + len2);
      normal(normCDB.x, normCDB.y, normCDB.z);
      vertex(vert1.x, vert1.y, vert1.z + len2);
    }
    endShape(CLOSE);
  }
  popMatrix();

  noLights();
  pt.display(0, 0);
}







void keyPressed() {
}
