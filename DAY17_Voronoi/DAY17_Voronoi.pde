import fpstracker.core.*;
import org.json.JSONObject;
import org.json.JSONArray;
import com.hamoid.*;
import gpuimage.core.*;

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
//Filter filter;
Compositor comp;

//control & UI
boolean pause;
boolean debug;

//exports
boolean export;
VideoExport videoExport;

void settings() {
  if (args != null) {
    configPath       = args[0];
    configFileName   = args[1];
  } else {
    println("No config passed as arguments. Load based config file");
  }
  loadConfig(configPath+configFileName);
  if(!CONFIG.topBar) fullScreen(P3D);
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


  pt = new PerfTracker(this, 120);
  Time.setStartTime(this);
  
  init(ctx);

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
  Time.computeTimeAnimation(Time.time, CONFIG.timeDuration);
  
  compute(true);
  computeBuffer(ctx);
  computeUIBuffer(ui);
  // computePostProcessBuffer(ctx);
  computeOutputBuffer(outputBuffer, new PGraphics[]{ui, ctx});

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
    if(export){
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
      rect(width/2, height/2 + yOffset,progressWidth, pogressHeight);
      fill(progressColor);
      noStroke();
      rect(width/2, height/2 + yOffset, progressWidth * Time.normTime, pogressHeight);
      popStyle();
    }
  }
}

void computeBuffer(PGraphics ctx){
  ctx.beginDraw();
  if(RENDERPARAMS.type == TYPE.iTRANSPARENT){
    ctx.blendMode(REPLACE);
    ctx.background(100, 0);
  }else{
    ctx.background(40);
  }
  
  ctx.image(filter.getBuffer(), 0, 0);

  ctx.endDraw();
}

void computeUIBuffer(PGraphics ui){
  ui.beginDraw();
  ui.background( 229 *0.7, 224 *0.7, 221 *0.7);
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

void computeOutputBuffer(PGraphics ctx, PGraphics[] orderedLayer){
  switch(RENDERPARAMS.type){
    case TYPE.iTRANSPARENT :
      ctx.beginDraw();
      ctx.imageMode(CORNER);
      ctx.image(orderedLayer[0], 0, 0, orderedLayer[0].width, orderedLayer[0].height);
      ctx.image(orderedLayer[1], 0, 0, orderedLayer[1].width, orderedLayer[1].height);
      ctx.endDraw();
      break;
    case TYPE.iCIRCMASK : 
      comp.getMask(orderedLayer[1], orderedLayer[0], MEDIA.mask);
      ctx.beginDraw();
      ctx.imageMode(CORNER);
      ctx.image(comp.getBuffer(), 0, 0, ctx.width, ctx.height);
      ctx.endDraw();
      break;
    case TYPE.iSQUAREDMASK :
      ctx.beginDraw();
      ctx.imageMode(CENTER);
      ctx.image(orderedLayer[0], ctx.width/2, ctx.height/2, orderedLayer[0].width, orderedLayer[0].height);
      ctx.image(orderedLayer[1], ctx.width/2, ctx.height/2, 626, 626);
      ctx.endDraw(); 
      break;
  }
 
}

void computePostProcessBuffer(PGraphics src){
  //1- High pass the source image
  filter.getHighPass(src, 2.0);
  //2- Desaturate the result image
  filter.getDesaturate(filter.getBuffer(), 100.0);
  //3- Compose it with the source image as overlay
  comp.getBlendOverlay(filter.getBuffer(), src, 100.0);

  filter.getChromaWarpHigh(comp.getBuffer(), src.width/2, src.height/2, 0.001, HALF_PI * 0.005);
  // filter.getAnimatedGrainRGB(filter.getBuffer(), 0.01);
}

void exportVideo(){
  if(export){
    if(Time.timeLoop == 0){
      videoExport.saveFrame();
    }else{
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
      String filename = year()+""+month()+""+day()+""+"_"+hour()+""+minute()+""+second()+""+millis()+"_"+CONFIG.simplifiedName+".png";
      ctx.save(CONFIG.exportPathImage+filename);
      break;
    case 'q' :
    case 'Q' :
      videoExport.endMovie();
      exit();
      break;
    case 'e' : 
    case 'E' :
      if(!export){
        export = true;
        Time.resetTimeForExport(this);
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
