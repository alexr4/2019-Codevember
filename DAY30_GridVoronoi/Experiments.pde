
PShader raymarcher, dof, FXAA;
PGraphics buffer;
Filter filter;
boolean livecoding;
PImage albedo, normal, specular, ramp;



void init(PGraphics ctx) {
  buffer = createGraphics(ctx.width, ctx.height, P2D);
  filter = new Filter(this, buffer.width, buffer.height);
  raymarcher = loadShader("raymarcher.glsl");
  //ramp = loadImage(MEDIA.path + "Toon/rampToon.png");
  //albedo = loadImage(MEDIA.path + "Metal02/albedo.jpg");
  //normal = loadImage(MEDIA.path + "Metal02/normal.jpg");
  //specular = loadImage(MEDIA.path + "Metal02/specular.jpg");
  //displacement = loadImage(MEDIA.path + "Metal02/displacement2.jpg");
  raymarcher.set("resolution", (float)buffer.width, (float)buffer.height);
  raymarcher.set("ramp", ramp);
  //raymarcher.set("albedoMap", albedo);
  //raymarcher.set("normalMap", normal);
  //raymarcher.set("specularMap", specular);
  //raymarcher.set("displacementMap", displacement);
  dof = loadShader("hexagonalDOF.glsl");
  FXAA = loadShader("fxaa.glsl");

}

void compute(boolean livecoding) {
  try {
    if (livecoding) {
      raymarcher = loadShader("raymarcher.glsl");
      //rampGenerator = loadShader("rampGenerator.glsl");
      raymarcher.set("resolution", (float)buffer.width, (float)buffer.height);
      raymarcher.set("ramp", ramp);
      //raymarcher.set("albedoMap", albedo);
      //raymarcher.set("normalMap", normal);
      //raymarcher.set("specularMap", specular);
      ////raymarcher.set("displacementMap", displacement);
      //raymarcher.set("startRamp", ppb.getSrcBuffer());
      //raymarcher.set("endRamp", ppb.getDstBuffer());
      //rampGenerator.set("resolution", (float) ppb.dst.width, (float) ppb.dst.height);


      //computeNoisedRamp(next);
    }

    
    float t = ctime.normTime;
    if( ctime.timeLoop % 2 != 0) t = 1.0 - ctime.normTime;
    
    float easedTime = NormalEasing.inoutQuad(ctime.normTime);
    raymarcher.set("easing", (float)easedTime);
    raymarcher.set("startTime", previousLoop);
    raymarcher.set("endTime", previousLoop + 1);
    raymarcher.set("mouse", (float)mouseX/width, (float)mouseY/height);
    raymarcher.set("time", (Time.time / 1000.0) * 0.5);


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
