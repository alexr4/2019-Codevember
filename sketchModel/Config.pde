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
}

static public class UI{
  static public String tags, author, challenge;
  static public String date, simpledDate;
}


private void loadConfig(String configfile) {
  try {
    JSONObject config       = new JSONObject(loadJSONObject(configfile).toString());
    JSONObject output       = config.getJSONObject("output");
    JSONObject ui           = config.getJSONObject("UIInfo");
    JSONObject time         = config.getJSONObject("Time");

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

    checkDirectoryForExports(CONFIG.exportPathImage);
    checkDirectoryForExports(CONFIG.exportPathVideo);

    JSONArray uitags            = ui.getJSONArray("tags");
    for(int i=0; i<uitags.length(); i++){
      String tag = uitags.getString(i);
      UI.tags += "#"+tag+" ";
    }
    UI.author                   = ui.getString("authors");
    UI.challenge                = ui.getString("challenge");
    Date date = new Date();
    SimpleDateFormat dateFormat = new SimpleDateFormat("EEEE d MMMM");
    UI.date                     = dateFormat.format(date);
    UI.simpledDate              = year()+""+month()+""+day();

    println(CONFIG.appname+" config ready.\n"+
      "Visual Output: "+ CONFIG.width + "x" + CONFIG.height + "\tTarget FPS: " + CONFIG.fps + "\tPosition: " + CONFIG.windowX + "x" + CONFIG.windowY);
  } 
  catch (Exception e) {
    e.printStackTrace();
  }
}

public void checkDirectoryForExports(String path){
    try{
      File directory = new File(path);
      if (! directory.exists()){
        directory.mkdir();
      }else{
      }
    }catch(Exception e){
    }
}
