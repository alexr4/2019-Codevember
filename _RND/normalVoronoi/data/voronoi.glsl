#ifdef GL_ES
precision mediump float;
#endif

//pre-processor macro defining the key word PI as 3.14159265359 will compiled
#define PI 3.1415926535897932384626433832795
#define TWOPI (PI*2.0)

uniform float u_time;
uniform vec2 u_resolution;
uniform vec2 u_mouse;
uniform float orientation;
uniform float normTime;

struct VoroStruct{
  vec2 dist;
  vec2 indices;
};

struct Time{
  float time;
  float modTime;
  float normTime;
  float timeLoop;
  float maxTime;
};

Time computeTime(float maxTime){
  float modTime = floor(mod(u_time, maxTime));
  float normTime = mod(u_time, maxTime) / maxTime;
  float timeLoop = floor(u_time / maxTime);
  Time time = Time(
    u_time,
    modTime,
    normTime,
    timeLoop,
    maxTime
    );
  return time;
}


mat2 rotate2d(float angle){
  return mat2(cos(angle), -sin(angle),
              sin(angle),  cos(angle));
}

vec2 rotate(vec2 st, float angle){
  //move to center
  st -= vec2(0.5);
  //rotate
  st = rotate2d(angle) * st;
  //reset position
  st += vec2(0.5);
  return st;
}

float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(10.9898,78.233)))*43758.5453123);
}

vec2 random2D( vec2 p ) {
    return fract(sin(vec2(dot(p,vec2(127.1,311.7)),dot(p,vec2(269.5,183.3))))*43758.5453);
}

float linear(float fmin, float fmax, float foffset){
  return mix(fmin, fmax, foffset);
}

//noise from Morgan McGuire
//https://www.shadertoy.com/view/4dS3Wd
float noise(vec2 st){
  vec2 ist = floor(st);
  vec2 fst = fract(st);

  //get 4 corners of the pixel
  float bl = random(ist);
  float br = random(ist + vec2(1.0, 0.0));
  float tl = random(ist + vec2(0.0, 1.0));
  float tr = random(ist + vec2(1.0, 1.0));

  //smooth interpolation using cubic function
  vec2 si = fst * fst * (3.0 - 2.0 * fst);

  //mix the four corner to get a noise value
  return mix(bl, br, si.x) +
         (tl - bl) * si.y * (1.0 - si.x) +
         (tr - br) * si.x * si.y;
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



//to be replace by DCusrom function
float getBorder(VoroStruct voronoi, float minSize, float maxSize, float minThickness, float maxThickness, float minSmoothness, float maxSmoothness)
{
    float offset = random(voronoi.indices);
    float stepper = 1.0 - step(0.5, offset);
    float dist = voronoi.dist.x;

    float size = mix(minSize, maxSize, offset);
    float thickness = mix(minThickness, maxThickness, offset);
    float smoothness = mix(minSmoothness, maxSmoothness, offset);

    //to be replace by Data
    return smoothstep(size - thickness - smoothness, size - thickness, dist);
    // - (1.0 - smoothstep(size + thickness * 5.5 + smoothness, size + thickness * 5.5 , dist));
}


void main(){
  //compute the normalize screen coordinate
  vec2 st = gl_FragCoord.xy/u_resolution.xy;

  vec2 nst = st;
  nst = rotate(st, PI*.25);

  // Time time = computeTime(4.0);
  // float modLoop = mod(time.timeLoop, 2.0);
  float stepOriention = 1.0 - step(.5, orientation);
  float nx = u_mouse.x/u_resolution.x;
  float nt = normTime *1.5;
  float distToCenter = length(nst * 2. - 1.);
  float normDistToCenter = ((nt-distToCenter)/sqrt(2.0)) * 6.0;


  float offset = smoothstep(0.0, 1., normDistToCenter) * stepOriention + (1.0 - smoothstep(0.0, 1.0, normDistToCenter)) * (1.- stepOriention);
  //float offset = smoothstep(0.0, 0.01, normDistToCenter) * (1.0 - smoothstep(0.99, 1.0, normDistToCenter));


  float minSize = mix(1.5, 0.25, offset);
  float maxSize = mix(1.5, 0.55, offset);

  vec2 colsrows = vec2(6);
  VoroStruct voronoi = voronoiDistance(st + vec2(0, u_time * .0), colsrows, u_time, minSize, maxSize);
  vec2 index = voronoi.indices;

  float border = getBorder(voronoi, 0.035, 0.075, 0.001, 0.01, 0.01, 0.015);


  vec3 color = vec3(border);

  gl_FragColor = vec4(color, 1);
}
