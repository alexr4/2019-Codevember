#ifdef GL_ES
precision highp float;
precision highp int;
#endif

//Defines raymarcher constants
#define PI 3.1415926535897932384626433832795
#define TWO_PI (PI * 2.0)
#define TWOPI TWO_PI

//Defines GPGPU constants
const vec4 efactor = vec4(1.0, 255.0, 65025.0, 16581375.0);
const vec4 dfactor = vec4(1.0/1.0, 1.0/255.0, 1.0/65025.0, 1.0/16581375.0);
const float mask = 1.0/256.0;

//defines bound informations from p5
uniform vec2 resolution;
uniform vec2 mouse;
uniform float time;
uniform sampler2D ramp;

in vec4 vertTexCoord;
in vec4 color;
out vec4 fragColor;

//Post Process
const float gamma = 2.2;

//RAYMARCHIN CONSTANT
#define OCTAVE 8
#define FAR 1000.0
#define MAX_STEPS 32 * 5 //max iteration on the marching loop
#define MAX_STEPS_SHADOW 32 //max iteration on the marching loop for shadow
#define MAX_DIST FAR * 1.5 //maximum distance from camera //based on near and far
#define SHADOW_DIST_DIV 1.5
#define MAX_DIST_SHADOW (FAR * SHADOW_DIST_DIV)  //based on near and far
#define SURFACE_DIST 0.1 // minimum distance for a Hit
#define SHADOW_SURFACE_DIST 0.001
//old params
// #define MAX_STEPS 64 * 3 //max iteration on the marching loop
// #define MAX_STEPS_SHADOW MAX_STEPS //max iteration on the marching loop for shadow
// #define MAX_DIST 5000. //maximum distance from camera
// #define MAX_DIST_SHADOW MAX_DIST
// #define SURFACE_DIST 0.1 // minimum distance for a Hit

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


/* retreive uv from index helper + GPGPU */
vec3 getUVN(int index, vec2 dataResolution, int maxData){
    float ni = float(index) / float(maxData);
    
		//find uv
		float x = floor(mod(index, dataResolution.x));
		float y = floor((index - x) / dataResolution.x);
		vec2 uv = vec2(x, y) / (dataResolution- vec2(1.0));
    // uv.y *= aspectRatio;
    // uv.y = 1.0 - uv.y;
    return vec3(uv, ni);
}

float decodeRGBA32(vec4 rgba){
	return dot(rgba, dfactor.rgba);
}

float decodeRGBA24(vec3 rgb){
	return dot(rgb, dfactor.rgb);
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

/*Camera computation*/
vec3 R(vec2 uv, vec3 p, vec3 o, float z) { //this function return the ray direction from a non aligned axis camera
    vec3 f = normalize(o-p),
        r = normalize(cross(vec3(0.75,-1,0), f)),
        u = cross(f,r),
        c = p+f*z,
        i = c + uv.x*r + uv.y*u,
        d = normalize(i-p);
    return d;
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


/*MARCHING SCENE: Where all the shape computation are made*/
vec2 getDist(vec3 p){
  
  vec2 uv = gl_FragCoord.xy /resolution;

  vec2 planeDist = vec2(p.z, 0.0); //get the distance from the ground
  vec2 box = sdBox(p, vec3(75, 200, 75.0), 0.0);
  vec2 box2 = sdBox(p, vec3(75, 200, 75.0) * 0.9, 0.0);
  vec2 sph = sdSphere(p, 200, 0.0);
  vec2 sph2 = sdSphere(p, 200 * 0.9, 0.0);

  VoroStruct voronoi = voronoiDistance((p.xy + vec2(p.z+p.x * 0.1, p.z+p.y * 0.1) * 1.0) * 0.001 + vec2(0, time * 0.025), vec2(8), 10, 0.25, 0.55);
  // float fbm = fbm(p + vec3(0, -time * 25, 0), 0.045, 0.0045, 3.5, 0.27);
  // float test = smoothstep(0.005, .25, fbm);
  float rnd =  random(voronoi.indices);
  float dist = voronoi.dist.y;
  float offset = rnd * 75.0 * dist;//clamp(voronoi.dist.y, 0.0, 1.0);
  float orientation = step(rnd, 0.85) * 2.0 - 1.0;
  planeDist.x = (box.x + offset * orientation);


  int starti = 1;
  vec2 depth = opSubstract(box2, planeDist);
  depth.y =  round(random(voronoi.indices) * 10);
  // depth.x *= 0.5;
  // Time t = computeTime(time, 6.0);
  // float modTime = mod(time, 6.0);
// 
  return depth;
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
  vec3 bg = vec3(255, 254, 255) / 255.0;

  //float p = rayMarchPerfCheck(ro, rd);
  //vec3 perf = mix(vec3(0,0,1), vec3(1, 0, 0), p);

  float index;
  vec2 d = rayMarch(ro, rd, index);
  //index ++;
  //index /= 2.0;
  float depth = 0.0;

  float near = 500.0;
  float far = 1000.0;
  if(d.x > 0.0){
    // depth = d.x/(far - near);//compute depthmap (useful for debug only
    vec3 pos = ro + rd * d.x;
    vec3 nor = getNormal(pos, 0.5);
    vec3 eye = normalize(ro);
    vec3 view = normalize(-rd);

    //keyLight
    vec3 lightColor = vec3(255, 254, 255) / 255.;//vec3(1.0, 0.9843, 0.949);
    // lightColor *= 0.65;
    float eta   = PI * mouse.x;//0.22;
    float theta = TWO_PI * mouse.y;
    float radius = length(rd - ro);
    vec3 lightPos = vec3(sin(eta) * cos(theta) * radius, 
                         sin(eta) * sin(theta) * radius, 
                         cos(theta) * radius);

    lightPos = ro + vec3(50.0, 5.0, 0);

    // float lightRadius = (far - near) * 0.5;
    // float lightSpeed = 0.0001;
    // float pingpongTime = abs(fract(time.time * lightSpeed) * 2.0 - 1.0);
    // theta = mix(PI * 1.95, PI * 1.05, pingpongTime);
    // //lightPos.xz = vec2(cos(theta) * lightRadius, sin(theta) * lightRadius);

    //lighting
    vec3 lig = normalize(lightPos);
    vec3 hal = normalize(lig - rd);
    float diff = clamp(dot(nor, lig), 0.0, 1.0) *
                 softShadowImproved(pos, lig, 10, 100.0);
                //softShadow(pos, lig, 25.0);
                // quilezImprovedShadow(pos, lig, 64, 10, 2000.0, 100.0);

    //material
    vec3 mat = vec3(242, 236, 235) / 255.0;
    mat = vec3(random(index),
    			random(index + 10),
    			random(index + 20));
    mat = nor * random(index);
   

    //specularity
    float NdotHL = clamp(dot(nor, hal), 0., 1.);
    float HLdotRD = clamp(1.0+dot(hal, rd),0.0,1.0);
    float speItensity =  100;
    float speDiff = 25.5;
    float specular = pow(NdotHL, speDiff) *
                    diff * (0.04 + .96*pow(HLdotRD, 5.0));


    // vec3 perturb = pos;
      
    //rim light
    float rimPower = 0.25;
    float rim = 1.0 - max(dot(view, nor), 0.0);
    rim = smoothstep(0.65, 0.9, rim);
	// diff += 0.5;
    //material definition
    col += mat * diff * lightColor + rim * rimPower;
    col += mat * diff * speItensity * specular * lightColor;

    //ambient + occlusion
    float occ = ambientOcclusion(pos, nor);
    float amb = clamp(0.5 + 0.5 * nor.y, 0.0, 1.0);
    col += mat * amb * 0.25;
    // col *= mat * occ * 0.1;

    //fog exp
    // col *= exp(-0.0005 * pow(d, 2.5));
    //fog of war
    float fog = (d.x - near) / (far - near);
    fog = clamp(fog, 0., 1.0);
    col = mix(col, bg, fog);

    depth            = d.x;
    float ndofLength = (1.0 - length(ro - vec3(0, 0, 0.0)) / depth);
    ndofLength       = clamp(ndofLength, 0.001, 1.0);
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
  ro =  vec3(cos(stime.normTime * TWO_PI) * FAR * 0.25,
  			0,
  			sin(stime.normTime * TWO_PI) * FAR * 0.25);
  			 // ro = vec3(0, 0, FAR * 0.5);

  float hyp = sqrt(resolution.x * resolution.x + resolution.y * resolution.y) * 0.5;
  rd = R(uv, ro, vec3(0.0), PI * 0.5);

  // render	
  vec4 color = render(ro, rd, stime);
  // gamma
  // color.rgb = toGamma(color.rgb);
  color.rgb = pow(color.rgb, vec3(0.4545 * 1.15));
  fragColor = color;
}