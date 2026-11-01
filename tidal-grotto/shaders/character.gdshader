shader_type canvas_item;
render_mode unshaded;

uniform float immersion = 0.0;
uniform float clock = 0.0;
uniform float night = 0.0;
uniform bool submersion_enabled = true;
uniform bool show_height = false;
uniform vec4 sprite_rect = vec4(0.0,0.0,640.0,640.0);
uniform vec2 world_texel = vec2(.02);


uniform float waterline_height = 0.55;
uniform float under_brightness = 0.55;
uniform float under_mix = 0.58;
uniform float under_alpha = 0.36;
uniform float under_distortion = 3.0;
uniform float under_frequency = 33.0;
uniform float under_speed = 2.0;
uniform float offset_under_speed = 0.;
#define phase_under_speed (clock*under_speed+offset_under_speed)
uniform float waterline_amplitude = 0.012;
uniform float waterline_speed = 2.0;
uniform float offset_waterline_speed = 0.;
#define phase_waterline_speed (clock*waterline_speed+offset_waterline_speed)
uniform float waterline_width = 1.0;
uniform float waterline_strength = 0.9;
uniform float waterline_alpha = 0.85;
uniform vec3 under_grade = vec3(0.,1.,1.);
uniform vec3 waterline_grade = vec3(0.,1.,1.);
uniform vec3 night_character_grade = vec3(0.,1.,1.);

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
void fragment() {
	vec2 uv = UV;
	// Explicit atlas bounds keep the waterline independent of Sprite2D's region mode.
	vec2 pixel = uv / TEXTURE_PIXEL_SIZE;
	vec2 local = (pixel - sprite_rect.xy) / sprite_rect.zw;
	float width_curve = pow(abs(local.x - .5) * 2.0, 2.0) * .065;
	float height = 1.0 - local.y + width_curve;
	float level = immersion * waterline_height;
	float surface = level + sin(phase_waterline_speed + local.x * 5.0) * waterline_amplitude;
	vec4 base = texture(TEXTURE, uv);
	if (submersion_enabled && immersion > .015) {
		if (height < surface) {
			vec2 shift = vec2(sin(local.y * under_frequency + phase_under_speed), 0.0) * TEXTURE_PIXEL_SIZE * under_distortion;
			base = texture(TEXTURE, uv + shift);
			base.rgb = mix(base.rgb * under_brightness, grade_rgb(vec3(.06,.43,.46),under_grade), under_mix);
			base.a *= under_alpha;
		}
		float band = 1.0 - smoothstep(.012*waterline_width, .035*waterline_width, abs(height - surface));
		base.rgb = mix(base.rgb, grade_rgb(vec3(.77,.96,.87),waterline_grade), band * waterline_strength);
		float neighbor = max(texture(TEXTURE,uv+vec2(world_texel.x,0)).a,
			texture(TEXTURE,uv-vec2(world_texel.x,0)).a);
		if (base.a < .25 && neighbor > .5 && band > .3) {
			base = vec4(grade_rgb(vec3(.77,.96,.87),waterline_grade),band*waterline_alpha);
		}
	}
	if (base.a < .08) { discard; }
	base.rgb *= mix(vec3(1.),grade_rgb(vec3(.54,.66,.88),night_character_grade),night);
	if (show_height) { base.rgb = vec3(height); }
	COLOR = base;
}
