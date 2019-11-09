import fpstracker.core.*;

PerfTracker pt;
boolean pause;
float loop;

PShader normal, voronoi;
PGraphics voroBuffer, normBuffer;

void setup() {
  size(1600, 800, P3D);
  smooth(8);

  pt = new PerfTracker(this, 120);
  
  voroBuffer = createGraphics(height, height, P2D);
  normBuffer = createGraphics(height, height, P2D);
  
  voronoi = loadShader("voronoi.glsl");
  voronoi.set("u_resolution", (float)voroBuffer.width, (float)voroBuffer.height);
  normal = loadShader("PP_NormalMapping.glsl");
}

void draw() {
  Time.update(this, pause);
  Time.computeTimeAnimation(Time.time, 4000);
  float pingpong = 1.0 - abs((Time.normTime) * 2.0 - 1.0);
  float easedTime = NormalEasing.inoutQuad(Time.normTime);
  if (loop != Time.timeLoop) {
    println("reinit "+pingpong);
    loop = Time.timeLoop;
    
  }

  background(200);
  float nmx = norm(mouseX, 0, width);
  
  voronoi.set("u_time", Time.time * 0.001);
  voronoi.set("normTime", easedTime);
  voronoi.set("orientation", loop % 2.0);
  voroBuffer.beginDraw();
  voroBuffer.shader(voronoi);
  voroBuffer.rect(0, 0, voroBuffer.width, voroBuffer.height);
  voroBuffer.endDraw();
  
  //normal.set("sobel1Scale", nmx);
  //normal.set("sobel2Scale", nmx);
  normBuffer.beginDraw();
  normBuffer.shader(normal);
  normBuffer.image(voroBuffer, 0, 0);
  normBuffer.endDraw();
 
  image(voroBuffer,0, 0);
  image(normBuffer,height, 0);
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
