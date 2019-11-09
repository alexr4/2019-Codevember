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

public float smoothstep(float edge0, float edge1, float value){
  float t = constrain((value - edge0) / (edge1 - edge0), 0.0, 1.0);
  return t * t * (3.0 - 2.0 * t);
}
