import fpstracker.core.*;
import org.json.JSONObject;
import org.json.JSONArray;
import com.hamoid.*;
import gpuimage.core.*;
import java.nio.IntBuffer;

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
Icosahedron sico;
float previousLoop;
float easedTime;
ControlledTime ctime;
PShape obj;
IntBuffer envMapTextureID;
PShader envShader;
PImage envTex;
PShape cubeMapObj;
PMatrix3D cameraMatrix;
PImage envMap;

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

  obj = loadShape(MEDIA.path+"_Models/Man.obj");
  envMap = loadImage(MEDIA.path+"cubemap/City/city2.jpg");
  generateCubeMap();
  cubeMapObj = texturedCube(envMap, 1000);
  envShader = loadShader("env_frag.glsl", "env_vert.glsl");
  envShader.set("cubemap", 1);
  envShader.set("fresnel", 0.75f);


  //sico = new Icosahedron(6, 10, null);
  //sico.init();

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

  if (ctime.timeLoop % 3 == 0) {
    easedTime = NormalEasing.inoutQuad(ctime.normTime);
  } else if ( ctime.timeLoop % 3 == 1) {
    easedTime = 1.0;
  } else {
    easedTime = 1.0 - NormalEasing.outExp(ctime.normTime);
  }
  if (previousLoop != ctime.timeLoop && ctime.timeLoop % 3 == 0) {
    previousLoop = ctime.timeLoop;
  } else {
  }

  easedTime = constrain(easedTime, 0.0, 1.0);


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
    ctx.background(#181D6B);
  }

  float nmx = mouseX / (float) width;
  float nmy = mouseY / (float) height;
  //camera
  float eta = TWO_PI * .5 + Time.time * 0.0001;
  float theta = PI*.65;
  float radius = 500 + abs(sin(Time.time * 0.00025)) * - 1.0 * 200;
  float x = sin(theta) * cos(eta) * radius;
  float z = sin(theta) * sin(eta) * radius;
  float y = cos(theta) * radius;
  float ty = 150 * 0.5;


  //design
  ctx.ortho(-ctx.width/2, ctx.width/2, -ctx.height/2, ctx.height/2);
  ctx.camera(x, y, z, 0, ty, 0, 0, 1, 0);
/*
  ctx.noLights();
  for (int i=0; i<4; i++) {
    float ni = (float)i/4.0;
    float px = cos(ni*TWO_PI) * 500;
    float pz = sin(ni*TWO_PI) * 500;
    ctx.pointLight(255, 255, 255, px, 0, pz);
  }
  */
  //ctx.directionalLight(200, 200, 200, 0.8f, 0.8f, -0.6f);
  //ctx.directionalLight(255, 255, 255, 0, -0.2f, 1);
  //ctx.directionalLight(120, 120, 120, -1f, -0.8f, -0.6f);

  float noiseInc = 0.015;
  float displacementFactor = 50 * easedTime;

  try {


    PGraphics3D g3 = (PGraphics3D)ctx;
    cameraMatrix = g3.camera;
    //cameraMatrix = g3.cameraInv;
    envShader.set("camMatrix", cameraMatrix);
    envShader.set("displacementFactor", displacementFactor);
    envShader.set("noiseInc", noiseInc);
    envShader.set("time", Time.time * 0.0001);
    ctx.shader(envShader);
  }
  catch(Exception e) {
    e.printStackTrace();
  }

  // ctx.lights();
  ctx.noStroke();
  ctx.fill(255);
  ctx.shape(obj);
  //ctx.box(250);
  //ctx.box(120 * 1.5);
  //ctx.sphereDetail(2);
 /* int rows = 8;
  int cols = 8;
  float radiusSphere = 80;
  float offset = radiusSphere * 4;
  float center = offset * rows * .5;
  for (int r = 0; r<rows; r++) {
    for (int c = 0; c<cols; c++) {
      float px = r * offset - center;
      float pz = c * offset - center;
      ctx.pushMatrix();
      ctx.translate(px, 0, pz);
      ctx.sphere(radiusSphere);
      ctx.popMatrix();
    }
  }
*/
  //ctx.sphere(150);


  ctx.endDraw();
}

void computeUIBuffer(PGraphics ui) {
  ui.beginDraw();
  ui.background(#2D31A9);
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
