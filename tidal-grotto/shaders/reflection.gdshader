shader_type canvas_item;
render_mode unshaded;
uniform float clock = 0.0;
uniform sampler2D bathymetry : filter_nearest;
uniform vec2 foot = vec2(0.0);
uniform vec2 dimensions = vec2(20.0, 30.0);
uniform float opacity = .25;
uniform vec4 sprite_rect = vec4(0.0,0.0,640.0,640.0);

void fragment() {
	vec2 pixel = UV / TEXTURE_PIXEL_SIZE;
	vec2 local = (pixel - sprite_rect.xy) / sprite_rect.zw;
	vec2 position = foot + vec2((local.x-.5)*dimensions.x, (1.0-local.y)*dimensions.y);
	vec2 uv = UV + vec2(sin(local.y*30.0+clock*1.7)*2.0,0.0)*TEXTURE_PIXEL_SIZE;
	vec4 color = texture(TEXTURE, uv);
	float mask = texture(bathymetry, position / vec2(480.0,320.0)).r;
	color.rgb = mix(color.rgb, vec3(.08,.28,.33), .6);
	color.a *= opacity * local.y * mask;
	COLOR = color;
}
