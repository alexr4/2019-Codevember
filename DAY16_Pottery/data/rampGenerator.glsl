//blend sources : http://wiki.polycount.com/wiki/Blending_functions

#ifdef GL_ES
precision mediump float;
precision mediump int;
#endif

uniform sampler2D texture;
uniform float time;
uniform vec2 resolution;

in vec4 vertTexCoord;
out vec4 fragColor;

/*Maths Helpers*/
float random(float value){
  return fract(sin(value) * 43758.5453123);
}

float random(vec2 tex){
  //return fract(sin(x) * offset);
  return fract(sin(dot(tex.xy, vec2(12.9898, 78.233))) * 43758.5453123);//43758.5453123);
}

// Simplex 2D noise
//
vec3 permute(vec3 x) { return mod(((x*34.0)+1.0)*x, 289.0); }

float snoise(vec2 v){
  const vec4 C = vec4(0.211324865405187, 0.366025403784439,
           -0.577350269189626, 0.024390243902439);
  vec2 i  = floor(v + dot(v, C.yy) );
  vec2 x0 = v -   i + dot(i, C.xx);
  vec2 i1;
  i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
  vec4 x12 = x0.xyxy + C.xxzz;
  x12.xy -= i1;
  i = mod(i, 289.0);
  vec3 p = permute( permute( i.y + vec3(0.0, i1.y, 1.0 ))
  + i.x + vec3(0.0, i1.x, 1.0 ));
  vec3 m = max(0.5 - vec3(dot(x0,x0), dot(x12.xy,x12.xy),
    dot(x12.zw,x12.zw)), 0.0);
  m = m*m ;
  m = m*m ;
  vec3 x = 2.0 * fract(p * C.www) - 1.0;
  vec3 h = abs(x) - 0.5;
  vec3 ox = floor(x + 0.5);
  vec3 a0 = x - ox;
  m *= 1.79284291400159 - 0.85373472095314 * ( a0*a0 + h*h );
  vec3 g;
  g.x  = a0.x  * x0.x  + h.x  * x0.y;
  g.yz = a0.yz * x12.xz + h.yz * x12.yw;
  return 130.0 * dot(m, g);
}

void main(){
	vec2 uv = gl_FragCoord.xy / resolution.xy;
	vec4 tex = texture(texture, uv);

	vec2 colsRows = vec2(2.0, 1.0);
	vec2 nuv = uv * colsRows;
	vec2 fuv = fract(nuv);
	vec2 iuv = floor(nuv);

	float rnd = mix(1.0, 8.0, random(time));

	float noiseUV = (snoise(vec2(fuv.y * rnd)) * 0.5 + 0.5);


	vec3 color = vec3(noiseUV);
	fragColor = vec4(color, 1.0);
}