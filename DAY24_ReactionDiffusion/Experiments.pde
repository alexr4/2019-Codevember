
PShader raymarcher, dof, FXAA;
PGraphics buffer;
Filter filter;
boolean livecoding;
PImage albedo, normal, specular, ramp;


PShader reactionDiffusion;
PShader grayScale;
PingPongBuffer rdbuffer;
Filter filterRD;
PGraphics debugSource;
int iteration = 100;
float hyp;
float size = 5;
int minElements = 50;
int maxElements = 500;
int nbElements;

PGraphics displacement;


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

  reactionDiffusion = loadShader("reactionDiffusion.glsl");
  grayScale = loadShader("reactionDiffusionRender.glsl");
  rdbuffer = new PingPongBuffer(this, ctx.width/2, ctx.width/2, P2D);
  rdbuffer.enableTextureMipmaps(false);
  rdbuffer.setFiltering(3);
  rdbuffer.noSmooth();

  filterRD = new Filter(this, ctx.width/2, ctx.height/2);
  debugSource = createGraphics(ctx.width/2, ctx.height/2, P2D);
  displacement =  createGraphics(ctx.width/2, ctx.height/2, P2D);
  hyp = sqrt(pow(rdbuffer.dst.width/2, 2) + pow(rdbuffer.dst.height/2, 2)) * 0.5;
  generate();
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

    for (int i=0; i<25; i++) {
      rdbuffer.swap();
      rdbuffer.dst.beginDraw();
      rdbuffer.dst.background(0);
      rdbuffer.dst.shader(reactionDiffusion);
      rdbuffer.dst.image(rdbuffer.getSrcBuffer(), 0, 0);
      rdbuffer.dst.endDraw();
    }

    grayScale.set("offset", 0.5);
    grayScale.set("thickness", 0.1);
    filterRD.getCustomFilter(rdbuffer.dst, grayScale);
    filterRD.getGaussianBlurMedium(filterRD.getBuffer(), 50);
    filterRD.getGaussianBlurMedium(filterRD.getBuffer(), 25);

    displacement.beginDraw();
    displacement.image(filterRD.getBuffer(), 0, 0);
    displacement.endDraw();
    
    float t = ctime.normTime;
    if( ctime.timeLoop % 2 != 0) t = 1.0 - ctime.normTime;
    
    float easedTime = NormalEasing.inoutQuad(ctime.normTime);
    raymarcher.set("easing", (float)easedTime);
    raymarcher.set("startTime", previousLoop);
    raymarcher.set("endTime", previousLoop + 1);
    raymarcher.set("mouse", (float)mouseX/width, (float)mouseY/height);
    raymarcher.set("time", Time.time / 1000.0);
    raymarcher.set("displacementMap", displacement);

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


void clearBuffer()
{
  rdbuffer.clear();
  filter.clear();
}

void generateNewVarToShader() {
  float dT= random(0.5, 1.0);
  float dA = random(0.65, 0.98);
  float dB = random(0.1, dA * 0.45);
  float fR = random(0.1, 0.045);
  float kR = random(0.01, 0.1);
  println(dA, dB);
  reactionDiffusion.set("dT", dT);
  //reactionDiffusion.set("dA", dA);
  //reactionDiffusion.set("dB", dB);
  //reactionDiffusion.set("feedRate", fR);
  //reactionDiffusion.set("killRate", kR);
}

void saveIntoSource(PGraphics ctx, PGraphics toSave) {
  ctx.beginDraw();
  ctx.background(255);
  ctx.image(toSave, 0, 0, ctx.width, ctx.height); 
  ctx.endDraw();
}

void generate() {
  size = random(5, 40);
  nbElements = round(random(minElements, maxElements));
  clearBuffer();
  float rnd = random(1.0);
  //if (rnd <= 0.5) {
  //  populateFromCenter(rdbuffer.dst, nbElements, hyp, rdbuffer.dst.width * 0.5, rdbuffer.dst.height*0.5, size);
  //  populateAtRandom(debugSource, nbElements, size);
  //} else {
  //  debugSource.beginDraw();
  //  debugSource.image(imgSource, 0, 0);
  //  debugSource.endDraw();
  //}

  //populateFromCenter(debugSource, nbElements, hyp, rdbuffer.dst.width * 0.5, rdbuffer.dst.height*0.5, size);
  populateAtRandom(debugSource, nbElements, size);
  saveIntoSource(rdbuffer.dst, debugSource);
  generateNewVarToShader();
}
