import fpstracker.core.*;
import org.json.JSONObject;
import org.json.JSONArray;
import com.hamoid.*;
import gpuimage.core.*;
import estudiolumen.simplepbr.*;

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
Icosahedron sico;
float previousLoop;
float easedTime;
ControlledTime ctime;

PShader normal, voronoi;
PGraphics voroBuffer, normBuffer;
float colsrows;

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
  SimplePBR.setExposure(1.0); // simple exposure control

  // Create PBR material from a set of textures
  mat = new PBRMat();//MEDIA.path+"Plaster/");
  mat.setCustomShader("vert.glsl", "frag.glsl");
  voroBuffer = createGraphics(height, height, P2D);
  normBuffer = createGraphics(height, height, P2D);

  voronoi = loadShader("voronoi.glsl");
  voronoi.set("u_resolution", (float)voroBuffer.width, (float)voroBuffer.height);
  normal = loadShader("PP_NormalMapping.glsl");
  colsrows = 8.0;

  //sico = new Icosahedron(6, 120, null);
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
  
  float loop = 0.0;
  if (ctime.timeLoop % 3 == 0) {
    easedTime = NormalEasing.inoutQuad(ctime.normTime);
  } else if ( ctime.timeLoop % 3 == 1) {
    easedTime = 1.0;
  } else {
    loop = 1.0;
    easedTime =NormalEasing.outExp(ctime.normTime);
  }
  if (previousLoop != ctime.timeLoop && ctime.timeLoop % 3 == 0) {
    previousLoop = ctime.timeLoop;
    colsrows = random(4, 20);
  } else {
  }

  easedTime = constrain(easedTime, 0.0, 1.0);

  float nmx = norm(mouseX, 0, width);

  voronoi.set("u_time", Time.time * 0.001);
  voronoi.set("normTime", easedTime);
  voronoi.set("orientation", loop);
  voronoi.set("colsrows", colsrows);
  voroBuffer.beginDraw();
  voroBuffer.shader(voronoi);
  voroBuffer.rect(0, 0, voroBuffer.width, voroBuffer.height);
  voroBuffer.endDraw();

  normal.set("sobel1Scale", 1.5);
  normal.set("sobel2Scale", 1.0);
  normBuffer.beginDraw();
  normBuffer.shader(normal);
  normBuffer.image(voroBuffer, 0, 0);
  normBuffer.endDraw();


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
    
    float targetSize = 250;
    image(voroBuffer, 0, height - targetSize, targetSize, targetSize);
    image(normBuffer, 0, height - targetSize*2, targetSize, targetSize);
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
    ctx.background(202, 196, 193);
  }

  float nmx = mouseX / (float) width;
  float nmy = mouseY / (float) height;
  //camera
  float eta = Time.time * 0.0001;
  float theta = PI*0.5;
  float radius = 525 + abs(sin(Time.time * 0.0001)) * - 1.0 * 200;
  float x = sin(theta) * cos(eta) * radius;
  float z = sin(theta) * sin(eta) * radius;
  float y = cos(theta) * radius;
  float ty = -150 * 0.0;

  //lighting
  SimplePBR.setDiffuseAttenuation(mat.getShader(), 1.5);
  SimplePBR.setReflectionAttenuation(mat.getShader(), 1.5);
  SimplePBR.setExposure(mat.getShader(), 1.6);

  ctx.noLights();
  //ctx.pointLight(200, 200, 200, width/2, 0, 500);
  //ctx.directionalLight(200, 200, 200, 0.8f, 0.8f, -0.6f);
  ctx.directionalLight(255, 255, 255, 0, -1, -0.15);
  //ctx.directionalLight(120, 120, 120, -1f, -0.8f, -0.6f);


  mat.bind(ctx);//Binds comes always before set because it bind variable to shader (texture map, mat properties)
  //cameraMatrix correction
  PGraphics3D g3 = (PGraphics3D)ctx;
  PMatrix3D cameraMatrix = g3.camera;
  //cameraMatrix = g3.cameraInv;
  mat.getShader().set("camMatrix", cameraMatrix);
  //mat.setFloat("fresnel", 0.75f);

  mat.setRougness(1.0);
  mat.setMetallic(0.1);
  mat.setTexture("normalMap", normBuffer);
  mat.setNormalIntensity(0.25);
  //mat.setRim(0.0);

  //design
  //ctx.camera(0, 0, 0, 0, ty, 0, 0, 1, 0);
  //// ctx.lights();
  ctx.noStroke();
  ctx.fill(255);
  //ctx.shape(sico.icosahedron);
  ctx.rectMode(CENTER);
  ctx.rect(ctx.width/2, ctx.height/2, ctx.width, ctx.height);


  ctx.endDraw();
}

void computeUIBuffer(PGraphics ui) {
  ui.beginDraw();
  ui.background(215 * 0.75, 214 * .75, 215 * 0.75);
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
