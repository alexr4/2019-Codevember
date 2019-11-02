uniform vec2 resolution;
uniform float offset = 43758.5453123;
uniform float scale = 1.0;
uniform vec3 time;
uniform int cols = 5;
uniform int rows = 5;
uniform int octave = 8;
uniform float amplitude = 0.5;
uniform	float frequency = 0.25;
uniform	float lacunarity = 2.0;
uniform	float gain = 0.5;
uniform float eta = 0.0;
uniform float gamma = 0.0;
uniform float dwInc = 25;

in vec4 vertTexCoord;
out vec4 fragColor;

float random(float value){
	return fract(sin(value) * offset);
}

float random(vec2 tex){
	//return fract(sin(x) * offset);
	return fract(sin(dot(tex.xy, vec2(12.9898, 78.233))) * offset);//43758.5453123);
}

float random(vec3 tex){
	//return fract(sin(x) * offset);
	return fract(sin(dot(tex.xyz, vec3(12.9898, 78.233, 12.9898))) * offset);//43758.5453123);
}

vec2 random2D(vec2 uv){
	uv = vec2(dot(uv, vec2(127.1, 311.7)), dot(uv, vec2(269.5, 183.3)));
	return -1.0 + 2.0 * fract(sin(uv) * offset);
}

vec3 random3D(vec3 uv){
	uv = vec3(dot(uv, vec3(127.1, 311.7, 120.9898)), dot(uv, vec3(269.5, 183.3, 150.457)), dot(uv, vec3(380.5, 182.3, 170.457)));
	return -1.0 + 2.0 * fract(sin(uv) * offset);
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
		mix(dotAA_, dotBB_,	suv.x),
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
		mix(dotAA_, dotBB_,	suv.x),
		mix(dotCC_, dotDD_, suv.x),
		suv.y);

	float passH1 = mix(
		mix(dotEE_, dotFF_,	suv.x),
		mix(dotGG_, dotHH_, suv.x),
		suv.y);
	
	return mix(passH0, passH1, suv.z);
}

float fbm(vec2 st, float amp, float freq, float lac, float gain){
	return fbm(st.xy, amp, freq, lac, gain);
}

float fbm(vec3 st, float amp, float freq, float lac, float gain){
	//initial value
	float fbm = 0.0;

	//float rmx = sin(eta);
	//float rmy = cos(eta);
	//float px = 0.0;

	vec3 shift = vec3(1.0);
	mat2 rot2 = mat2(cos(-eta), sin(eta), -sin(eta), cos(eta));
	mat3 rot3 = mat3(sin(-gamma) * cos(-eta), cos(gamma) * sin(eta), sin(gamma),
		sin(gamma) * -sin(eta), sin(-gamma) * cos(eta), sin(gamma),
		sin(gamma) * cos(eta), cos(gamma) * sin(eta), sin(gamma)
		);

	for(int i = 0; i < octave; i++){
		//px = st.x;
		//st.x = st.x * rmx + st.y * rmy;
		//st.y = px * rmy + st.y * rmx;

		fbm += amp * noise(st * freq);
		st = rot3 * st * 1.5 + shift;
		freq *= lac;
		amp *= gain;
	}

	return fbm;
}

float domainWarping(vec3 st, float inc1, float inc2, float amp, float freq, float lac, float gain){
	float tmp = fbm(st, amp, freq, lac, gain);
	tmp += fbm(st + tmp * inc1, amp, freq, lac, gain);
	tmp += fbm(st + tmp * inc2, amp, freq, lac, gain);

	return tmp;
}

void main(){
	vec2 uv = gl_FragCoord.xy / resolution.xy;
	vec3 pos = vec3(uv.x * cols, uv.y * rows, 1.0 * scale);
	float amp = amplitude;
	float freq = frequency;
	float lac = lacunarity;
	float g = gain;
	float dwi = dwInc;

	float nc  = noise(pos + time);
	float fractal = fbm(pos + time, amp, freq, lac, g); 
	float dw = domainWarping(pos + time, dwi, dwi * -1, amp, freq, lac, g);
	vec3 c = vec3(dw * 0.5 + 0.5);

	vec3 albedo = pow(c.xyz, vec3(1.0));
	albedo += time.z;
	albedo = mix(albedo, vec3(1.0), time);

	fragColor = vec4(albedo, 1.0); 
}