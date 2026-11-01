shader_type canvas_item;
render_mode unshaded;

uniform sampler2D seabed : source_color, filter_nearest, repeat_disable;
uniform sampler2D bathymetry : filter_nearest, repeat_disable;
uniform vec2 resolution = vec2(480.0, 320.0);
uniform float clock = 0.0;
uniform float water_level = 0.0;
uniform float clarity = 0.65;
uniform float strength = 1.0;
uniform float night = 0.0;
uniform bool basin_scene = false;
uniform bool environment_enabled = true;
uniform bool waterfall_enabled = true;
uniform bool depth_enabled = true;
uniform bool refraction_enabled = true;
uniform bool caustics_enabled = true;
uniform bool foam_enabled = true;
uniform bool ripples_enabled = true;
uniform bool debug_depth = false;
uniform float ripple_offsets[16];
uniform vec4 ripples[16]; // x, y, birth time, amplitude; world-pixel coordinates

vec2 turn(vec2 p,float angle) {
 if(angle==0.) { return p; }
 float a=radians(angle);
 return mat2(vec2(cos(a),sin(a)),vec2(-sin(a),cos(a)))*p;
}

uniform float water_mix = 0.12;
uniform float deep_mix = 0.32;
uniform float tide_influence = 0.28;
uniform float wave1_density = 1.0;
uniform float wave1_angle = 0.0;
uniform float wave1_speed = 1.0;
uniform float offset_wave1_speed = 0.;
#define phase_wave1_speed (clock*wave1_speed+offset_wave1_speed)
uniform float wave2_density = 1.0;
uniform float wave2_angle = 0.0;
uniform float wave2_speed = 1.0;
uniform float offset_wave2_speed = 0.;
#define phase_wave2_speed (clock*wave2_speed+offset_wave2_speed)
uniform float wave2_weight = 0.45;
uniform float wave_axis_speed = 0.9;
uniform float refraction_base = 0.4;
uniform float caustic_strength = 0.27;
uniform float caustic_density = 0.16;
uniform float caustic_x = 0.12;
uniform float offset_caustic_x = 0.;
#define phase_caustic_x (clock*caustic_x+offset_caustic_x)
uniform float caustic_y = -0.08;
uniform float offset_caustic_y = 0.;
#define phase_caustic_y (clock*caustic_y+offset_caustic_y)
uniform float caustic_width = 1.0;
uniform float caustic_deform = 1.0;
uniform float offset_caustic_deform = 0.;
#define phase_caustic_deform (clock*caustic_deform+offset_caustic_deform)
uniform float caustic_break = 1.0;
uniform float offset_caustic_break = 0.;
#define phase_caustic_break (clock*caustic_break+offset_caustic_break)
uniform float foam_strength = 0.4;
uniform float foam_distance = 1.8;
uniform float foam_amplitude = 1.3;
uniform float foam_speed = 0.65;
uniform float offset_foam_speed = 0.;
#define phase_foam_speed (clock*foam_speed+offset_foam_speed)
uniform float foam_jagged = 0.65;
uniform float foam_jagged_speed = 0.4;
uniform float offset_foam_jagged_speed = 0.;
#define phase_foam_jagged_speed (clock*foam_jagged_speed+offset_foam_jagged_speed)
uniform float foam_width = 1.0;
uniform float foam_break_speed = 0.33;
uniform float offset_foam_break_speed = 0.;
#define phase_foam_break_speed (clock*foam_break_speed+offset_foam_break_speed)
uniform float backwash_distance = 4.0;
uniform float backwash_width = 0.7;
uniform float backwash_strength = 0.12;
uniform float ripple_lifetime = 2.8;
uniform float ripple_speed = 15.0;
uniform float ripple_radius = 2.0;
uniform float ripple_aspect = 1.6;
uniform float ripple_width = 1.0;
uniform float ripple_refraction = 1.4;
uniform float ripple_highlight = 0.3;
uniform float flow_aspect = 1.8;
uniform float flow_density = 0.22;
uniform float flow_speed = 2.8;
uniform float offset_flow_speed = 0.;
#define phase_flow_speed (clock*flow_speed+offset_flow_speed)
uniform float flow_decay = 90.0;
uniform float flow_amplitude = 0.65;
uniform float bridge_strength = 0.13;
uniform float bridge_width = 37.0;
uniform float bridge_distortion = 1.5;
uniform float bridge_compression = 0.32;
uniform float light_break_speed = 1.5;
uniform float offset_light_break_speed = 0.;
#define phase_light_break_speed (clock*light_break_speed+offset_light_break_speed)
uniform float moon_strength = 0.65;
uniform float moon_width = 6.0;
uniform float moon_amplitude = 3.0;
uniform float moon_speed = 0.65;
uniform float offset_moon_speed = 0.;
#define phase_moon_speed (clock*moon_speed+offset_moon_speed)
uniform float lamp_strength = 0.65;
uniform float lamp_width = 3.5;
uniform float lamp_amplitude = 1.5;
uniform float lamp_speed = 0.7;
uniform float offset_lamp_speed = 0.;
#define phase_lamp_speed (clock*lamp_speed+offset_lamp_speed)
uniform vec3 shallow_grade = vec3(0.,1.,1.);
uniform vec3 deep_grade = vec3(0.,1.,1.);
uniform vec3 caustic_grade = vec3(0.,1.,1.);
uniform vec3 foam_grade = vec3(0.,1.,1.);
uniform vec3 backwash_grade = vec3(0.,1.,1.);
uniform vec3 ripple_grade = vec3(0.,1.,1.);
uniform vec3 flow_grade = vec3(0.,1.,1.);
uniform vec3 bridge_grade = vec3(0.,1.,1.);
uniform vec3 moon_grade = vec3(0.,1.,1.);
uniform vec3 lamp_grade = vec3(0.,1.,1.);
uniform float offset_wave1_speed_axis = 0.;
#define phase_wave1_speed_axis (clock*wave1_speed*wave_axis_speed+offset_wave1_speed_axis)
uniform float offset_wave2_speed_axis = 0.;
#define phase_wave2_speed_axis (clock*wave2_speed*wave_axis_speed+offset_wave2_speed_axis)

vec3 grade_rgb(vec3 c, vec3 adjustment) {
 if (adjustment == vec3(0.,1.,1.)) { return c; }
 vec4 k=vec4(0.,-1./3.,2./3.,-1.);
 vec4 p=mix(vec4(c.bg,k.wz),vec4(c.gb,k.xy),step(c.b,c.g));
 vec4 q=mix(vec4(p.xyw,c.r),vec4(c.r,p.yzx),step(p.x,c.r));
 float d=q.x-min(q.w,q.y);
 float h=abs(q.z+(q.w-q.y)/(6.*d+.000001));
 float sat=clamp(d/(q.x+.000001)*adjustment.y,0.,1.);
 vec3 wheel=abs(fract(vec3(h+adjustment.x/360.)+vec3(0.,2./3.,1./3.))*6.-3.);
 return q.x*adjustment.z*mix(vec3(1.),clamp(wheel-1.,0.,1.),sat);
}
float wave(vec2 p, bool secondary) {
 vec2 a=turn(p*wave1_density,wave1_angle);
 vec2 b=turn(p*wave2_density,wave2_angle);
 float time1=secondary ? phase_wave1_speed_axis : phase_wave1_speed;
 float time2=secondary ? phase_wave2_speed_axis : phase_wave2_speed;
 return sin(a.x*.102+a.y*.073+time1*.8)
  +wave2_weight*sin(b.x*-.067+b.y*.134-time2*1.1);
}

void fragment() {
	vec2 p = floor(UV * resolution) + .5;
	vec2 uv = p / resolution;
	vec4 map = texture(bathymetry, uv);
	if (map.r < .5) { discard; }
	float dist = map.g * 64.0;
	float depth = clamp(map.b + water_level * tide_influence, 0.0, 1.0);
	float t = clock;
	vec2 displacement = vec2(wave(p, false), wave(p.yx + 67.0, true));
	float fall_wave = 0.0;
	if (basin_scene && waterfall_enabled) {
		vec2 delta=(p-vec2(395.,108.))*vec2(1.,flow_aspect);
		float radius=length(delta);
		fall_wave=sin(radius*flow_density-phase_flow_speed)*exp(-radius/flow_decay)*smoothstep(8.,22.,radius);
		displacement+=normalize(delta+vec2(.001))*fall_wave*flow_amplitude;
	}
	float rings = 0.0;
	if (ripples_enabled) {
		for (int i=0; i<16; i++) {
			float age = t - ripples[i].z;
			if (age >= 0.0 && age < ripple_lifetime && ripples[i].w > 0.0) {
				vec2 delta = (p - ripples[i].xy) * vec2(1.0, ripple_aspect);
				float d = length(delta);
				float radius = max(0.,age * ripple_speed + ripple_radius + ripple_offsets[i]);
				float fade = (1.0 - age / ripple_lifetime) * ripples[i].w;
				float ring = (1.0 - smoothstep(.35*ripple_width, 1.4*ripple_width, abs(d-radius))) * fade;
				rings += ring;
				displacement += normalize(delta + vec2(.001)) * ring * ripple_refraction;
			}
		}
	}
	vec2 offset = floor(displacement * strength * (refraction_base + depth) + .5);
	vec2 bent_uv = (p + offset) / resolution;
	// Reject samples that cross onto sand, cliffs or the palm islet.
	if (!refraction_enabled || texture(bathymetry, bent_uv).r < .5) { bent_uv = uv; }
	vec3 color = texture(seabed, bent_uv).rgb;
	if (depth_enabled) {
		vec3 tint = mix(grade_rgb(vec3(.16,.69,.65),shallow_grade), grade_rgb(vec3(.025,.19,.29),deep_grade), depth);
		tint=mix(tint,mix(grade_rgb(vec3(.025,.26,.39),shallow_grade),grade_rgb(vec3(.01,.045,.14),deep_grade),depth),night);
		color = mix(color, tint, clamp((water_mix + depth * deep_mix) * (1.15 - clarity * .55),0.,1.));
	}
	if (caustics_enabled) {
		vec2 q = p * caustic_density + vec2(phase_caustic_x, phase_caustic_y);
		float field = sin(q.x + sin(q.y * .9 + phase_caustic_deform * .21))
			* sin(q.y + sin(q.x * .8 - phase_caustic_deform * .18));
		float lattice = 1.0 - smoothstep(.025*caustic_width, .105*caustic_width, abs(field));
		float broken = smoothstep(-.6, .55, sin(q.x * .45 + q.y * .7 + phase_caustic_break * .2));
		float caustic = lattice * broken * (1.0 - depth) * smoothstep(1., 6., dist);
		color += grade_rgb(mix(vec3(.12,.24,.19),vec3(.04,.11,.17),night),caustic_grade) * caustic * caustic_strength;
	}
	if (foam_enabled) {
		float tide = foam_distance + foam_amplitude * sin(phase_foam_speed + p.x * .016);
		float jagged = foam_jagged * sin(p.x * .21 + p.y * .25 + phase_foam_jagged_speed);
		float edge = 1.0 - smoothstep(.35*foam_width, 1.1*foam_width, abs(dist - tide - jagged));
		float broken = smoothstep(-.5, .05, sin(p.x * .23 - p.y * .17 + phase_foam_break_speed));
		color = mix(color, grade_rgb(mix(vec3(.72,.89,.79),vec3(.22,.49,.68),night),foam_grade), edge * broken * foam_strength);
		float backwash = (1.0 - smoothstep(.0, backwash_width, abs(dist - tide - backwash_distance))) * backwash_strength;
		color += grade_rgb(vec3(.28,.46,.39),backwash_grade) * backwash;
	}
	if (basin_scene && environment_enabled) {
		// Artistic 2D projection of the real bridge colors into the water.
		float bridge=exp(-pow(abs((p.x-240.)/bridge_width),4.))*smoothstep(44.,57.,p.y)*(1.-smoothstep(60.,126.,p.y));
		vec2 reflected=vec2(p.x+floor(wave(p,false)*bridge_distortion),35.-(p.y-53.)*bridge_compression)/resolution;
		color=mix(color,grade_rgb(texture(seabed,reflected).rgb,bridge_grade),bridge*bridge_strength);
		float broken=.35+.65*smoothstep(-.35,.65,sin(p.y*1.1+phase_light_break_speed+sin(p.x*.4)));
		float moon=exp(-pow(abs((p.x-309.-sin(p.y*.07+phase_moon_speed)*moon_amplitude)/moon_width),2.))*smoothstep(88.,106.,p.y)*(1.-smoothstep(190.,265.,p.y));
		float lamp=exp(-pow(abs((p.x-144.-sin(p.y*.13+phase_lamp_speed)*lamp_amplitude)/lamp_width),2.))*smoothstep(125.,134.,p.y)*(1.-smoothstep(170.,211.,p.y));
		color+=night*broken*(grade_rgb(vec3(.13,.27,.35),moon_grade)*moon*moon_strength+grade_rgb(vec3(.55,.29,.055),lamp_grade)*lamp*lamp_strength);
	}
	color+=grade_rgb(mix(vec3(.018,.05,.05),vec3(.012,.035,.065),night),flow_grade)*max(0.,fall_wave)*smoothstep(6.,15.,dist);
	color = mix(color, grade_rgb(mix(vec3(.65,.88,.81),vec3(.26,.63,.79),night),ripple_grade), clamp(rings * ripple_highlight, 0.0, .7));
	if (debug_depth) { color = mix(vec3(.7,.95,.77), vec3(.05,.13,.42), depth); }
	COLOR = vec4(color, 1.0);
}
