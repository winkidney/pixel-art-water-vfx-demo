shader_type canvas_item;
render_mode unshaded;
uniform sampler2D scene_plate : source_color, filter_nearest;
uniform sampler2D fall_mask : filter_nearest;
uniform vec2 resolution = vec2(480.0,320.0);
uniform float clock = 0.0;
uniform float night = 0.0;
void fragment() {
	vec2 p = floor(UV*resolution)+.5;
	vec2 uv=p/resolution;
	vec2 mask=texture(fall_mask,uv).rg;
	if (max(mask.r,mask.g)<.5) { discard; }
	vec2 offset=vec2(0.0);
	if (mask.r>.5) {
		// Two crossfaded downward translations keep the source curtain continuous.
		float phase=fract(clock*1.5);
		vec2 a=(p-vec2(0.0,floor(phase*9.0)))/resolution;
		vec2 b=(p-vec2(0.0,floor(fract(phase+.5)*9.0)))/resolution;
		if (texture(fall_mask,a).r<.5) { a=uv; }
		if (texture(fall_mask,b).r<.5) { b=uv; }
		float blend=abs(phase-.5)*2.0;
		vec3 color=mix(texture(scene_plate,a).rgb,texture(scene_plate,b).rgb,blend);
		float stream=sin(p.x*.65+sin(p.y*.06-clock*4.0))*sin(p.y*.25-clock*7.0);
		COLOR=vec4(color*(1.0+stream*.065),1.0);
	} else {
		vec2 delta=(p-vec2(397.,105.))*vec2(1.,2.5);
		float phase=length(delta)*.28-clock*3.0;
		offset=floor(vec2(sin(phase),cos(phase))*1.4+.5);
		vec2 bent=(p+offset)/resolution;
		if (texture(fall_mask,bent).g<.5) { bent=uv; }
		vec3 color=texture(scene_plate,bent).rgb;
		COLOR=vec4(color*(.94+.06*sin(phase)),1.0);
	}
}
