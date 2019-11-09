#version 150

uniform mat4 transformMatrix;
uniform mat4 modelviewMatrix;
uniform mat3 normalMatrix;
uniform mat4 texMatrix;
uniform vec4 lightPosition[8];
uniform vec3 lightDiffuse[8];
uniform float time;
uniform mat4 camMatrix;

in vec4 position;
in vec4 color;
in vec3 normal;
in vec2 texCoord;

uniform float fresnel; // Ratio of indices of refraction
const float fresnelPower = 0.5;
 
 
out FragData {
  vec4 color;
  vec3 ecVertex;
  vec3 normal;
  vec2 texCoord;
  vec3 reflectDir;
  vec3 refractDir;
  float refractRatio;
} FragOut;
 

void main() {
  
  gl_Position = transformMatrix * position;
  vec3 ecp = vec3(modelviewMatrix * position);
  FragOut.ecVertex = ecp;
  FragOut.normal = normalize(normalMatrix * normal);
  FragOut.color =  color;
  FragOut.texCoord = (texMatrix * vec4(texCoord, 1.0, 1.0)).st;

   //Reflection
  vec3 reflectDir =  reflect(normalize(ecp), FragOut.normal);
  vec4 reflectMatrixCorrection = camMatrix * vec4(reflectDir, 0);
  FragOut.reflectDir = reflectMatrixCorrection.xyz;

  //Refracction
  vec3 refractDir =  refract(normalize(ecp),  FragOut.normal, fresnel);
  vec4 refractMatrixCorrection = camMatrix * vec4(refractDir, fresnel);
  FragOut.refractDir = refractMatrixCorrection.xyz;

  float f = ((1.0-fresnel) * (1.0-fresnel)) / ((1.0+fresnel) * (1.0+fresnel));
  FragOut.refractRatio = f + (1.0 - f) * pow((1.0 - dot(-normalize(normalize(ecp).xyz), FragOut.normal)), fresnelPower);

}