import fpstracker.core.*;
import java.util.*;

PerfTracker pt;
ArrayList<CollatzOperator> collatzList;
float previousLoop;

void setup() {
  size(800, 800, P3D);
  smooth(8);
  pt = new PerfTracker(this, 120);

  background(20);
  init();


  Time.setStartTime(this);
}

void init() {
  collatzList = new ArrayList<CollatzOperator>();
  long startingPoint = randomLong(6171, 8400511L);
  long offset = randomLong(1L, 10000L);
  int numberOfbranch = 100;//round(random(10, 250));
  for (int i=0; i<numberOfbranch; i++) {
    long number = startingPoint + i * offset;
    float randomAngle = random(0.1, 0.01);
    pushMatrix();
    translate(width/2, height/2);

    CollatzOperator co = new CollatzOperator(number, HALF_PI * randomAngle, 10.0);
    collatzList.add(co);
    popMatrix();
  }
}

public long randomLong(long min, long max) {
  long val = min + (long) (Math.random() * (max - min));
  return val;
}

void draw() {
  //Time and scene management
  int maxTime = 2000;
  Time.update(this, false);
  Time.computeTimeAnimation(Time.time, maxTime);

  //println(Time.timeLoop, Time.timeLoop % 3, Time.normTime);
  float easedTime = 0.0;
  if (Time.timeLoop % 3 == 0) {
    easedTime = NormalEasing.inoutQuad(Time.normTime);
  } else if ( Time.timeLoop % 3 == 1) {
    easedTime = 1.0;
  } else {
    easedTime = 1.0 - NormalEasing.outExp(Time.normTime);
  }
  if (previousLoop != Time.timeLoop && Time.timeLoop % 3 == 0) {
    println("reinit");
    init();
    previousLoop = Time.timeLoop;
  } else {
  }
  
  //camera management
  float eta = frameCount * 0.01;
  float theta = PI*0.5;
  float radius = 500;
  float x = sin(theta) * cos(eta) * radius;
  float z = sin(theta) * sin(eta) * radius;
  float y = cos(theta) * radius;
  
  background(20);
  pushMatrix();
  camera(x, y, z, 0, 0, 0, 0, 1, 0);
  lights();

  for (int i=0; i<collatzList.size(); i++) {
    float normIndex = (float) i / (float) collatzList.size();
    CollatzOperator co = collatzList.get(i);
    //co.drawShape(g);
    //co.drawBox(g);
    co.drawAnimatedBox(g, easedTime);
  }
  popMatrix();
  
  noLights();
  pt.display(0, 0);
}

void keyPressed(){
  saveFrame("test.png");
}
