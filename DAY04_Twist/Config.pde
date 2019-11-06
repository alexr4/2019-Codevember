import java.text.*;
import java.util.*;
import java.nio.file.*;

static public class CONFIG {
  static public int width, height, originalWidth, originalHeight, windowX, windowY, fps = 60;
  static public float aspectRatio;
  static public int smooth = 8;
  static public float scale;
  static public String appname, exportPath, simplifiedName, exportPathImage, exportPathVideo;
  static public boolean  topBar;
  static public PGraphics ctx;

  static public int timeDuration;
  static public int timeAnimation;
}

static public class FFMPEGPARAMS{
  static public int fps, videoQuality, audioQuality;
  static public boolean debug;
}

static public class UI{
  static public String tags, author, challenge, title;
  static public String date, simpledDate;
  static public boolean dynamicDate;
}

static public class MEDIA{
  static public String path, maskpath, fontpath;
  static public String maskurl, mainfonturl;
  static public PImage mask;
  static public PFont mainfont;
  static public String cubemapath;
  static public String matpath;

  static public void loadAsset(PApplet ctx){
    mask     = ctx.loadImage(maskurl);
    mainfont = ctx.createFont(mainfonturl, 24, true);
  }
}

static public class CSS{
  static public int marginX, marginY, titleMarginX, titleMarginY;
  static public int infoFontSize, titleFontSize;
  static public float titleLineHeight;
}

private void loadConfig(String configfile) {
  try {
    JSONObject config           = new JSONObject(loadJSONObject(configfile).toString());
    JSONObject output           = config.getJSONObject("output");
    JSONObject ui               = config.getJSONObject("UIInfo");
    JSONObject time             = config.getJSONObject("Time");
    JSONObject media            = config.getJSONObject("Media");
    JSONObject css              = ui.getJSONObject("CSS");
    JSONObject render           = config.getJSONObject("Render");
    JSONObject ffmpeg           = config.getJSONObject("FFMEPG");

    CONFIG.appname              = config.getString("title");
    CONFIG.originalWidth        = output.getInt("width");
    CONFIG.originalHeight       = output.getInt("height");
    CONFIG.scale                = (float) output.getDouble("scale");
    CONFIG.fps                  = output.getInt("fps");
    CONFIG.windowX              = output.getInt("x");
    CONFIG.windowY              = output.getInt("y");
    CONFIG.smooth               = output.getInt("smooth");
    CONFIG.topBar               = output.getBoolean("topBar");
    CONFIG.width                = round(CONFIG.originalWidth * CONFIG.scale);
    CONFIG.height               = round(CONFIG.originalHeight * CONFIG.scale);
    CONFIG.exportPath           = output.getString("exportPath");
    CONFIG.simplifiedName       = CONFIG.appname.replaceAll("[^a-zA-Z0-9]", "");
    CONFIG.aspectRatio          = (float)CONFIG.width / (float)CONFIG.height;
    CONFIG.timeDuration         = time.getInt("duration");
    CONFIG.exportPathImage      = CONFIG.exportPath+"images/";
    CONFIG.exportPathVideo      = CONFIG.exportPath+"videos/";
    CONFIG.timeAnimation        = time.getInt("animationTime");

    checkDirectoryForExports(CONFIG.exportPathImage);
    checkDirectoryForExports(CONFIG.exportPathVideo);

    FFMPEGPARAMS.fps            = ffmpeg.getInt("fps");
    FFMPEGPARAMS.videoQuality   = ffmpeg.getInt("videoQuality");
    FFMPEGPARAMS.audioQuality   = ffmpeg.getInt("audioQuality");
    FFMPEGPARAMS.debug          = ffmpeg.getBoolean("debug");

    JSONArray uitags            = ui.getJSONArray("tags");
    UI.tags                     = "";
    for(int i=0; i<uitags.length(); i++){
      String tag = uitags.getString(i);
      UI.tags += ("#"+tag+" ").toUpperCase();
    }
    UI.title                    = (ui.getString("title")).toUpperCase();
    UI.author                   = (ui.getString("authors")).toUpperCase();
    UI.challenge                = (ui.getString("challenge")).toUpperCase();
    UI.dynamicDate              = ui.getBoolean("dynamicDate");
    Date date = new Date();
    if(!UI.dynamicDate){
      SimpleDateFormat nonDynamicDateFormat = new SimpleDateFormat("dd/MM/yyyy");
      date = nonDynamicDateFormat.parse(ui.getString("date"));
    }
   SimpleDateFormat dateFormat = new SimpleDateFormat("EEEE d MMMM");
    UI.date                     = (dateFormat.format(date)).toUpperCase();
    UI.simpledDate              = year()+""+month()+""+day();


    MEDIA.path                  = sketchPath(media.getString("path"));
    MEDIA.maskpath              = MEDIA.path+media.getString("maskFolder");
    MEDIA.fontpath              = MEDIA.path+media.getString("fontFolder");
    MEDIA.maskurl               = MEDIA.maskpath+media.getString("mask");
    MEDIA.mainfonturl           = MEDIA.fontpath+media.getString("mainFont");
    MEDIA.cubemapath            = MEDIA.path+media.getString("cubemapFolder");
    MEDIA.matpath               = MEDIA.path+media.getString("matFolder");

    CSS.marginX                 = css.getJSONObject("margin").getJSONArray("main").getInt(0);
    CSS.marginY                 = css.getJSONObject("margin").getJSONArray("main").getInt(1);
    CSS.titleMarginX            = css.getJSONObject("margin").getJSONArray("title").getInt(0);
    CSS.titleMarginY            = css.getJSONObject("margin").getJSONArray("title").getInt(1);
    CSS.infoFontSize            = css.getJSONObject("infos").getInt("fontsize");
    CSS.titleFontSize           = css.getJSONObject("title").getInt("fontsize");
    CSS.titleLineHeight         = css.getJSONObject("title").getInt("lineheight");

    switch((render.getString("type")).toUpperCase()){
      case TYPE.TRANSPARENT : 
        RENDERPARAMS.type = TYPE.iTRANSPARENT;
        break;
      case TYPE.CIRCMASK : 
        RENDERPARAMS.type = TYPE.iCIRCMASK;
        break;
      case TYPE.SQUAREDMASK : 
        RENDERPARAMS.type = TYPE.iSQUAREDMASK;
        break;
    }

    println(CONFIG.appname+" config ready.\n"+
      "Visual Output: "+ CONFIG.width + "x" + CONFIG.height + "\tTarget FPS: " + CONFIG.fps + "\tPosition: " + CONFIG.windowX + "x" + CONFIG.windowY);
  } 
  catch (Exception e) {
    e.printStackTrace();
  }
}
