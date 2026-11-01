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
uniform vec4 ripples[16]; // x, y, birth time, amplitude; world-pixel coordinates

float wave(vec2 p, float t) {
	return sin(p.x * .102 + p.y * .073 + t * .8)
		+ .45 * sin(p.x * -.067 + p.y * .134 - t * 1.1);
}

void fragment() {
	vec2 p = floor(UV * resolution) + .5;
	vec2 uv = p / resolution;
	vec4 map = texture(bathymetry, uv);
	if (map.r < .5) { discard; }
	float dist = map.g * 64.0;
	float depth = clamp(map.b + water_level * .28, 0.0, 1.0);
	float t = clock;
	vec2 displacement = vec2(wave(p, t), wave(p.yx + 67.0, t * .9));
	float fall_wave = 0.0;
	if (basin_scene && waterfall_enabled) {
		vec2 delta=(p-vec2(395.,108.))*vec2(1.,1.8);
		float radius=length(delta);
		fall_wave=sin(radius*.22-t*2.8)*exp(-radius/90.)*smoothstep(8.,22.,radius);
		displacement+=normalize(delta+vec2(.001))*fall_wave*.65;
	}
	float rings = 0.0;
	if (ripples_enabled) {
		for (int i=0; i<16; i++) {
			float age = t - ripples[i].z;
			if (age >= 0.0 && age < 2.8 && ripples[i].w > 0.0) {
				vec2 delta = (p - ripples[i].xy) * vec2(1.0, 1.6);
				float d = length(delta);
				float radius = age * 15.0 + 2.0;
				float fade = (1.0 - age / 2.8) * ripples[i].w;
				float ring = (1.0 - smoothstep(.35, 1.4, abs(d-radius))) * fade;
				rings += ring;
				displacement += normalize(delta + vec2(.001)) * ring * 1.4;
			}
		}
	}
	vec2 offset = floor(displacement * strength * (.4 + depth) + .5);
	vec2 bent_uv = (p + offset) / resolution;
	// Reject samples that cross onto sand, cliffs or the palm islet.
	if (!refraction_enabled || texture(bathymetry, bent_uv).r < .5) { bent_uv = uv; }
	vec3 color = texture(seabed, bent_uv).rgb;
	if (depth_enabled) {
		vec3 tint = mix(vec3(.16,.69,.65), vec3(.025,.19,.29), depth);
		tint=mix(tint,mix(vec3(.025,.26,.39),vec3(.01,.045,.14),depth),night);
		color = mix(color, tint, (.12 + depth * .32) * (1.15 - clarity * .55));
	}
	if (caustics_enabled) {
		vec2 q = p * .16 + vec2(t * .12, -t * .08);
		float field = sin(q.x + sin(q.y * .9 + t * .21))
			* sin(q.y + sin(q.x * .8 - t * .18));
		float lattice = 1.0 - smoothstep(.025, .105, abs(field));
		float broken = smoothstep(-.6, .55, sin(q.x * .45 + q.y * .7 + t * .2));
		float caustic = lattice * broken * (1.0 - depth) * smoothstep(1., 6., dist);
		color += mix(vec3(.12,.24,.19),vec3(.04,.11,.17),night) * caustic * .27;
	}
	if (foam_enabled) {
		float tide = 1.8 + 1.3 * sin(t * .65 + p.x * .016);
		float jagged = .65 * sin(p.x * .21 + p.y * .25 + t * .4);
		float edge = 1.0 - smoothstep(.35, 1.1, abs(dist - tide - jagged));
		float broken = smoothstep(-.5, .05, sin(p.x * .23 - p.y * .17 + t * .33));
		color = mix(color, mix(vec3(.72,.89,.79),vec3(.22,.49,.68),night), edge * broken * .40);
		float backwash = (1.0 - smoothstep(.0, .7, abs(dist - tide - 4.0))) * .12;
		color += vec3(.28,.46,.39) * backwash;
	}
	if (basin_scene && environment_enabled) {
		// Artistic 2D projection of the real bridge colors into the water.
		float bridge=exp(-pow(abs((p.x-240.)/37.),4.))*smoothstep(44.,57.,p.y)*(1.-smoothstep(60.,126.,p.y));
		vec2 reflected=vec2(p.x+floor(wave(p,t)*1.5),35.-(p.y-53.)*.32)/resolution;
		color=mix(color,texture(seabed,reflected).rgb,bridge*.13);
		float broken=.35+.65*smoothstep(-.35,.65,sin(p.y*1.1+t*1.5+sin(p.x*.4)));
		float moon=exp(-pow(abs((p.x-309.-sin(p.y*.07+t*.65)*3.)/6.),2.))*smoothstep(88.,106.,p.y)*(1.-smoothstep(190.,265.,p.y));
		float lamp=exp(-pow(abs((p.x-144.-sin(p.y*.13+t*.7)*1.5)/3.5),2.))*smoothstep(125.,134.,p.y)*(1.-smoothstep(170.,211.,p.y));
		color+=night*broken*(vec3(.13,.27,.35)*moon*.65+vec3(.55,.29,.055)*lamp*.65);
	}
	color+=mix(vec3(.018,.05,.05),vec3(.012,.035,.065),night)*max(0.,fall_wave)*smoothstep(6.,15.,dist);
	color = mix(color, mix(vec3(.65,.88,.81),vec3(.26,.63,.79),night), clamp(rings * .30, 0.0, .7));
	if (debug_depth) { color = mix(vec3(.7,.95,.77), vec3(.05,.13,.42), depth); }
	COLOR = vec4(color, 1.0);
}
