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
