
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
    raymarcher.set("time", Time.time / 1000.0);


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

void populateFromCenter(PGraphics ctx, int nbElements, float radius, float x, float y, float size)
{
  ctx.beginDraw();
  ctx.background(255);
  //buffer.strokeWeight(10);
  ctx.noStroke();
  ctx.fill(0);
  for (int i=0; i<nbElements; i++)
  {
    float a = norm(i, 0, nbElements) * TWO_PI;
    float rndRadius = random(0, radius);
    float px = cos(a) * rndRadius + x;
    float py = sin(a) * rndRadius + y;
    ctx.ellipse(px, py, size, size);
  }

  ctx.endDraw();
}

void populateAtRandom(PGraphics ctx, int nbElements, float size)
{
  ctx.beginDraw();
  ctx.background(255);
  //buffer.strokeWeight(10);
  ctx.noStroke();
  ctx.fill(0);
  for (int i=0; i<nbElements; i++)
  {
    float px = random(ctx.width);
    float py = random(ctx.height);
    //ctx.ellipse(px, py, size, size);
    int rnd = round(random(1, 10));
    //modEllipse(ctx, rnd, px, py, size);
    ctx.ellipse(px, py, size, size);
  }

  ctx.endDraw();
}

void modEllipse(PGraphics ctx, int nbElements, float x, float y, float size) {
  for (int i=0; i<nbElements; i++)
  {
    float normi = 1.0 - (float)i/(float)nbElements;
    if (i % 2 == 0) ctx.fill(0);
    else ctx.fill(255);

    ctx.ellipse(x, y, normi * size, normi * size);
  }
}
