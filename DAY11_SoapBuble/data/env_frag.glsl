uniform samplerCube cubemap;
uniform float time;

in vec3 reflectDir;
in vec3 refractDir;
in float refractRatio;
in vec3 ecVertex;
in vec3 ecNormal;

float random(float value){
	return fract(sin(value) * 43758.5453123);
}

float random(vec2 tex){
	//return fract(sin(x) * offset);
	return fract(sin(dot(tex.xy, vec2(12.9898, 78.233))) * 43758.5453123);//43758.5453123);
}

vec4 permute(vec4 x){return mod(((x*34.0)+1.0)*x, 289.0);}
vec4 taylorInvSqrt(vec4 r){return 1.79284291400159 - 0.85373472095314 * r;}

float map(float value, float oMin, float oMax, float iMin, float iMax){
    return iMin + ((value - oMin)/(oMax - oMin)) * (iMax - iMin);
}

float snoise(vec3 v){ 
  const vec2  C = vec2(1.0/6.0, 1.0/3.0) ;
  const vec4  D = vec4(0.0, 0.5, 1.0, 2.0);

// First corner
  vec3 i  = floor(v + dot(v, C.yyy) );
  vec3 x0 =   v - i + dot(i, C.xxx) ;

// Other corners
  vec3 g = step(x0.yzx, x0.xyz);
  vec3 l = 1.0 - g;
  vec3 i1 = min( g.xyz, l.zxy );
  vec3 i2 = max( g.xyz, l.zxy );

  //  x0 = x0 - 0. + 0.0 * C 
  vec3 x1 = x0 - i1 + 1.0 * C.xxx;
  vec3 x2 = x0 - i2 + 2.0 * C.xxx;
  vec3 x3 = x0 - 1. + 3.0 * C.xxx;

// Permutations
  i = mod(i, 289.0 ); 
  vec4 p = permute( permute( permute( 
             i.z + vec4(0.0, i1.z, i2.z, 1.0 ))
           + i.y + vec4(0.0, i1.y, i2.y, 1.0 )) 
           + i.x + vec4(0.0, i1.x, i2.x, 1.0 ));

// Gradients
// ( N*N points uniformly over a square, mapped onto an octahedron.)
  float n_ = 1.0/7.0; // N=7
  vec3  ns = n_ * D.wyz - D.xzx;

  vec4 j = p - 49.0 * floor(p * ns.z *ns.z);  //  mod(p,N*N)

  vec4 x_ = floor(j * ns.z);
  vec4 y_ = floor(j - 7.0 * x_ );    // mod(j,N)

  vec4 x = x_ *ns.x + ns.yyyy;
  vec4 y = y_ *ns.x + ns.yyyy;
  vec4 h = 1.0 - abs(x) - abs(y);

  vec4 b0 = vec4( x.xy, y.xy );
  vec4 b1 = vec4( x.zw, y.zw );

  vec4 s0 = floor(b0)*2.0 + 1.0;
  vec4 s1 = floor(b1)*2.0 + 1.0;
  vec4 sh = -step(h, vec4(0.0));

  vec4 a0 = b0.xzyw + s0.xzyw*sh.xxyy ;
  vec4 a1 = b1.xzyw + s1.xzyw*sh.zzww ;

  vec3 p0 = vec3(a0.xy,h.x);
  vec3 p1 = vec3(a0.zw,h.y);
  vec3 p2 = vec3(a1.xy,h.z);
  vec3 p3 = vec3(a1.zw,h.w);

//Normalise gradients
  vec4 norm = taylorInvSqrt(vec4(dot(p0,p0), dot(p1,p1), dot(p2, p2), dot(p3,p3)));
  p0 *= norm.x;
  p1 *= norm.y;
  p2 *= norm.z;
  p3 *= norm.w;

// Mix final noise value
  vec4 m = max(0.6 - vec4(dot(x0,x0), dot(x1,x1), dot(x2,x2), dot(x3,x3)), 0.0);
  m = m * m;
  return 42.0 * dot( m*m, vec4( dot(p0,x0), dot(p1,x1), 
                                dot(p2,x2), dot(p3,x3) ) );
}

vec3 pal( in float t, in vec3 a, in vec3 b, in vec3 c, in vec3 d )
{
    return a + b*cos( 6.28318*(c*t+d) );
}


vec4 iridescence(float orientation, vec3 position)//iridescence base on orientation
{
    vec3 iridescent;
    float frequence = .5;
    float offset = 2.0;
    float noiseInc = 1.5;

    // iridescent.x = abs(cos(orientation * frequence + snoise(position) * noiseInc + 1 * offset));
    // iridescent.y = abs(cos(orientation * frequence + snoise(position) * noiseInc + 2 * offset));
    // iridescent.z = abs(cos(orientation * frequence + snoise(position) * noiseInc + 3 * offset));
    vec2 uv = gl_FragCoord.xy / vec2(1000);
    float n = snoise(vec3(uv * 2., time)) * 2. - 1.0  + random(uv) * .25;
    float t = abs(cos(orientation * frequence + snoise(position) * noiseInc + 1 * offset)) + n;

    vec3 palette = pal(abs(fract(t)), vec3(0.5,0.5,0.5),vec3(0.5,0.5,0.5),vec3(2.0,1.0,0.0),vec3(0.5,0.20,0.25));
    return vec4(palette, t / 2.);
}

float luma(vec3 color) {
  return dot(color, vec3(0.299, 0.587, 0.114));
}

void main() {
	vec4 mainColor = vec4(vec3(0, 0, .25), 1.0);
	vec3 ecv = normalize(ecVertex);
    // if(!gl_FrontFacing)
    // {
    //     ecVertex = normalize(ecVertex);
    // }
    float facingRatio = dot(ecNormal, ecv);

    vec4 iridescentColor = vec4(iridescence(facingRatio, ecv * .05));/* 
                            map(pow(1 - facingRatio, 1.0/0.75), 0.0, 1.0, 0.1, 1);*/
    //float alpha = luma(iridescentColor.rgb);
    iridescentColor.rgb = pow(iridescentColor.rgb, vec3(2.25));;

  	vec3 refle = vec3(reflectDir.x, -reflectDir.y, reflectDir.z);
  	vec3 refra = vec3(refractDir.x, -refractDir.y, refractDir.z);

  	vec4 refractColor = textureCube(cubemap, refra);
  	vec4 refractRed = textureCube(cubemap, refra + vec3(iridescentColor.w * 0.015));
  	vec4 refractGreen = textureCube(cubemap, refra);
  	vec4 refractBlue = textureCube(cubemap, refra - vec3(iridescentColor.w * 0.015));
  	refractColor.rgb = vec3(refractRed.x, refractGreen.g, refractBlue.b);
  	refractColor = mix(refractColor, mainColor, 0.5);
  	refractColor.rgb += iridescentColor.rgb * 0.2; 
  	refractColor.rgb = pow(refractColor.rgb, vec3(0.65));
  	//refractColor.a = alpha * 0.5;

  	vec4 reflectColor = textureCube(cubemap, refle);
  	reflectColor = mix(reflectColor, mainColor, 0.0);

  	 
    //refractColor.rgb = iridescentColor.rgb * 0.25;
    //refractColor.a = alpha;
  	gl_FragColor = refractColor;//mix(reflectColor, refractColor, refractRatio);//;//


}
