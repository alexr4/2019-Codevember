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
PBRSMMat mat;
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
  mat = new PBRSMMat(MEDIA.matpath);

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
    ctx.background(220);
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
  PVector dir = PVector.sub(new PVector(), new PVector(cx, cy, cz)).normalize().mult(1.0);
  
  PVector light2 = new PVector(
    sin(theta * HALF_PI) * cos(eta),
    sin(theta * HALF_PI) * sin(eta),
    cos(theta * HALF_PI)
  );

  //lighting
  SimplePBR.setDiffuseAttenuation(mat.getShader(), 1.0);
  SimplePBR.setReflectionAttenuation(mat.getShader(), 1.0);
  SimplePBR.setExposure(0.25);

  ctx.noLights();
  ctx.directionalLight(255, 255, 255, dir.x, dir.y, dir.z);
  ctx.directionalLight(0, 0, 255, light2.x, light2.y, light2.z);
 ctx.directionalLight(100, 100, 100, -1f, -0.8f, -0.6f);


  //mat.setRougness(0.65);
  //mat.setMetallic(0.75);
  mat.setNormalIntensity(1.0);
  mat.setRim(1.0);
  mat.bind(ctx);

  //design
  float maxBranchTime = 1500.0;
  float animatedBranchTime = (Time.time % maxBranchTime) / maxBranchTime;
  ctx.camera(cx, cy, cz, 0, ty, 0, 0, 1, 0);
  

  int dimXYZ = 25;
  int dimX = 8;//round(random(6, 8));
  int dimZ = 8;//round(random(6, 8));
  int dimY = 16;//round(random(8, 14));

  float offset = dimXYZ * 4.0;
  color based = color(255);
  
  float hue = random(251./360.0, 260/360.);
  color end = HSBtoRGB(hue, 1.0, 1.0);//color(#5E25D9);//HSBtoRGB(random(.72, 0.76), 1.0, 1.0);//color(140, 75, 255);
  ctx.noStroke();
  for (int x=0; x<dimX; x++) {
    float px = x * dimXYZ - dimX * dimXYZ * .5;
    float normX = (float)x/(float)dimX;
    float ssnx = smoothstep(0.25, 1.0, normX);
    for (int y=0; y<dimY; y++) { 
      float py = y * dimXYZ - dimY * dimXYZ *  .5;
      float normY = (float)y/(float)dimY;
      float ssny = smoothstep(0.15, .85, normY);
      float ssny2 = smoothstep(0.45, .75, normY);
      for (int z=0; z<dimZ; z++) {
        float pz = z * dimXYZ - dimZ * dimXYZ *  .5;
        float normZ = (float)z/(float)dimZ;
        float ssnz = smoothstep(0.25, 1.0, normZ);

        float easing = NormalEasing.inQuad(ssny);
        float easing2 = NormalEasing.inCirc(ssny2);
        float easingScale = map(easing * easedTime, 0, 1, 1.0, 0.65);

        //float eta   = random(PI * .5) * easing * easedTime;
        //float theta = random(PI * .5) * easing * easedTime;
        //float phi   = random(PI * .5) * easing * easedTime;
        float noiseAngle = 2.75;
        float reta   = noise(normX * noiseAngle) * PI * 1. * easing * easedTime;
        float rtheta = noise(normY * noiseAngle) * PI * 1. * easing * easedTime;
        float rphi   = noise(normZ * noiseAngle) * PI * 1. * easing * easedTime;
        //PVector rnd = PVector.random3D(this);
        //rnd.mult(easing * offset * easedTime);
        
        float offsetX = random(-1, 1) * easing * offset * easedTime;
        float offsetY = random(-1, 1) * easing * offset * easedTime;
        float offsetZ = random(-1, 1) * easing * offset * easedTime;
        
        float noiseScale = 0.75;
        float rndValue = random(x + y * dimY + z * dimZ) / (dimX * dimY * dimZ) * 0.2;
        float noiseEta   = (noise(rndStart + normX * noiseScale, rndStart + normY * noiseScale, rndStart + normZ * noiseScale + rndValue) * 2. - 1.) * HALF_PI + HALF_PI;
        float noiseTheta = (noise(rndStart * 10 + normZ * noiseScale, rndStart * 10 + normX * noiseScale, rndStart * 10 + normY * noiseScale + rndValue) * 2. - 1.) * TWO_PI;
        PVector noiseOffset = new PVector(
          sin(noiseEta) * cos(noiseTheta),
          sin(noiseEta) * sin(noiseTheta),
          cos(noiseEta)
        );
        noiseOffset.mult(easing * offset * easedTime);
        
       //float normIndex = (x + dimX * (y + dimZ * z)) / (dimX * dimY * dimZ);// random(x + y * dimY + z * dimZ) / (dimX * dimY * dimZ);//(x + dimX * (y + dimZ * z)) / (dimX * dimY * dimZ);
        
        float fhue = lerp(hue-.25, hue, normY);
        end = HSBtoRGB(fhue, 1.0, 1.0);
        color col = lerpColor(based, end, easing2 * easedTime);

        ctx.pushMatrix();
        ctx.translate(px + noiseOffset.x, py + noiseOffset.y, pz + noiseOffset.z);
        ctx.rotateX(rtheta);
        ctx.rotateY(reta);
        ctx.rotateZ(rphi);
        ctx.fill(col);
        ctx.box(dimXYZ * easingScale);
        ctx.popMatrix();
      }
    }
  }


  ctx.endDraw();
}

void computeUIBuffer(PGraphics ui) {
  ui.beginDraw();
  ui.background(200);
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
