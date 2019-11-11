void generateCubeMap() {
  PGL pgl = beginPGL();
  // create the OpenGL-based cubeMap
  IntBuffer envMapTextureID = IntBuffer.allocate(1);
  pgl.genTextures(1, envMapTextureID);
  pgl.activeTexture(PGL.TEXTURE1);
  pgl.enable(PGL.TEXTURE_CUBE_MAP);  
  pgl.bindTexture(PGL.TEXTURE_CUBE_MAP, envMapTextureID.get(0));
  pgl.texParameteri(PGL.TEXTURE_CUBE_MAP, PGL.TEXTURE_WRAP_S, PGL.CLAMP_TO_EDGE);
  pgl.texParameteri(PGL.TEXTURE_CUBE_MAP, PGL.TEXTURE_WRAP_T, PGL.CLAMP_TO_EDGE);
  pgl.texParameteri(PGL.TEXTURE_CUBE_MAP, PGL.TEXTURE_WRAP_R, PGL.CLAMP_TO_EDGE);
  pgl.texParameteri(PGL.TEXTURE_CUBE_MAP, PGL.TEXTURE_MIN_FILTER, PGL.LINEAR);
  pgl.texParameteri(PGL.TEXTURE_CUBE_MAP, PGL.TEXTURE_MAG_FILTER, PGL.LINEAR);

  String[] textureNames = { 
    "posx.jpg", "negx.jpg", "posy.jpg", "negy.jpg", "posz.jpg", "negz.jpg"
  };
  PImage[] textures = new PImage[textureNames.length];
  for (int i=0; i<textures.length; i++) {
    textures[i] = loadImage(MEDIA.path+"cubemap/City/"+textureNames[i]);
  }

  // put the textures in the cubeMap
  for (int i=0; i<textures.length; i++) {
    int w = textures[i].width;
    int h = textures[i].height;
    textures[i].loadPixels();
    int[] pix = textures[i].pixels;
    int[] rgbaPixels = new int[pix.length];
    for (int j = 0; j< pix.length; j++) {
      int pixel = pix[j];
      rgbaPixels[j] = 0xFF000000 | ((pixel & 0xFF) << 16) | ((pixel & 0xFF0000) >> 16) | (pixel & 0x0000FF00);
    }
    pgl.texImage2D(PGL.TEXTURE_CUBE_MAP_POSITIVE_X + i, 0, PGL.RGBA, w, h, 0, PGL.RGBA, PGL.UNSIGNED_BYTE, java.nio.IntBuffer.wrap(rgbaPixels));
  }
  endPGL();
  flush();
}

PShape texturedCube(PImage tex, float scale) {
  PShape cube = createShape();

  cube.beginShape(QUADS);
  cube.texture(tex);

  // +Z "front" face

  cube.vertex(-1*scale, -1*scale, 1*scale, 1024, 1024);
  cube.vertex( 1*scale, -1*scale, 1*scale, 2048, 1024);
  cube.vertex( 1*scale, 1*scale, 1*scale, 2048, 2048);
  cube.vertex(-1*scale, 1*scale, 1*scale, 1024, 2048);

  // -Z "back" face
  cube.vertex( 1*scale, -1*scale, -1*scale, 3072, 1026);
  cube.vertex(-1*scale, -1*scale, -1*scale, 4096, 1026);
  cube.vertex(-1*scale, 1*scale, -1*scale, 4096, 2046);
  cube.vertex( 1*scale, 1*scale, -1*scale, 3072, 2046);

  // +Y "bottom" face
  cube.vertex(-1*scale, 1*scale, 1*scale, 1026, 2048);
  cube.vertex( 1*scale, 1*scale, 1*scale, 2046, 2048);
  cube.vertex( 1*scale, 1*scale, -1*scale, 2046, 3072);
  cube.vertex(-1*scale, 1*scale, -1*scale, 1026, 3072);

  // -Y "top" face
  cube.vertex(-1*scale, -1*scale, -1*scale, 1026, 0);
  cube.vertex( 1*scale, -1*scale, -1*scale, 2046, 0);
  cube.vertex( 1*scale, -1*scale, 1*scale, 2046, 1024);
  cube.vertex(-1*scale, -1*scale, 1*scale, 1026, 1024);

  // +X "right" face
  cube.vertex( 1*scale, -1*scale, 1*scale, 2048, 1026);
  cube.vertex( 1*scale, -1*scale, -1*scale, 3072, 1026 );
  cube.vertex( 1*scale, 1*scale, -1*scale, 3072, 2046);
  cube.vertex( 1*scale, 1*scale, 1*scale, 2048, 2046);

  // -X "left" face
  cube.vertex(-1*scale, -1*scale, -1*scale, 0, 1026);
  cube.vertex(-1*scale, -1*scale, 1*scale, 1024, 1026);
  cube.vertex(-1*scale, 1*scale, 1*scale, 1024, 2046);
  cube.vertex(-1*scale, 1*scale, -1*scale, 0, 2046);

  cube.endShape();
  
  return cube;
}

void displayCubeMap()
{
  pushStyle();
  noStroke();
  shape(cubeMapObj);
  popStyle();
 
  //cameraMatrix correction
  PGraphics3D g3 = (PGraphics3D)g;
  cameraMatrix = g3.camera;
  //cameraMatrix = g3.cameraInv;
  

  
  envShader.set("camMatrix", cameraMatrix);
  
    
}
