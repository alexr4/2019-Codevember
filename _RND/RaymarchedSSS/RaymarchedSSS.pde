import fpstracker.core.*;
import gpuimage.core.*;

PerfTracker pt;
PShader raymarcher, dof, FXAA;
PGraphics buffer;
Filter filter;

boolean livecoding = true;;

void setup() {
  size(800, 800, P2D);
  pt = new PerfTracker(this, 120);

  buffer = createGraphics(width, height, P2D);
  filter = new Filter(this, buffer.width, buffer.height);
  raymarcher = loadShader("raymarcher.glsl");
  raymarcher.set("resolution", (float)buffer.width, (float)buffer.height);
  raymarcher.set("ramp", loadImage("rampsimple.png"));
  dof = loadShader("hexagonalDOF.glsl");
  FXAA = loadShader("fxaa.glsl");
}

void draw() {
  background(255);
  compute(livecoding);

  image(filter.getBuffer(), 0, 0);
  pt.display(0, 0);
  pt.displayOnTopBar(livecoding);
}

void keyPressed(){
  livecoding = !livecoding;
}

void compute(boolean livecoding) {
  try {
    if (livecoding) {
      raymarcher = loadShader("raymarcher.glsl");
      raymarcher.set("resolution", (float)buffer.width, (float)buffer.height);
      raymarcher.set("ramp", loadImage("rampsimple.png"));
    }

    raymarcher.set("mouse", (float)mouseX/width, (float)mouseY/height);
    raymarcher.set("time", millis() * 0.001);

    buffer.beginDraw();
    buffer.clear();
    buffer.blendMode(REPLACE);
    buffer.shader(raymarcher);
    buffer.rect(0, 0, buffer.width, buffer.height);
    buffer.endDraw();

    dof.set("resolution", (float)this.buffer.width, (float)this.buffer.height);
    dof.set("mouse", (float)mouseX/(float)width, (float)mouseY/(float)height);
    filter.getCustomFilter(buffer, dof);
    for (int i=0; i<2; i++) {
      filter.getCustomFilter(filter.getBuffer(), FXAA);
    }
  }
  catch(Exception e) {
    e.printStackTrace();
  }
}
