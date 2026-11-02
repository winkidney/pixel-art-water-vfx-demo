shader_type canvas_item;
render_mode unshaded;
uniform sampler2D scene_plate : source_color, filter_nearest;
uniform sampler2D occlusion_map : filter_nearest;
uniform float foot_y=0.0;
void fragment() {
	float contact=texture(occlusion_map,UV).r*320.0;
	if (contact<1.0 || foot_y>=contact) { discard; }
	COLOR=texture(scene_plate,UV);
}
