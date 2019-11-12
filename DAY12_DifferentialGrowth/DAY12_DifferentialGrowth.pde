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

//DGS
Rectangle aabb;
QuadTree quadtree;
ArrayList<DGS> dgsdays;

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
  mat = new PBRMat(MEDIA.path+"Plaster/");
  mat.setCustomShader("vert.glsl", "frag.glsl");

  sico = new Icosahedron(6, 120, null);
  sico.init();

  aabb = new Rectangle(ctx.width * 0.5, ctx.height * 0.5, ctx.width * 0.5, ctx.height * 0.5);
  quadtree = new QuadTree(aabb, 8);

  dgsdays = new ArrayList<DGS>();
  int nbDay = 6;
  float x = width/2;
  float res = ctx.height;
  float resX = 200;

  float offset = (resX * nbDay) / 2; 
  for (int i=0; i<nbDay; i++) {
    DGS dgs = new DGS(quadtree);
    float x_ = x + i * 50 - (50 * nbDay * 0.5);
    dgs.initAsLine(x_, 0, x_, ctx.height);
    //dgs.initAsCircle();
    //dgs.initAsSpiral();
    dgsdays.add(dgs);
  }

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

  int nbElem = 15000;
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
    ctx.background(204, 200, 215);
  }

  float nmx = mouseX / (float) width;
  float nmy = mouseY / (float) height;
  //camera
  float theta = TWO_PI * 0.8;
  float radius = 500;
  float cx = cos(theta) * radius + width/2;
  float cz = sin(theta) * radius;
  float cy = height/2;

  //lighting
  SimplePBR.setDiffuseAttenuation(mat.getShader(), 1.0);
  SimplePBR.setReflectionAttenuation(mat.getShader(), 0.35);
  SimplePBR.setExposure(mat.getShader(), 1.25);

  ctx.noLights();
  ctx.directionalLight(200, 200, 200, 0.8f, 0.8f, -0.6f);
  ctx.directionalLight(255, 255, 255, 0, -0.2f, 1);
  ctx.directionalLight(242, 5, 116/*20, 120, 120*/, -1f, -0.8f, -0.6f);


  //cameraMatrix correction
  PGraphics3D g3 = (PGraphics3D)ctx;
  PMatrix3D cameraMatrix = g3.camera;
  //cameraMatrix = g3.cameraInv;
  mat.getShader().set("camMatrix", cameraMatrix);
  mat.setFloat("fresnel", 0.75f);

  mat.setRougness(0.5);
  mat.setMetallic(0.0);
  mat.setRim(0.0);
  mat.bind(ctx);//Binds comes always before set because it bind variable to shader (texture map, mat properties)

  //design
  //ctx.rotateZ(HALF_PI * 0.25);
  float zoom = 10.0 * 0.5;
  ctx.ortho(-width/zoom, width/zoom, -height/zoom, height/zoom);
  ctx.camera(cx, cy, cz, width/2, height/2, 0, 1.0, 1, 0);
  // ctx.lights();
  ctx.noStroke();
  ctx.fill(255);

  //ctx.shape(sico.icosahedron);
  float len = 10;
  float len2 = 100;
  PVector extrude = new PVector(0, 0, len);
  //translate(width/2, height/2);
  ctx.fill(255);
  ctx.noStroke();
  for (int i=0; i<dgsdays.size(); i++) {
    DGS dgs = dgsdays.get(i);

    ctx.beginShape(TRIANGLES);
    ctx.textureMode(NORMAL);
    for (int j=0; j<dgs.nodeList.size()-1; j++) {
      Node nodeJ = dgs.nodeList.get(j);
      Node nodeJN = dgs.nodeList.get(j+1);

      int nextIndex = i+2;
      if (nextIndex >= dgs.nodeList.size()-1) {
        nextIndex = i-1;
      }

      float normi = (float)j/(float)dgs.nodeList.size();
      float normii = (float)(j+1)/(float)dgs.nodeList.size();

      normi = (normi * 10.0) % 1.0;
      normii = (normii * 10.0) % 1.0;

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
      PVector normCDB = v2v3.cross(v2v1).normalize().mult(-1);

      ctx.fill(150, 142, 201);//noiseRed, noiseGreen, noiseBlue);
      ctx.normal(normABC.x, normABC.y, normABC.z);
      ctx.vertex(vert0.x, vert0.y, vert0.z, normi, 0);
      ctx.normal(normABC.x, normABC.y, normABC.z);
      ctx.vertex(vert1.x, vert1.y, vert1.z, normi, 1);
      ctx.normal(normABC.x, normABC.y, normABC.z);
      ctx.vertex(vert2.x, vert2.y, vert2.z, normii, 0);

      ctx.normal(normCDB.x, normCDB.y, normCDB.z);
      ctx.vertex(vert2.x, vert2.y, vert2.z, normii, 0);
      ctx.normal(normCDB.x, normCDB.y, normCDB.z);
      ctx.vertex(vert3.x, vert3.y, vert3.z, normii, 1);
      ctx.normal(normCDB.x, normCDB.y, normCDB.z);
      ctx.vertex(vert1.x, vert1.y, vert1.z, normi, 1);

      ctx.fill(229, 203, 212);
      ctx.normal(normABC.x, normABC.y, normABC.z);
      ctx.vertex(vert0.x, vert0.y, vert0.z + len, normi, 0);
      ctx.normal(normABC.x, normABC.y, normABC.z);
      ctx.vertex(vert1.x, vert1.y, vert1.z + len2, normi, 1);
      ctx.normal(normABC.x, normABC.y, normABC.z);
      ctx.vertex(vert2.x, vert2.y, vert2.z + len, normii, 0);

      ctx.normal(normCDB.x, normCDB.y, normCDB.z);
      ctx.vertex(vert2.x, vert2.y, vert2.z + len, normii, 0);
      ctx.normal(normCDB.x, normCDB.y, normCDB.z);
      ctx.vertex(vert3.x, vert3.y, vert3.z + len2, normii, 1);
      ctx.normal(normCDB.x, normCDB.y, normCDB.z);
      ctx.vertex(vert1.x, vert1.y, vert1.z + len2, normi, 1);
    }
    ctx.endShape(CLOSE);
  }


  ctx.endDraw();
}

void computeUIBuffer(PGraphics ui) {
  ui.beginDraw();
  ui.background(194, 191, 212);
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

      dgsdays = new ArrayList<DGS>();
      int nbDay = 6;
      float x = width/2;
      float res = ctx.height;
      float resX = 200;

      float offset = (resX * nbDay) / 2; 
      for (int i=0; i<nbDay; i++) {
        DGS dgs = new DGS(quadtree);
        float x_ = x + i * 50 - (50 * nbDay * 0.5);
        dgs.initAsLine(x_, 0, x_, ctx.height);
        //dgs.initAsCircle();
        //dgs.initAsSpiral();
        dgsdays.add(dgs);
      }
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
