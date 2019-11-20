#ifdef GL_ES
precision mediump float;
precision mediump int;
#endif

//Defines raymarcher constants
#define PI 3.1415926535897932384626433832795
#define TWO_PI (PI * 2.0)

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
#define OCTAVE 6
#define FAR 1000.0
#define MAX_STEPS 32 * 2 //max iteration on the marching loop
#define MAX_STEPS_SHADOW 32 * 4 //max iteration on the marching loop for shadow
#define MAX_DIST FAR * 1.15 //maximum distance from camera //based on near and far
#define SHADOW_DIST_DIV 1.5
#define MAX_DIST_SHADOW (FAR * SHADOW_DIST_DIV)  //based on near and far
#define SURFACE_DIST 0.1 // minimum distance for a Hit
#define SHADOW_SURFACE_DIST 0.0001
//old params
// #define MAX_STEPS 64 * 3 //max iteration on the marching loop
// #define MAX_STEPS_SHADOW MAX_STEPS //max iteration on the marching loop for shadow
// #define MAX_DIST 5000. //maximum distance from camera
// #define MAX_DIST_SHADOW MAX_DIST
// #define SURFACE_DIST 0.1 // minimum distance for a Hit

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

/*Camera computation*/
vec3 R(vec2 uv, vec3 p, vec3 o, float z) { //this function return the ray direction from a non aligned axis camera
    vec3 f = normalize(o-p),
        r = normalize(cross(vec3(0,-1,0), f)),
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
  float c = cos(k*p.y);
  float s = sin(k*p.y);
  mat2  m = mat2(c,-s,s,c);
  return vec3(m*p.xz,p.y);
}


/*MARCHING SCENE: Where all the shape computation are made*/
vec2 getDist(vec3 p){

  vec2 box = sdBox(p, vec3(75, 200, 75.0), 0.0);
  vec2 sphere= sdSphere(p, 150, 0.0);

  return opUnite(box, sphere);
}

/*MAIN RAYMARCHER FUNCTION*/
vec2 rayMarch(vec3 ro, vec3 rd, inout float index){
  vec2 dO = vec2(0.0); //distance to origin
  for(int i=0; i<MAX_STEPS; i++){
    vec3 p = ro + rd * dO.x; //current marching location on the ray
    vec2 dS = getDist(p); // distance to the scene
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


vec3 SubsurfaceTrace( vec3 ro, vec3 rd )
{
	vec3 density = pow(vec3(.7,.5,.4),vec3(.4));
	const float confidence = .01;
	vec3 visibility = vec3(1.0);
	
	float lastVal = getDist(ro).x;
	float soft = 0.0;
	for ( int i=1; i < 50; i++ )
	{
		if ( visibility.x < confidence )
			continue;
		
		float val = getDist(ro).x;

		vec3 softened = pow(density,vec3(smoothstep(soft,-soft,val)));
//tweak this to create soft shadows, by expanding with each step (linearly)
		
		if ( (val-soft)*lastVal < 0.0 )
		{
			// approximate position of the surface
			float transition = -min(val-soft,lastVal)/abs(val-soft-lastVal);
			visibility *= pow(softened,vec3(transition));
		}
		else if ( val-soft < 0.0 )
		{
			visibility *= softened;
		}

		soft += .1;
		lastVal = val+soft;
		ro += rd*.4;
	}
	
	return visibility;
}

float RayMarchOut(vec3 ro, vec3 rd) 
{
	float dO=0.;
    
    for(float i=0.0; i<1.0; i+=0.05) 
	{
    	vec3 p = ro + rd*i;
        float dS = getDist(p).x;
		dO += 0.05 * step(dS, 0.0);
    }
	return exp(-dO*1.1);
}

float subsurface(vec3 p, vec3 v, vec3 n){
    //vec3 d = normalize(mix(v, -n, 0.5));
    // suggested by Shane
    vec3 d = refract(v, n, 1.0/1.5);
    vec3 o = p;
    float a = 0.0;
    
    const float max_scatter = 2.5;
    for(float i = 0.1; i < max_scatter; i += 0.2)
    {
        o += i*d;
        float t = getDist(o).x;
        a += t;
    }
    float thickness = max(0.0, -a);
    const float scatter_strength = 16.0;
	return scatter_strength*pow(max_scatter*0.5, 3.0)/thickness;
}


/*RENDER SCENE: Where all material computation are done*/
vec4 render(vec3 ro, vec3 rd, Time time){
  vec3 col = vec3(0.0);
  // vec3 bg = texture2D(colorramp, vec2(1.0, 0.5)).rgb;
  vec3 bg = vec3(216, 249, 251) / 255.0;

  //float p = rayMarchPerfCheck(ro, rd);
  //vec3 perf = mix(vec3(0,0,1), vec3(1, 0, 0), p);

  float index;
  vec2 d = rayMarch(ro, rd, index);
  //index ++;
  //index /= 2.0;
  float depth = 0.0;

  float near = 600.0;
  float far = 1000.0;
  if(d.x > 0.0){
    // depth = d.x/(far - near);//compute depthmap (useful for debug only
    vec3 pos = ro + rd * d.x;
    vec3 nor = getNormal(pos, 0.25);
    vec3 eye = normalize(ro);
    vec3 view = normalize(-rd);

    //keyLight
    vec3 lightColor = vec3(0, 0, 255) / 255.;//vec3(1.0, 0.9843, 0.949);
    float eta   = PI * time.normTime;
    float theta = TWO_PI * time.normTime;
    float radius = length(rd - ro);
    vec3 lightPos = vec3(cos(theta) * radius,
    				0.0,
    				sin(theta) * radius);

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



 //    float sss = 0.0;
 //    float density = 0.5;
 //    float ss_offset = 0.1;
 //    float ss_intensity = 0.1;
 //    vec3 ssColor = vec3(0, 0, 1.0);

 //    //     //subsurface_scattering
 //    float s = subsurface_scattering(ro, rd, lig, nor);
	// s = pow(exp(ss_offset -s * density), 1.0);
	// sss += s * ss_intensity;
	// vec3 sscol = s * ssColor * ss_intensity;	
	// ssColor += mix(sscol, ssColor, 0.5);

    //material
  
    vec3 mat = vec3(200.0) / 255.0;

    // if(d.y == 3.0){
    //   mat = vec3(0, 0, 255)/255.0;
    // }

    //specularity
    float NdotHL = clamp(dot(nor, hal), 0., 1.);
    float HLdotRD = clamp(1.0+dot(hal, rd),0.0,1.0);
    float speItensity = 20.0;
    float speDiff = 5.0;
    float specular = pow(NdotHL, speDiff) *
                    diff * (0.04 + .96*pow(HLdotRD, 5.0));

    vec3 SScol = vec3(0.8, 0.4, 0.4);
    float ss = RayMarchOut(ro+rd*(SURFACE_DIST * 4.0 +noise(pos * 100.0) * 4.0), lig);
    float density = 0.25 * 10.0;
    float intensity = 0.25;
    ss = ss * 0.05 + pow((d.x / FAR) * 2, density);
    // float ss = max(0.0, subsurface(pos, lig, nor));

    //iridescence from : https://www.shadertoy.com/view/llcXWM

    //material definition
    // col += mat * (diff * 0.5 + 0.5) * SScol * ss * lightColor;
    // col += speItensity * specular * SScol;
    // col *= 0.5;;
    col += (SScol * ss) * intensity + mat * (diff * 0.75 + 0.25) * lightColor;
    col += speItensity * specular + (SScol * ss) * intensity;

    //ambient + occlusion
    float occ = ambientOcclusion(pos, nor);
    float amb = clamp(0.5 + 0.5 * nor.y, 0.0, 1.0);
    col += mat * amb * 0.005;
    col *= mat * occ;

    //fog exp
    // col *= exp(-0.0005 * pow(d, 2.5));
    //fog of war
    float fog = (d.x - near) / (far - near);
    fog = clamp(fog, 0., 1.0);
    col = mix(col, bg, fog);

    depth            = d.x;
    float ndofLength = (1.0 - length(ro - vec3(0, 0, 0.0)) / depth);
    ndofLength       = clamp(ndofLength, 0.025, 1.0);
    float coc        =  0.0 * ndofLength;
    depth            =  max(0.01, min(0.35, coc));
  }

  col = clamp(col, vec3(0.0), vec3(1.0));
  return vec4(col, depth);
}

/*MAIN FUNCTION*/
void main(){
  //define time
  Time stime = computeTime(time, 6.0);

  //define uv and aspect ratio
  float aspectRatio = resolution.x / resolution.y;
  vec2 uv = -1.0 + 2.0 * gl_FragCoord.xy / resolution.xy;
  uv.x *= aspectRatio;
  
  //define camera
  vec3 ro, rd;
  ro = vec3(cos(stime.time * 0.0 * TWO_PI) * FAR * 0.5,
  			0,
  			sin(stime.time * 0.0 * TWO_PI) * FAR * 0.5);

  float hyp = sqrt(resolution.x * resolution.x + resolution.y * resolution.y) * 0.5;
  rd = R(uv, ro, vec3(0.0), PI * 0.5);

  // render	
  vec4 color = render(ro, rd, stime);
  // gamma
  color.rgb = toGamma(color.rgb);
  // color = pow(color, vec3(0.4545));
  fragColor = color;
}