shader_type canvas_item;
render_mode unshaded;
uniform sampler2D scene_plate : source_color, filter_nearest;
uniform sampler2D fall_mask : filter_nearest;
uniform vec2 resolution = vec2(480.0,320.0);
uniform float clock = 0.0;
uniform float night = 0.0;

uniform float fall_speed = 1.5;
uniform float offset_fall_speed = 0.;
#define phase_fall_speed (clock*fall_speed+offset_fall_speed)
uniform float fall_scroll = 9.0;
uniform float fall_stream = 0.065;
uniform float fall_stream_speed = 1.0;
uniform float offset_fall_stream_speed = 0.;
#define phase_fall_stream_speed (clock*fall_stream_speed+offset_fall_stream_speed)
uniform float impact_aspect = 2.5;
uniform float impact_density = 0.28;
uniform float impact_speed = 3.0;
uniform float offset_impact_speed = 0.;
#define phase_impact_speed (clock*impact_speed+offset_impact_speed)
uniform float impact_amplitude = 1.4;
uniform float impact_brightness = 0.94;
uniform float impact_flicker = 0.06;
uniform vec3 fall_grade = vec3(0.,1.,1.);
uniform vec3 impact_grade = vec3(0.,1.,1.);

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
	vec2 p = floor(UV*resolution)+.5;
	vec2 uv=p/resolution;
	vec2 mask=texture(fall_mask,uv).rg;
	if (max(mask.r,mask.g)<.5) { discard; }
	vec2 offset=vec2(0.0);
	if (mask.r>.5) {
		// Two crossfaded downward translations keep the source curtain continuous.
		float phase=fract(phase_fall_speed);
		vec2 a=(p-vec2(0.0,floor(phase*fall_scroll)))/resolution;
		vec2 b=(p-vec2(0.0,floor(fract(phase+.5)*fall_scroll)))/resolution;
		if (texture(fall_mask,a).r<.5) { a=uv; }
		if (texture(fall_mask,b).r<.5) { b=uv; }
		float blend=abs(phase-.5)*2.0;
		vec3 color=mix(texture(scene_plate,a).rgb,texture(scene_plate,b).rgb,blend);
		float stream=sin(p.x*.65+sin(p.y*.06-phase_fall_stream_speed*4.0))*sin(p.y*.25-phase_fall_stream_speed*7.0);
		COLOR=vec4(grade_rgb(color,fall_grade)*(1.0+stream*fall_stream),1.0);
	} else {
		vec2 delta=(p-vec2(397.,105.))*vec2(1.,impact_aspect);
		float phase=length(delta)*impact_density-phase_impact_speed;
		offset=floor(vec2(sin(phase),cos(phase))*impact_amplitude+.5);
		vec2 bent=(p+offset)/resolution;
		if (texture(fall_mask,bent).g<.5) { bent=uv; }
		vec3 color=texture(scene_plate,bent).rgb;
		COLOR=vec4(grade_rgb(color,impact_grade)*max(0.,impact_brightness+impact_flicker*sin(phase)),1.0);
	}
}
