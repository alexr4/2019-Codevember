#ifdef GL_ES
precision highp float;
precision highp int;
#endif

//Defines raymarcher constants
#define PI 3.1415926535897932384626433832795
#define TWOPI (PI * 2.0)

//Defines GPGPU constants
const vec4 efactor = vec4(1.0, 255.0, 65025.0, 16581375.0);
const vec4 dfactor = vec4(1.0/1.0, 1.0/255.0, 1.0/65025.0, 1.0/16581375.0);
const float mask = 1.0/256.0;

//defines bound informations from p5
uniform vec2 resolution;
uniform vec2 mouse;
uniform float time;
uniform sampler2D albedoMap;
uniform sampler2D normalMap;
uniform sampler2D specularMap;
uniform sampler2D displacementMap;
uniform sampler2D startRamp;
uniform sampler2D endRamp;
uniform float easing;
uniform float startTime;
uniform float endTime;

in vec4 vertTexCoord;
in vec4 color;
out vec4 fragColor;

//Post Process
const float gamma = 2.2;

//RAYMARCHIN CONSTANT
#define OCTAVE 8
#define FAR 1000.0
#define MAX_STEPS 32 * 4 //max iteration on the marching loop
#define MAX_STEPS_SHADOW 32 * 4 //max iteration on the marching loop for shadow
#define MAX_DIST FAR * 1.5 //maximum distance from camera //based on near and far
#define SHADOW_DIST_DIV 1.5
#define MAX_DIST_SHADOW (FAR * SHADOW_DIST_DIV)  //based on near and far
#define SURFACE_DIST 0.001 // minimum distance for a Hit
#define SHADOW_SURFACE_DIST 0.001

struct VoroStruct{
  vec2 dist;
  vec2 indices;
};

/*Time system computation*/
struct Time{
  float time;
  float modTime;
  float normTime;
  float timeLoop;
  float maxTime;
};

/*Time management*/
Time computeTime(float atime, float maxTime){
  float modTime = floor(mod(atime, maxTime));
  float normTime = mod(atime, maxTime) / maxTime;
  float timeLoop = floor(atime / maxTime);
  Time time = Time(
    atime,
    modTime,
    normTime,
    timeLoop,
    maxTime
    );
  return time;
}


//smooth min/max
vec2 smin(vec2 a, vec2 b, float k){
  float h = clamp(0.5 + 0.5 * (b.x - a.x) / k, 0.0, 1.0);
  float d = mix(b.x, a.x, h) - k * h * (1.0 - h);
  // // float index = (a.x < b.x) ? a.y : b.y;//mix(b.y, a.y, h);
  float index = mix(b.y, a.y, h);
  return vec2(d, index);
}

vec2 smax(vec2 a, vec2 b, float k){
  float h = clamp(0.5 - 0.5 * (b.x - a.x) / k, 0.0, 1.0);
  float d = mix(b.x, a.x, h) + k * h * (1.0 - h);
  float index = mix(b.y, a.y, h);
  return vec2(d, index);
}

// IQ's polynomial-based smooth minimum function.
float smin( float a, float b, float k ){

    float h = clamp(.5 + .5*(b - a)/k, 0., 1.);
    return mix(b, a, h) - k*h*(1. - h);
}

// Commutative smooth minimum function. Provided by Tomkh and taken from
// Alex Evans's (aka Statix) talk:
// http://media.lolrus.mediamolecule.com/AlexEvans_SIGGRAPH-2015.pdf
// Credited to Dave Smith @media molecule.
float smin2(float a, float b, float r)
{
   float f = max(0., 1. - abs(b - a)/r);
   return min(a, b) - r*.25*f*f;
}

// IQ's exponential-based smooth minimum function. Unlike the polynomial-based
// smooth minimum, this one is associative and commutative.
float sminExp(float a, float b, float k)
{
    float res = exp(-k*a) + exp(-k*b);
    return -log(res)/k;
}

/*Maths Helpers*/
float random(float value){
  return fract(sin(value) * 43758.5453123);
}

float random(vec2 tex){
  //return fract(sin(x) * offset);
  return fract(sin(dot(tex.xy, vec2(12.9898, 78.233))) * 43758.5453123);//43758.5453123);
}

float random(vec3 tex){
  //return fract(sin(x) * offset);
  return fract(sin(dot(tex.xyz, vec3(12.9898, 78.233, 12.9898))) * 43758.5453123);//43758.5453123);
}

vec2 random2D(vec2 uv){
  uv = vec2(dot(uv, vec2(127.1, 311.7)), dot(uv, vec2(269.5, 183.3)));
  return -1.0 + 2.0 * fract(sin(uv) * 43758.5453123);
}

vec3 random3D(vec3 uv){
  uv = vec3(dot(uv, vec3(127.1, 311.7, 120.9898)), dot(uv, vec3(269.5, 183.3, 150.457)), dot(uv, vec3(380.5, 182.3, 170.457)));
  return -1.0 + 2.0 * fract(sin(uv) * 43758.5453123);
}


float cubicCurve(float value){
  return value * value * (3.0 - 2.0 * value); // custom cubic curve
}

vec2 cubicCurve(vec2 value){
  return value * value * (3.0 - 2.0 * value); // custom cubic curve
}

vec3 cubicCurve(vec3 value){
  return value * value * (3.0 - 2.0 * value); // custom cubic curve
}

float noise(vec2 uv){
  vec2 iuv = floor(uv);
  vec2 fuv = fract(uv);
  vec2 suv = cubicCurve(fuv);

  float dotAA_ = dot(random2D(iuv + vec2(0.0)), fuv - vec2(0.0));
  float dotBB_ = dot(random2D(iuv + vec2(1.0, 0.0)), fuv - vec2(1.0, 0.0));
  float dotCC_ = dot(random2D(iuv + vec2(0.0, 1.0)), fuv - vec2(0.0, 1.0));
  float dotDD_ = dot(random2D(iuv + vec2(1.0, 1.0)), fuv - vec2(1.0, 1.0));

  return mix(
    mix(dotAA_, dotBB_, suv.x),
    mix(dotCC_, dotDD_, suv.x),
    suv.y);
}

float noise(vec3 uv){
  vec3 iuv = floor(uv);
  vec3 fuv = fract(uv);
  vec3 suv = cubicCurve(fuv);

  float dotAA_ = dot(random3D(iuv + vec3(0.0)), fuv - vec3(0.0));
  float dotBB_ = dot(random3D(iuv + vec3(1.0, 0.0, 0.0)), fuv - vec3(1.0, 0.0, 0.0));
  float dotCC_ = dot(random3D(iuv + vec3(0.0, 1.0, 0.0)), fuv - vec3(0.0, 1.0, 0.0));
  float dotDD_ = dot(random3D(iuv + vec3(1.0, 1.0, 0.0)), fuv - vec3(1.0, 1.0, 0.0));

  float dotEE_ = dot(random3D(iuv + vec3(0.0, 0.0, 1.0)), fuv - vec3(0.0, 0.0, 1.0));
  float dotFF_ = dot(random3D(iuv + vec3(1.0, 0.0, 1.0)), fuv - vec3(1.0, 0.0, 1.0));
  float dotGG_ = dot(random3D(iuv + vec3(0.0, 1.0, 1.0)), fuv - vec3(0.0, 1.0, 1.0));
  float dotHH_ = dot(random3D(iuv + vec3(1.0, 1.0, 1.0)), fuv - vec3(1.0, 1.0, 1.0));

  float passH0 = mix(
    mix(dotAA_, dotBB_, suv.x),
    mix(dotCC_, dotDD_, suv.x),
    suv.y);

  float passH1 = mix(
    mix(dotEE_, dotFF_, suv.x),
    mix(dotGG_, dotHH_, suv.x),
    suv.y);

  return mix(passH0, passH1, suv.z);
}

//	Simplex 3D Noise 
//	by Ian McEwan, Ashima Arts
//
vec4 permute(vec4 x){return mod(((x*34.0)+1.0)*x, 289.0);}
vec4 taylorInvSqrt(vec4 r){return 1.79284291400159 - 0.85373472095314 * r;}

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



VoroStruct voronoiDistance(vec2 st, vec2 colsrows, float seed, float minRound, float maxRound)
{
	vec2 nuv = st * colsrows;
	vec2 iuv = floor(nuv);
	vec2 fuv = fract(nuv);

    vec2 nearestNeighborsIndex;
    vec2 nearestDiff;
    vec2 cellindex;

    //compute voronoi
    float dist = 8.0;
    for( int j=-1; j<=1; j++ ){
    	for( int i=-1; i<=1; i++ )
    	{
    		//neightbor
        	vec2 neighbor = vec2(i, j);

        	//randomPoint
        	vec2 point = random2D(iuv + neighbor);

        	//animation
        	point = 0.5 + 0.5* sin(seed + TWOPI * point);

        	//define the vector between the pixel and the point
        	vec2  diff = neighbor + point - fuv;

        	//Compute the Dot product
        	float d = dot(diff,diff);

    	    if(d < dist)
    	    {
    	        dist = d;
    	        nearestDiff = diff;
    	        nearestNeighborsIndex = neighbor;
    	        cellindex = (iuv + vec2(i, j)) / colsrows;
    	    }
    	}
	}
	float basedVoronoi = dist;

  //compute distance
  dist = 8.0;
  float sdist = 8.0;
  for( int j=-2; j<=2; j++ ){
  	for( int i=-2; i<=2; i++ )
  	{
  		//neightbor
  	    vec2 neighbor = nearestNeighborsIndex + vec2(i, j);

  	    //randomPoint
  	    vec2 point = random2D(iuv + neighbor);

      	//animation
      	point = 0.5 + 0.5* sin(seed + TWOPI * point);

      	//define the vector between the pixel and the point
  	    vec2  diff = neighbor + point - fuv;

      	//Compute the Dot product to get the distance
  	    float d = dot(0.5 * (nearestDiff + diff), normalize(diff - nearestDiff));


  	   //rounded voronoi distance from https://www.shadertoy.com/view/lsSfz1
  	   //Skip the same cell
  	    if( dot(diff-nearestDiff, diff-nearestDiff)>.00001){
  	   		 // Abje's addition. Border distance using a smooth minimum. Insightful, and simple.
         		 // On a side note, IQ reminded me that the order in which the polynomial-based smooth
         		 // minimum is applied effects the result. However, the exponentional-based smooth
         		 // minimum is associative and commutative, so is more correct. In this particular case,
         		 // the effects appear to be negligible, so I'm sticking with the cheaper polynomial-based
         		 // smooth minimum, but it's something you should keep in mind. By the way, feel free to
         		 // uncomment the exponential one and try it out to see if you notice a difference.
         		 //
         		 // // Polynomial-based smooth minimum.
             float round = mix(minRound, maxRound, noise(cellindex * 100.0));
         		sdist = smin(sdist, d, round);


          	// Exponential-based smooth minimum. By the way, this is here to provide a visual reference
          	// only, and is definitely not the most efficient way to apply it. To see the minor
          	// adjustments necessary, refer to Tomkh's example here: Rounded Voronoi Edges Analysis -
          	// https://www.shadertoy.com/view/MdSfzD
          	//sdist = sminExp(sdist, d, 20.);
      	}
  	    //voronoi distance
  	    dist = min(dist, d);
      }
    }

    VoroStruct vs = VoroStruct(
        vec2(sdist, dist),
        cellindex
      );

    return vs;
}

float fbm(vec3 st, float amp, float freq, float lac, float gain){
  //initial value
  float fbm = 0.0;

  for(int i = 0; i < OCTAVE; i++){
    fbm += amp * noise(st * freq);
    freq *= lac;
    amp *= gain;
  }

  return fbm;
}

/*Camera computation*/
vec3 R(vec2 uv, vec3 p, vec3 o, vec3 axis, float z) { //this function return the ray direction from a non aligned axis camera
    vec3 f = normalize(o-p),
        r = normalize(cross(axis, f)),
        u = cross(f,r),
        c = p+f*z,
        i = c + uv.x*r + uv.y*u,
        d = normalize(i-p);
    return d;
}

/*Screen Space normal mapping*/
// http://www.thetenthplanet.de/archives/1180
mat3 cotangent_frame(vec3 N, vec3 p, vec2 uv)
{
    // récupère les vecteurs du triangle composant le pixel
    vec3 dp1 = dFdx( p );
    vec3 dp2 = dFdy( p );
    vec2 duv1 = dFdx( uv );
    vec2 duv2 = dFdy( uv );

    // résout le système linéaire
    vec3 dp2perp = cross( dp2, N );
    vec3 dp1perp = cross( N, dp1 );
    vec3 T = dp2perp * duv1.x + dp1perp * duv2.x;
    vec3 B = dp2perp * duv1.y + dp1perp * duv2.y;

    // construit une trame invariante à l'échelle
    float invmax = inversesqrt( max( dot(T,T), dot(B,B) ) );
    return mat3( T * invmax, B * invmax, N );
}

vec3 perturb_normal( vec3 N, vec3 V, vec2 texcoord, sampler2D normalMap)
{
    // N, la normale interpolée et
    // V, le vecteur vue (vertex dirigé vers l'œil)
    vec3 map = texture2D(normalMap, texcoord).xyz;
    map = map * 255./127. - 128./127.;
    mat3 TBN = cotangent_frame(N, -V, texcoord);
    return normalize(TBN * map);
}

vec2 topDownUvProjection(vec3 pos, float textureFreq, vec2 offset){
    vec2 uv = textureFreq * (pos.xy + offset);
    uv.x = 1.0 - uv.x;

    return uv;
}


/*RayMarcher primitives*/
vec2 sdSphere(vec3 p, float r, float index){
  
  return vec2(length(p) - r, index);
}

vec2 sdCapsule(vec3 p, vec3 a, vec3 b, float r, float index){
  vec3 ab = b-a;
  vec3 ap = p-a;

  float t = dot(ab, ap) / dot(ab, ab); //project ray on the line between the two sphere of teh capsule to get the distance
  t = clamp(t, 0.0, 1.0);

  vec3 c = a + t * ab; // get the ray a to the ab
  return vec2(length(p-c) - r, index); // get the distance between p and the c
}

vec2 sdTorus(vec3 p, vec2 r, float index){
  float x = length(p.xz) - r.x;
  return vec2(length(vec2(x, p.y)) - r.y, index);
}

vec2 sdBox(vec3 p, vec3 s, float index){
  vec3 d = abs(p) -s;

  return vec2(length(max(d, 0.0)) + min(max(d.x, max(d.y, d.z)), 0.0), //remove this line for an only partially signed sdf
              index);
}

vec2 sdCylinder(vec3 p, vec3 a, vec3 b, float r, float index){
  vec3 ab = b-a;
  vec3 ap = p-a;

  float t = dot(ab, ap) / dot(ab, ab); //project ray on the line between the two sphere of teh capsule to get the distance
  //t = clamp(t, 0.0, 1.0);

  vec3 c = a + t * ab; // get the ray a to the ab

  float x = length(p-c) - r; // get the distance between p and the c
  float y = (abs(t - 0.5) - 0.5) * length(ab);
  float e = length(max(vec2(x, y), 0.0));
  float i = min(max(x, y), 0.0);
  return vec2(e + i, index);
}

vec2 sdRoundBox(vec3 p, vec3 s, float r, float index){
  vec3 d = abs(p) -s;

  return vec2(length(max(d, 0.0)) - r + min(max(d.x, max(d.y, d.z)), 0.0), //remove this line for an only partially signed sdf
              index);
}

float dot2( in vec2 v ) { return dot(v,v);}
vec2 sdCone(vec3 p, float h, float r1, float r2, float index){
    vec2 q = vec2( length(p.xz), p.y );

    vec2 k1 = vec2(r2,h);
    vec2 k2 = vec2(r2-r1,2.0*h);
    vec2 ca = vec2(q.x-min(q.x,(q.y < 0.0)?r1:r2), abs(q.y)-h);
    vec2 cb = q - k1 + k2*clamp( dot(k1-q,k2)/dot2(k2), 0.0, 1.0 );
    float s = (cb.x < 0.0 && ca.y < 0.0) ? -1.0 : 1.0;
    return vec2(s*sqrt(min(dot2(ca),dot2(cb))), index);
}

/*Raymarcher operator*/
vec2 opUnite(vec2 d1, vec2 d2){
  return (d1.x < d2.x) ? d1 : d2;//min(d1, d2);
}

vec2 opSubstract(vec2 d1, vec2 d2){
  return (-d1.x < d2.x) ? d2 : vec2(-d1.x, d1.y);//max(-d1, d2);
}

vec2 opIntersect(vec2 d1, vec2 d2){
  return (d1.x < d2.x) ? d2 : d1;//max(d1, d2);
}

vec2 opMorph(vec2 d1, vec2 d2, float offset){
  return mix(d1, d2, offset);
}

vec2 opSmoothUnite(vec2 d1, vec2 d2, float k){
  return smin(d1, d2, k);;
}

vec2 opSmoothUniteID(vec2 d1, vec2 d2, float k){
  float h = clamp(0.5 + 0.5 * (d2.x - d1.x) / k, 0.0, 1.0);
  float d = mix(d2.x, d1.x, h) - k * h * (1.0 - h);
  // // float index = (a.x < b.x) ? a.y : b.y;//mix(b.y, a.y, h);
  float index = mix(d2.y, d1.y, pow(h, 4.0) * 20.0);
  return vec2(d, index);
}


vec2 opSmoothSubstract(vec2 d1, vec2 d2, float k){
  return smax(vec2(-d1.x, d1.y), d2, k);
}

vec2 opSmoothIntersect(vec2 d1, vec2 d2, float k){
  return smax(d1, d2, k);
}

/*Raymarcher displacement*/
vec3 opRepeat(vec3 p, vec3 freqXYZ){
  return (mod(p, freqXYZ) - 0.5 * freqXYZ);
}

float displace(vec3 p, vec3 freqXYZ, float inc, vec3 time){
  return (sin(freqXYZ.x * p.x + time.x) * cos(freqXYZ.y * p.y + time.y) * sin(freqXYZ.z * p.z + time.z)) * inc;
}

vec3 deform(vec3 p, vec3 freqXYZ, float inc){
  //1.0, 0.5, 0.25
    p.xyz += (freqXYZ.x * sin(2.0 * p.zxy)) * inc;
    p.xyz += (freqXYZ.y * sin(4.0 * p.zxy)) * inc;
    p.xyz += (freqXYZ.z * sin(8.0 * p.zxy)) * inc;
    return p;
}

vec3 twist(vec3 p, float k){
  float c = cos(k*p.z);
  float s = sin(k*p.z);
  mat2  m = mat2(c,-s,
  			    s,c);
  return vec3(m*p.xy,p.z);
}

vec3 rotation(vec3 point, vec3 axis, float angle){
    axis = normalize(axis);
    float s = sin(angle);
    float c = cos(angle);
    float oc = 1.0 - c;
    
    mat4 rot= mat4(oc * axis.x * axis.x + c, oc * axis.x * axis.y - axis.z * s,  oc * axis.z * axis.x + axis.y * s,  0.0,
                oc * axis.x * axis.y + axis.z * s,  oc * axis.y * axis.y + c,oc * axis.y * axis.z - axis.x * s,  0.0,
                oc * axis.z * axis.x - axis.y * s,  oc * axis.y * axis.z + axis.x * s,  oc * axis.z * axis.z + c,           0.0,
                0.0,0.0,0.0,1.0);
    return (rot*vec4(point,1.)).xyz;
}

float luma(vec3 color) {
  return dot(color, vec3(0.299, 0.587, 0.114));
}


/*MARCHING SCENE: Where all the shape computation are made*/
vec2 getDist(vec3 p){
  vec3 op = p;
  vec2 uv = topDownUvProjection(p, 0.0025, vec2(200));
  float displacement = texture2D(displacementMap, uv).r * 0.25;

  float boxRadius = 250.0;
  float npy = (p.y / boxRadius) * 0.5 + 0.5;
  npy = clamp(npy, 0.0, 1.0);
  float maxScale = 100.0;

  //test
  float prevNoise = luma(texture2D(startRamp, vec2(0.5, npy)).rgb);
  float nextNoise = luma(texture2D(endRamp, vec2(0.5, npy)).rgb);


  float noiseShapeScale = mix( luma(texture2D(startRamp, vec2(0.5, npy)).rgb),
                               luma(texture2D(endRamp, vec2(0.5, npy)).rgb), easing) * 0.25 + 0.25;
  p.y = p.y + mix(prevNoise, nextNoise, easing) * noiseShapeScale * maxScale;

  //shapes 
  float rndSizeSphere       = (mix(random(startTime + 20), random(endTime + 20), easing) * 0.25 + 0.75) * boxRadius * 0.85;
  float rndPosSphere        = (mix(random(startTime + 30), random(endTime + 30), easing) * 2.0 - 1.0) * boxRadius * 0.25;
  float rndSizeTop          = (mix(random(startTime + 40), random(endTime + 40), easing) * 0.5 + 0.5) * boxRadius * 0.35;
  float rndSizeBaseTop      = (mix(random(startTime + 50), random(endTime + 50), easing) * 0.75 + 0.25) * boxRadius * 0.25;
  float rndSizeBaseBottom   = (mix(random(startTime + 60), random(endTime + 60), easing) * 0.25 + 0.25) * boxRadius * .5;
  float rndSmooth           = (mix(random(startTime + 70), random(endTime + 70), easing) * 0.75);

  vec2 body           = sdSphere(p + vec3(0, rndPosSphere, 0), rndSizeSphere, 0.0);
  vec2 top            = sdCylinder(p, vec3(0.00, -boxRadius, 0.), vec3(0.0, 0, 0), rndSizeTop, 0.0);
  vec2 innerToExtrude = sdCylinder(p, vec3(0.00, -boxRadius * 1.5, 0.), vec3(0.0, 0, 0), rndSizeTop  * 0.75, 0.0);
  vec2 base           = sdCone(p + vec3(0, -boxRadius * 0.35, 0), -boxRadius*0.5, rndSizeBaseTop + rndSizeBaseBottom, rndSizeBaseTop, 0.0);

  vec2 vase = opSmoothUnite(body, base, rndSmooth);
  vase = opSmoothUnite(vase, base, rndSmooth);
  vase = opSmoothUnite(vase, top, rndSmooth);
  vase = opSmoothUnite(vase, top, rndSmooth);
  vase = opSmoothSubstract(innerToExtrude, vase, 0.15);
  vase.x -= displacement;
  vase.x *= 0.5;

  //box
  vec2 box = sdBox(op - vec3(0, boxRadius * 1.15 + boxRadius * 0.35, 0), vec3(boxRadius * 0.55, 200, boxRadius * 0.55), 1.0);

  vec2 scene = opUnite(vase, box);

  return scene;
}

/*MAIN RAYMARCHER FUNCTION*/
vec2 rayMarch(vec3 ro, vec3 rd, inout float index){
  vec2 dO = vec2(0.0); //distance to origin
  for(int i=0; i<MAX_STEPS; i++){
    vec3 p = ro + rd * dO.x; //current marching location on the ray
    vec2 dS = getDist(p) * 0.5; // distance to the scene
    if(dO.x > MAX_DIST || dS.x < SURFACE_DIST){
      index = dS.y;
      break; //hit
    }
    dO.x += dS.x;
    index = dS.y;
  }
  return dO;
}

float rayMarchPerfCheck(vec3 ro, vec3 rd){
  vec2 dO = vec2(0.0); //distance to origin
  for(int i=0; i<MAX_STEPS; i++){
    vec3 p = ro + rd * dO.x; //current marching location on the ray
    vec2 dS = getDist(p); // distance to the scene
    if(dO.x > MAX_DIST || dS.x < SURFACE_DIST){
      return float(i)/float(MAX_STEPS); // return the the step / max which is the number of iteration between 0 (0) and 1 (MAX_STEPS)
    }; //hit
    dO.x += dS.x;
  }
}

/*LIGHTING AND MATERIALS*/
float softShadow(vec3 ro, vec3 rd, float k){
    float res = 1.0;
    float ph = 1e20;
    float dO = 0.0; //distance to origin
    for(int i=0; i<MAX_STEPS_SHADOW; i++){
      vec3 p = ro + rd * dO.x; //current marching location on the ray
      float dS = getDist(p).x; // distance to the scene
      if(dO.x > MAX_DIST_SHADOW || res < SURFACE_DIST) break; //hit

      res = min(res, 10.0 * dS/dO);
      dO += dS;
    }
    return res;//return clamp(res, 0.0, 1.0);
}

float softShadowImproved(vec3 ro, vec3 rd, float mind, float k){
    float res = 1.0;
    float ph = 1e20;
    float dO = mind; //distance to origin
    for(int i=0; i<MAX_STEPS_SHADOW; i++){
      vec3 p = ro + rd * dO; //current marching location on the ray
      float dS = getDist(p).x; // distance to the scene
      float y = dS*dS/(2.0*ph);
      float d = sqrt(dS*dS-y*y);
      res = min(res, k*d/max(0.0,dO-y));
      ph = dS;
      dO += dS;
      if(dO > MAX_DIST_SHADOW || res < SHADOW_SURFACE_DIST) break; //hit
    }
    return res;//clamp(res, 0.0, 1.0);
}

float quilezImprovedShadow(in vec3 ro, in vec3 rd, in int it, in float mint, in float tmax, in float k){
	  float res = 1.0;
    float t = mint;
    float ph = 1e20; // big, such that y = 0 on the first iteration
    for( int i=0; i<it; i++ )
    {
		    float h = getDist( ro + rd*t ).x;
        // use this if you are getting artifact on the first iteration, or unroll the
        // first iteration out of the loop
        // float y = (i==0) ? 0.0 : h*h/(2.0*ph); 
        float y = h*h/(2.0*ph);
        float d = sqrt(h*h-y*y);
        res = min( res, k*d/max(0.0,t-y) );
        ph = h;
        t += h;
        if( res<0.0001 || t>tmax ) break;
    }
    return clamp( res, 0.0, 1.0 );
}

vec3 getNormal(vec3 p, float offset){
  float d = getDist(p).x;// get the distance at point d
  vec2 e =  vec2(offset, 0.0);//define an offset vector
  vec3 n = d - vec3(
    getDist(p - e.xyy).x, //get dist offset on X
    getDist(p - e.yxy).x, //get dist offset en Y
    getDist(p - e.yyx).x // get dist offset on Z
    ); // get the vector next to the point as the normal

  return normalize(n);
}

float ambientOcclusion(vec3 p, vec3 n){
  float occ = 0.0;
  float sca = 1.0;
  #define OCCSTEP 2
  for(int i=0; i<OCCSTEP; i++){
    float h = 0.001 + 0.15 * float(i)/4.0;
    float d = getDist(p + h * n).x;
    occ += (h-d) * sca;
    sca += 0.95;
  }
  occ /= float(OCCSTEP);
  return clamp(1.0 - 1.5 * occ, 0.0, 1.0);
}



/*Triplanar texture projection*/
vec3 triplanarMap(vec3 pos, vec3 normal, sampler2D texture)
{
    // Take projections along 3 axes, sample texture values from each projection, and stack into a matrix
    mat3 triMapSamples = mat3(
        texture2D(texture, pos.yz).rgb,
        texture2D(texture, pos.xz).rgb,
        texture2D(texture, pos.xy).rgb
        );

    // Weight three samples by absolute value of normal components
    return triMapSamples * abs(normal);
}

/*Post-Processing*/
vec3 toLinear(vec3 v) {
  return pow(v, vec3(gamma));
}

vec4 toLinear(vec4 v) {
  return vec4(toLinear(v.rgb), v.a);
}


vec3 toGamma(vec3 v) {
  return pow(v, vec3(1.0 / gamma));
}

vec4 toGamma(vec4 v) {
  return vec4(toGamma(v.rgb), v.a);
}

// IQ
// https://www.shadertoy.com/view/ll2GD3
vec3 palette( in float t, in vec3 a, in vec3 b, in vec3 c, in vec3 d ) {
    return a + b*cos( 6.28318*(c*t+d));
}

vec3 spectrum(float n) {
       return palette(n, vec3(0.5,0.5,0.5),vec3(0.5,0.5,0.5),vec3(1.0,1.0,1.0),vec3(0.0,0.33,0.67) );
     // return palette(n, vec3(0.5,0.5,0.5),vec3(0.5,0.5,0.5),vec3(1.0,1.0,1.0),vec3(0.0,0.10,0.20));
     // return palette(n, vec3(0.5,0.5,0.5),vec3(0.5,0.5,0.5),vec3(1.0,0.7,0.4),vec3(0.0,0.15,0.20));
     // return palette(n, vec3(0.5,0.5,0.5),vec3(0.5,0.5,0.5),vec3(2.0,1.0,0.0),vec3(0.5,0.20,0.25));
}


/*RENDER SCENE: Where all material computation are done*/
vec4 render(vec3 ro, vec3 rd, Time time){
  vec3 col = vec3(0.0);
  // vec3 bg = texture2D(colorramp, vec2(1.0, 0.5)).rgb;
  vec3 bg = vec3(38, 37, 35) / 255.0;
  bg *= 0.1;

  //float p = rayMarchPerfCheck(ro, rd);
  //vec3 perf = mix(vec3(0,0,1), vec3(1, 0, 0), p);

  float index;
  vec2 d = rayMarch(ro, rd, index);
  float depth = 0.0;

  float near = 500.0;
  float far = 1000.0;
  if(d.x > 0.0){
    // depth = d.x/(far - near);//compute depthmap (useful for debug only
    vec3 pos = ro + rd * d.x;
    vec3 nor = getNormal(pos, 0.1);
    vec3 eye = normalize(ro);
    vec3 view = normalize(-rd);

    


    //texturing
    float isVase = 1.0 - step(0.5, index);
    vec2 uv = topDownUvProjection(pos, 0.0015, vec2(400));
    // uv = triplanarMap(pos, nor, )

    vec3 normalMapping    = mix(nor, perturb_normal(nor, normalize(view), uv, normalMap), 0.25);
    vec3 albedoMapping    = texture2D(albedoMap, uv).xyz;
    vec3 specularMapping  = texture2D(specularMap, uv).xyz;
    nor = normalMapping * isVase + nor * (1.0 - isVase);

    
    //material;
    vec3 mat = albedoMapping * isVase +  (vec3(111, 108, 104) / 255.0) * (1.0 - isVase);
    specularMapping = specularMapping * isVase + vec3(1.0) * (1.0 - isVase);;

    //lighting
    vec3 specColor;
    vec3 lightColor;
    vec3 lightsPos[4] = vec3[4](
    	vec3(cos(PI * 0.95), -0.8, sin(PI * 0.95)),
    	vec3(cos(PI * 0.05), -0.8, sin(PI * 0.05)),
    	vec3(cos(TWOPI * 0.9) * 1.0, -1, sin(TWOPI * 0.9) * 1.0),
    	vec3(cos(-PI * 0.7), 0, sin(-PI * 0.7))
    	);
    vec3 lightsColors[4] = vec3[4](
    	vec3(0.302, 0.3686, 1.0) * 0.15,
    	vec3(1.0, 0.9137, 0.6235) * 0.1,
    	vec3(1.0, 0.9529, 0.7922) * 1.00,
    	vec3(0.9373, 0.9804, 0.9882) * 1.0
    	);
    
    for(int i=0; i<lightsPos.length; i++){
      vec3 lp = lightsPos[i];

      float intensity = clamp(dot(nor, lp), 0.0, 1.0);
      float diffM =  clamp(dot(nor, lp), 0.0, 1.0) 
                    * softShadowImproved(pos, lp, 10, 100.0 );
                  //softShadow(pos, lig, 25.0);
                  // quilezImprovedShadow(pos, lig, 64, 10, 2000.0, 100.0);


      //specularity
      vec3 hal = normalize(lp - rd);
      float NdotHL = clamp(dot(nor, hal), 0., 1.);
      float HLdotRD = clamp(1.0+dot(hal, rd),0.0,1.0);
      float specPower = 25.0 * isVase + 1.0 * (1.0 - isVase);
      float gloss = 800.0 * isVase + 1.0 * (1.0 - isVase);
      float specMask = pow(specularMapping.r, 2.5);
      float specM = (pow(NdotHL, specPower) * gloss * diffM * (0.04 + .96*pow(HLdotRD, 5.0))) * specMask;

      specColor += lightsColors[i] * specM;
      lightColor += lightsColors[i] * diffM;
    }
    lightColor /= float(lightsColors.length);
    specColor /= float(lightsColors.length);

    // vec3 lig = normalize(lightPos);
    // float intensity = clamp(dot(nor, lig), 0.0, 1.0);
    // float diff =  clamp(dot(nor, lig), 0.0, 1.0) 
    //               * softShadowImproved(pos, lig, 10, 100.0 );
    //             //softShadow(pos, lig, 25.0);
    //             // quilezImprovedShadow(pos, lig, 64, 10, 2000.0, 100.0);


    //specularity
    // vec3 hal = normalize(lig - rd);
    // float NdotHL = clamp(dot(nor, hal), 0., 1.);
    // float HLdotRD = clamp(1.0+dot(hal, rd),0.0,1.0);
    // float specPower = 50.0 * isVase + 1.0 * (1.0 - isVase);
    // float gloss = 250.0 * isVase + 1.0 * (1.0 - isVase);
    // float specMask = pow(specularMapping.r, 2.5);
    // float specular = (pow(NdotHL, specPower) * gloss * diff * (0.04 + .96*pow(HLdotRD, 5.0))) * specMask;
    //OLD
    // float speItensity =  100.0;
    // float speDiff = 100.0;
    // float specular = pow(NdotHL, speDiff) *
    //                 diff * (0.04 + .96*pow(HLdotRD, 5.0));
      
    //rim light
    float rimPower = 0.015;
    float rim = 1.0 - max(dot(view, nor), 0.0);
    rim = smoothstep(0.65, 1.0, rim);
	
    //material definition
    // col += mat * diff * lightColor + specular;//Lambert estimation + BlinnPhong
    col += mat * lightColor + specColor;//Lambert estimation + BlinnPhong
    col += rim * rimPower;// * specMask;//rim light

    //ambient + occlusion
    float occ = ambientOcclusion(pos, nor);
    float amb = clamp(0.5 + 0.5 * nor.y, 0.0, 1.0);
    col += mat * amb * 0.01;
    col *= mat * occ;

    //fog exp
    // col *= exp(-0.0005 * pow(d, 2.5));
    //fog of war
    float fog = (d.x - near) / (far - near);
    fog = clamp(fog, 0., 1.0);

    col = mix(col, bg, fog);


    depth            = d.x;
    float ndofLength = (1.0 - length(ro - vec3(0, 0, 0.0)) / depth);
    ndofLength       = clamp(ndofLength,  0.005, 1.0);
    float coc        =  2.0 * ndofLength;
    depth            =  max(0.01, min(0.35, coc));
  }
  // col.rgb = vec3(d.x / FAR);
  col = clamp(col, vec3(0.0), vec3(1.0));
  return vec4(col, depth);
}

/*MAIN FUNCTION*/
void main(){
  //define time
  Time stime = computeTime(time, 15.0);

  //define uv and aspect ratio
  float aspectRatio = resolution.x / resolution.y;
  vec2 uv = -1.0 + 2.0 * gl_FragCoord.xy / resolution.xy;
  uv.x *= aspectRatio;
  
  //define camera
  vec3 ro, rd;
  //x
  // ro =  vec3(cos(stime.normTime * TWOPI) * FAR * 0.65,
  // 			0,
  // 			sin(stime.normTime * TWOPI) * FAR * 0.65);
  // ro =  vec3(0,
  // 			cos(0.34 * TWOPI) * FAR * 0.65,
  // 			sin(0.34 * TWOPI) * FAR * 0.65);
  ro = vec3(sin(time * 0.15) * 0.15 * FAR, 
            sin(time * 0.15) * 0.25 * PI * 500, 
            FAR * .65);// (mouse.x * 0.5 + 0.5));

  float hyp = sqrt(resolution.x * resolution.x + resolution.y * resolution.y) * 0.5;
  rd = R(uv, ro, vec3(0.0), vec3(0, -1, 0), PI * 0.5);

  // render	
  vec4 color = render(ro, rd, stime);

  // gamma
  color.rgb = toGamma(color.rgb * 1.0);
  // color.rgb = pow(color.rgb, vec3(0.4545 * mouse.x * 2.0));
  fragColor = color;
}