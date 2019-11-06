import fpstracker.core.*;
import org.json.JSONObject;
import org.json.JSONArray;
import com.hamoid.*;
import gpuimage.core.*;
import estudiolumen.simplepbr.*;
import java.awt.Color;

PerfTracker pt;

//config
String configPath = "_based/";
String configFileName = "config.json";
PGraphics ctx;
PGraphics ui;
PGraphics outputBuffer;
ArrayList<PGraphics> layers;
int actualLayer = 2;

//Post-Process
Filter filter;
Compositor comp;

//control & UI
boolean pause;
boolean debug;

//exports
boolean export;
VideoExport videoExport;

//Design experiment
PBRMat mat;
int seed = 1000;
float baseEta, baseTheta, basePhi;
float rndStart;
float previousLoop;
float easedTime;
ControlledTime ctime;

void settings() {
  if (args != null) {
    configPath       = args[0];
    configFileName   = args[1];
  } else {
    println("No config passed as arguments. Load based config file");
  }
  loadConfig(configPath+configFileName);
  if (!CONFIG.topBar) fullScreen(P3D);
  else size(250, 250, P3D);
  smooth(CONFIG.smooth);
  PJOGL.setIcon(configPath+"ico.png");
}

void setup() {
  //init surface
  surface.setSize(CONFIG.width, CONFIG.height);
  surface.setLocation(CONFIG.windowX, CONFIG.windowY);
  frameRate(CONFIG.fps);

  MEDIA.loadAsset(this);

  ctx           = createGraphics(CONFIG.originalWidth, CONFIG.originalHeight, P3D); 
  ui            = createGraphics(CONFIG.originalWidth, CONFIG.originalHeight, P2D); 
  outputBuffer  = createGraphics(CONFIG.originalWidth, CONFIG.originalHeight, P2D);  
  filter        = new Filter(this, CONFIG.originalWidth, CONFIG.originalHeight);
  comp          = new Compositor(this, CONFIG.originalWidth, CONFIG.originalHeight);

  ctx.smooth(CONFIG.smooth);
  ui.smooth(CONFIG.smooth);
  outputBuffer.smooth(CONFIG.smooth);

  layers = new ArrayList<PGraphics>();
  layers.add(ctx);
  layers.add(ui);
  layers.add(outputBuffer);

  computeUIBuffer(ui);

  //PBR init
  SimplePBR.init(this, MEDIA.cubemapath); // init PBR setting processed cubemap
  SimplePBR.setExposure(1.25f); // simple exposure control

  // Create PBR material from a set of textures
  mat = new PBRMat(MEDIA.matpath);
  //

  //init Experiment
  ctime = new ControlledTime();

  pt = new PerfTracker(this, 120);
  Time.setStartTime(this);
  ctime.setStartTime();

  String filename = year()+""+month()+""+day()+""+"_"+hour()+""+minute()+""+second()+""+millis()+"_"+CONFIG.simplifiedName;
  videoExport = new VideoExport(this, CONFIG.exportPathVideo+filename+".mp4", outputBuffer);
  videoExport.setQuality(FFMPEGPARAMS.videoQuality, FFMPEGPARAMS.audioQuality);
  videoExport.setFrameRate(FFMPEGPARAMS.fps);
  videoExport.setDebugging(FFMPEGPARAMS.debug);
}

void draw() {
  background(127);
  //compute here
  Time.update(this, pause);
  ctime.update(pause);
  Time.computeTimeAnimation(Time.time, CONFIG.timeDuration);
  ctime.computeTimeAnimation(CONFIG.timeAnimation);

  float pingpong = 1.0 - abs((ctime.normTime) * 2.0 - 1.0);
  easedTime = NormalEasing.inoutExp(pingpong);
  if (previousLoop != ctime.timeLoop) {
    println("reinit collatz");
    seed = frameCount * 10000;
    rndStart = random(1000 + frameCount);
    previousLoop = ctime.timeLoop;
  } else {
  }

  easedTime = constrain(easedTime, 0.0, 1.0);
  randomSeed(seed);


  //compute buffers
  computeBuffer(ctx);
  // computePostProcessBuffer(ctx);
  computeOutputBuffer(outputBuffer, ui, ctx);

  //export video
  exportVideo();

  //draw here
  image(layers.get(actualLayer), 0, 0, width, height);

  if (debug) {
    String uiText = CONFIG.appname + " — "+
      "Time: "+Time.time + "\n"+
      "Pause: "+pause;
    String uiExportProgress = "FFMEPG export: "+round(Time.normTime * 100)+"%";
    uiText = (export) ? uiText+ "\n"+uiExportProgress : uiText;

    float uiTextMargin = 20;
    float uiTextWidth = textWidth(uiText) + uiTextMargin * 2;
    pushStyle();
    fill(0);
    noStroke();
    rect(100, 0, uiTextWidth, 60);
    fill(255);
    text(uiText, 120, 20);
    popStyle();
    pt.display(0, 0);
  } else {
    pt.displayOnTopBar(CONFIG.appname);
    if (export) {
      String uiExportProgress = "FFMEPG export: "+round(Time.normTime * 100)+"%";
      float headerWidth = width;
      float headerHeight = height/10;
      float progressWidth = width * 0.95;
      float pogressHeight = headerHeight * 0.15;
      float yOffset = 10;
      color headerColor = color(255, 200, 0);
      color progressColor = color(255, 127, 0);

      pushStyle();
      fill(headerColor);
      noStroke();
      rectMode(CENTER);
      rect(width/2, height/2, headerWidth, headerHeight);
      fill(0);
      textAlign(CENTER, CENTER);
      textSize(14);
      text(uiExportProgress, width/2, height/2 - yOffset);
      stroke(progressColor);
      noFill();
      rect(width/2, height/2 + yOffset, progressWidth, pogressHeight);
      fill(progressColor);
      noStroke();
      rect(width/2, height/2 + yOffset, progressWidth * Time.normTime, pogressHeight);
      popStyle();
    }
  }
}

void computeBuffer(PGraphics ctx) {
  ctx.beginDraw();
  if (RENDERPARAMS.type == TYPE.iTRANSPARENT) {
    ctx.blendMode(REPLACE);
    ctx.background(100, 0);
  } else {
    ctx.background(31 * 0.25, 3 * 0.25, 133 * 0.25);
  }

  float nmx = mouseX / (float) width;
  float nmy = mouseY / (float) height;
  //camera
  float eta = Time.time * 0.0001;
  float theta = HALF_PI * 0.75;
  float radius = 800 + abs(sin(Time.time * 0.0001)) * - 1.0 * 200;
  float cx = sin(theta) * cos(eta) * radius;
  float cz = sin(theta) * sin(eta) * radius;
  float cy = cos(theta) * radius;
  float ty = 150 * 0.0;
  PVector dir = PVector.sub(new PVector(), new PVector(cx, cy, cz)).normalize().mult(-1.0);

  PVector light2 = new PVector(
    sin(theta * HALF_PI) * cos(eta), 
    sin(theta * HALF_PI) * sin(eta), 
    cos(theta * HALF_PI)
    );

  //lighting
  SimplePBR.setDiffuseAttenuation(mat.getShader(), 1.);
  SimplePBR.setReflectionAttenuation(mat.getShader(), 1.5);
  SimplePBR.setExposure(1.4);

  ctx.noLights();
  ctx.directionalLight(255, 255, 255, dir.x, dir.y, dir.z);
  ctx.directionalLight(200, 200, 200, light2.x, light2.y, light2.z);
  ctx.directionalLight(100, 100, 100, -1f, -0.8f, -0.6f);

  mat.setRougness(0.01);
  mat.setMetallic(0.1);
  //mat.setNormalIntensity(1.0);
  //mat.setRim(1.0);

  //design
  ctx.camera(0, 0, 1500, 0, ty, 0, 0, 1, 0);
  ctx.sphereDetail(8);

  float res = 50.0;
  float gwidth = 1000.0;
  float gheight = 1000.0;
  int cols = round(gwidth/res);
  int rows = round(gheight/res);

  float noiseScale = 0.1;
  float noiseTimeScale = 0.0001;
  float noiseTimeScale2 = 0.0005;

  ctx.noStroke();
  ctx.rotateZ(-HALF_PI * 0.5);
   ctx.rectMode(CENTER);
  mat.bind(ctx);
 
  for (int r=0; r<rows; r++) {
    int mod = r % 2;
    float multMod = 0.5;
    if(mod == 0) multMod = 0;
    for (int c =0; c<cols; c++) {
      float px = res * c + res * 0.5 - gwidth * 0.5;
      float py = res * r + res * 0.5 - gheight * 0.5;
      
      float noiseVal = noise(r * noiseScale - ctime.time * noiseTimeScale2, 
        c * noiseScale + ctime.time * noiseTimeScale2, 
        ctime.time * noiseTimeScale);
      float noiseAngle = noiseVal * PI;
      float nr = (float)r/rows;
      float nc = (float)c/cols;
      
      ctx.pushMatrix();
      ctx.translate(px, py);
      //ctx.rotateZ(HALF_PI * 0.5);
      ctx.rotateX(noiseAngle);
      //ctx.fill(242, 172, 41);
      ctx.fill(nr * 255, nc * 255, noiseVal * 255);
      //ellipse(ctx, 0, 0, res, 14, 1);
      ctx.rect(0, 0, res, res);
      //ctx.sphere(res * 0.5);

      ctx.translate(0, 0, -0.1);
      //ctx.fill(44, 152, 225);
      //ctx.fill(0, 0, 255);
      ctx.fill((1.0 - nr) * 255, (1.0 - nc) * 255, (1.0 - noiseVal) * 255);
      //ellipse(ctx, 0, 0, res, 14, 1);
      ctx.rect(0, 0, res, res);
      //ctx.sphere(res * 0.5);
      //ctx.ellipse(0, 0, res, res);


      ctx.popMatrix();
    }
  }

  ctx.endDraw();
}

void ellipse(PGraphics ctx, float x, float y, float diam, int res, float multNormal) {
  ctx.beginShape(TRIANGLE_FAN);
  ctx.textureMode(NORMAL);
  ctx.normal(0, 0, 1 * multNormal);
  ctx.vertex(x, y, 0.5, 0.5);
  for (int i=0; i<res; i++) {
    float ni = (float)i/(float)(res-1);
    float eta = TWO_PI * ni;
    float cx = cos(eta) * (diam * 0.5) + x;
    float cy = sin(eta) * (diam * 0.5) + y;
    float u = map(cx, -diam*0.5, diam*0.5, 0.0, 1.0);
    float v = map(cy, -diam*0.5, diam*0.5, 0.0, 1.0);
    ctx.normal(0, 0, 1 * multNormal);
    ctx.vertex(cx, cy, 0, u, v);
  }
  ctx.endShape(CLOSE);
}


void computeUIBuffer(PGraphics ui) {
  ui.beginDraw();
  ui.background(31 * 0.5, 3 * 0.5, 133 * 0.5);
  ui.textFont(MEDIA.mainfont);
  ui.textMode(SHAPE);
  ui.noStroke();
  ui.fill(255);
  ui.textAlign(LEFT, BOTTOM);
  ui.textSize(CSS.infoFontSize);
  ui.text(UI.date, CSS.marginX, CSS.marginY);
  ui.text(UI.challenge, ui.width/2, CSS.marginY);
  ui.textAlign(LEFT, TOP);
  ui.text(UI.author, CSS.marginX, ui.height-CSS.marginY);
  ui.text(UI.tags, ui.width/2, ui.height-CSS.marginY);

  ui.textSize(CSS.titleFontSize);
  ui.textLeading(CSS.titleLineHeight);
  ui.text(UI.title, CSS.titleMarginX, CSS.titleMarginY, ui.width - CSS.titleMarginX * 2, ui.height - CSS.titleMarginY * 2);
  ui.endDraw();
}

void computeOutputBuffer(PGraphics ctx, PGraphics ui, PGraphics design) {
  switch(RENDERPARAMS.type) {
  case TYPE.iTRANSPARENT :
    ctx.beginDraw();
    ctx.imageMode(CORNER);
    ctx.image(ui, 0, 0, ui.width, ui.height);
    ctx.image(design, 0, 0, design.width, design.height);
    ctx.endDraw();
    break;
  case TYPE.iCIRCMASK : 
    comp.getMask(ui, ui, MEDIA.mask);
    ctx.beginDraw();
    ctx.imageMode(CORNER);
    ctx.image(comp.getBuffer(), 0, 0, ctx.width, ctx.height);
    ctx.endDraw();
    break;
  case TYPE.iSQUAREDMASK :
    ctx.beginDraw();
    ctx.imageMode(CENTER);
    ctx.image(ui, ctx.width/2, ctx.height/2, ui.width, ui.height);
    ctx.image(design, ctx.width/2, ctx.height/2, 626, 626);
    ctx.endDraw(); 
    break;
  }
}

void computePostProcessBuffer(PGraphics src) {
  //1- High pass the source image
  filter.getHighPass(src, 2.0);
  //2- Desaturate the result image
  filter.getDesaturate(filter.getBuffer(), 100.0);
  //3- Compose it with the source image as overlay
  comp.getBlendOverlay(filter.getBuffer(), src, 100.0);

  filter.getChromaWarpHigh(comp.getBuffer(), src.width/2, src.height/2, 0.001, HALF_PI * 0.005);
  // filter.getAnimatedGrainRGB(filter.getBuffer(), 0.01);
}

void exportVideo() {
  if (export) {
    if (Time.timeLoop == 0) {
      videoExport.saveFrame();
    } else {
      videoExport.endMovie();
      export = false;
    }
  }
}

void keyPressed() {
  switch(key) {
  case 'p' :
  case 'P' :
    pause = !pause;
    break;
  case 'd' :
  case 'D' :
    debug = !debug;
    break;
  case 's':
  case 'S':
    String filename1 = year()+""+month()+""+day()+""+"_"+hour()+""+minute()+""+second()+""+millis()+"_"+CONFIG.simplifiedName+".png";
    String filename2 = year()+""+month()+""+day()+""+"_"+hour()+""+minute()+""+second()+""+millis()+"_"+CONFIG.simplifiedName+"_Generative"+".png";
    //String filename3 = year()+""+month()+""+day()+""+"_"+hour()+""+minute()+""+second()+""+millis()+"_"+CONFIG.simplifiedName+"_UI"+".png";
    ctx.save(CONFIG.exportPathImage+filename1);
    outputBuffer.save(CONFIG.exportPathImage+filename2);
    //ui.save(CONFIG.exportPathImage+filename3);
    break;
  case 'q' :
  case 'Q' :
    videoExport.endMovie();
    exit();
    break;
  case 'e' : 
  case 'E' :
    if (!export) {
      export = true;
      Time.resetTimeForExport(this);
      ctime.setStartTime();
      videoExport.startMovie();
    }
    break;
  case '+' :
    actualLayer ++;
    actualLayer %= layers.size();
    break;
  case '-' :
    actualLayer --;
    actualLayer = (actualLayer < 0) ? layers.size() - 1 : actualLayer;
    break;
  }
}
