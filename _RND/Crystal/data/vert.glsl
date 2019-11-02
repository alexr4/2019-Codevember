#version 150

uniform mat4 transformMatrix;
uniform mat4 modelviewMatrix;
uniform mat3 normalMatrix;
uniform mat4 texMatrix;
uniform vec4 lightPosition[8];
uniform vec3 lightDiffuse[8];
uniform float time;
uniform vec2 mouse;
uniform vec2 viewport = vec2(1920.0, 1080.0);
uniform float textureRatio;

uniform sampler2D displacementMap;
uniform float displacementFactor = 0.0;

in vec4 position;
in vec4 color;
in vec3 normal;
in vec2 texCoord;
 
out FragData {
  vec4 color;
  vec4 vertex;
  vec3 ecVertex;
  vec3 normal;
  vec2 texCoord;
} FragOut;


float luma(vec4 color) {
  return dot(color.rgb, vec3(0.299, 0.587, 0.114));
}

void main() {
  
  FragOut.texCoord = (texMatrix * vec4(texCoord, 1.0, 1.0)).st;
  FragOut.normal = normalize(normalMatrix * normal);


  // vec2 viewport = vec2(1280.0, 720.0);
  // vec4 posProjection = transformMatrix * position;
  // float u = textureRatio / posProjection.w * ((posProjection.x + posProjection.w) * 0.5);// + 0.5/ viewport.x;// * viewport.x * posProjection.w);
  // float v = textureRatio / posProjection.w * ((posProjection.w - posProjection.y) * 0.5);// + 0.5/ viewport.y;// * viewport.y * posProjection.w);
 // vec2 uvDisplace = (texMatrix * vec4(u, v, 1.0, 1.0)).xy;

  
  vec4 dv = texture2D(displacementMap, fract(FragOut.texCoord * 4.0));
  float df = luma(dv);
  float adf = mod(df + time, 1.0);
  vec3 norm = normalize(position.xyz);
  vec4 dp = mix(position + vec4(norm * displacementFactor * df * 0.2 * -1.0, 0.0), vec4(norm * displacementFactor * df, 0.0) + position, df);

  gl_Position = transformMatrix * dp;
  FragOut.vertex = transformMatrix * dp;
  vec3 ecp = vec3(modelviewMatrix * dp);
  FragOut.ecVertex = ecp;
  FragOut.color =  color;
}