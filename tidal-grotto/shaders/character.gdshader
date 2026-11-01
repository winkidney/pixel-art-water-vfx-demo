shader_type canvas_item;
render_mode unshaded;

uniform float immersion = 0.0;
uniform float clock = 0.0;
uniform float night = 0.0;
uniform bool submersion_enabled = true;
uniform bool show_height = false;
uniform vec4 sprite_rect = vec4(0.0,0.0,640.0,640.0);
uniform vec2 world_texel = vec2(.02);

void fragment() {
	vec2 uv = UV;
	// Explicit atlas bounds keep the waterline independent of Sprite2D's region mode.
	vec2 pixel = uv / TEXTURE_PIXEL_SIZE;
	vec2 local = (pixel - sprite_rect.xy) / sprite_rect.zw;
	float width_curve = pow(abs(local.x - .5) * 2.0, 2.0) * .065;
	float height = 1.0 - local.y + width_curve;
	float level = immersion * .55;
	float surface = level + sin(clock * 2.0 + local.x * 5.0) * .012;
	vec4 base = texture(TEXTURE, uv);
	if (submersion_enabled && immersion > .015) {
		if (height < surface) {
			vec2 shift = vec2(sin(local.y * 33.0 + clock * 2.0), 0.0) * TEXTURE_PIXEL_SIZE * 3.0;
			base = texture(TEXTURE, uv + shift);
			base.rgb = mix(base.rgb * .55, vec3(.06,.43,.46), .58);
			base.a *= .36;
		}
		float band = 1.0 - smoothstep(.012, .035, abs(height - surface));
		base.rgb = mix(base.rgb, vec3(.77,.96,.87), band * .9);
		float neighbor = max(texture(TEXTURE,uv+vec2(world_texel.x,0)).a,
			texture(TEXTURE,uv-vec2(world_texel.x,0)).a);
		if (base.a < .25 && neighbor > .5 && band > .3) {
			base = vec4(.77,.96,.87,band*.85);
		}
	}
	if (base.a < .08) { discard; }
	base.rgb *= mix(vec3(1.),vec3(.54,.66,.88),night);
	if (show_height) { base.rgb = vec3(height); }
	COLOR = base;
}
