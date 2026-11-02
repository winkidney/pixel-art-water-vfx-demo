shader_type canvas_item;
render_mode unshaded;
uniform float clock = 0.0;
uniform sampler2D bathymetry : filter_nearest;
uniform vec2 foot = vec2(0.0);
uniform vec2 dimensions = vec2(20.0, 30.0);
uniform float opacity = .25;
uniform vec4 sprite_rect = vec4(0.0,0.0,640.0,640.0);


uniform float reflection_distortion = 2.0;
uniform float reflection_speed = 1.7;
uniform float offset_reflection_speed = 0.;
#define phase_reflection_speed (clock*reflection_speed+offset_reflection_speed)
uniform float reflection_mix = 0.6;
uniform vec3 reflection_grade = vec3(0.,1.,1.);

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
	vec2 pixel = UV / TEXTURE_PIXEL_SIZE;
	vec2 local = (pixel - sprite_rect.xy) / sprite_rect.zw;
	vec2 position = foot + vec2((local.x-.5)*dimensions.x, (1.0-local.y)*dimensions.y);
	vec2 uv = UV + vec2(sin(local.y*30.0+phase_reflection_speed)*reflection_distortion,0.0)*TEXTURE_PIXEL_SIZE;
	vec4 color = texture(TEXTURE, uv);
	float mask = texture(bathymetry, position / vec2(480.0,320.0)).r;
	color.rgb = mix(color.rgb, grade_rgb(vec3(.08,.28,.33),reflection_grade), reflection_mix);
	color.a *= opacity * local.y * mask;
	COLOR = color;
}
