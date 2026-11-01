extends SceneTree
var study
var result := {}
var baselines := {}
var folder: String
var testing_id := ""
func _initialize() -> void:
	call_deferred("run")
func frames() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
func state(is_night: bool, is_moving: bool, time: float) -> void:
	study.clock=6.0
	for i in 16: study.ripples[i]=Vector4(0,0,-1000,0)
	study.ripple_cursor=0
	study.ripple_offsets.fill(0)
	study.add_ripple(Vector2(159,217),1.6)
	study.parameters.restore_defaults()
	if testing_id=="tide_influence": study.parameters.set_value("water_level",.5)
	study.auto_tour=false
	study.frozen=true
	study.moving=is_moving
	study.player=study.start_point if testing_id in ["idle_bob","idle_bob_speed"] else Vector2(134,213)
	study.target=study.player
	study.choose_time(is_night)
	study.clock=time
	study._refresh_character(Vector2.DOWN)
func count_changes(a: Image,b: Image) -> int:
	var changed:=0
	for y in 320:
		for x in 480:
			if a.get_pixel(x,y)!=b.get_pixel(x,y):changed+=1
	return changed
func run() -> void:
	folder=ProjectSettings.globalize_path("res://../evidence/parameters")
	study=load("res://main.tscn").instantiate()
	root.add_child(study)
	await frames()
	study.frozen=true
	study.auto_tour=false
	study.clock=6.0
	study.add_ripple(Vector2(159,217),1.6)
	var failed:=[]
	for definition in study.parameters.definitions:
		var id: String=definition.id
		testing_id=id
		var alternate: Variant=false if definition.get("type","")=="bool" else definition.max
		if alternate==definition.default: alternate=definition.min
		if id.ends_with("_grade_hue"):alternate=90.0
		if id.ends_with("_grade_saturation"):alternate=0.0
		if id.ends_with("_grade_brightness"):alternate=1.7
		if id in ["under_alpha","waterline_alpha","reflection_alpha","shadow_alpha","reflection_mix"]:alternate=0.0
		var is_moving: bool=id in ["move_bob","move_bob_speed","rotation_amplitude","rotation_speed"]
		var is_night: bool=id.begins_with("moon_") or id.begins_with("lamp_") or id.begins_with("night_character_") or id=="light_break_speed"
		state(is_night,is_moving,6.0)
		study.parameters.set_value(id,alternate)
		if id in ["click_amplitude","splash_amplitude","move_amplitude","move_interval"]:
			var before: int=study.ripple_cursor
			if id=="click_amplitude":
				var click:=InputEventMouseButton.new()
				click.position=Vector2(159,217)*2
				click.button_index=MOUSE_BUTTON_LEFT
				click.pressed=true
				study._scene_input(click)
			elif id=="splash_amplitude":
				var key:=InputEventKey.new()
				key.physical_keycode=KEY_SPACE
				key.pressed=true
				study._unhandled_key_input(key)
			else:
				study.target=study.player+Vector2(0,8)
				study.ripple_timer=0
				study._move_player(1.0/60)
			var expected: float=study.value(id) if id!="move_interval" else study.value("move_amplitude")
			var passed: bool=study.ripple_cursor!=before and is_equal_approx(study.ripples[before].w,expected)
			if id=="move_interval":passed=passed and is_equal_approx(study.ripple_timer,alternate)
			result[id]={"kind":"event","passed":passed}
			if not passed:failed.append(id)
			continue
		var changes:=0
		for time in [6.9,7.7]:
			study.clock=time
			study._refresh_character(Vector2.DOWN)
			await frames()
			var image: Image=study.viewport.get_texture().get_image()
			var key: String=str([is_night,is_moving,time,id=="tide_influence",id in ["idle_bob","idle_bob_speed"]])
			if not baselines.has(key):
				state(is_night,is_moving,time)
				await frames()
				baselines[key]=study.viewport.get_texture().get_image()
				state(is_night,is_moving,6.0)
				study.parameters.set_value(id,alternate)
			changes=maxi(changes,count_changes(image,baselines[key]))
			if changes>0:break
		result[id]={"kind":"render","changed_pixels":changes,"passed":changes>0}
		if changes==0:failed.append(id)
	study.parameters.restore_defaults()
	study.reset_study()
	study.choose_time(false)
	await create_timer(2.0).timeout
	var rendered:=Engine.get_frames_drawn()
	var ticks:=Time.get_ticks_usec()
	await create_timer(3.0).timeout
	var fps: float=(Engine.get_frames_drawn()-rendered)/((Time.get_ticks_usec()-ticks)/1000000.0)
	var report: Dictionary={"passed":failed.is_empty() and fps>55,"failed":failed,"count":result.size(),"windowed_render_fps":fps,"parameters":result}
	var file:=FileAccess.open(folder.path_join("coverage-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print("PARAMETER_COVERAGE ",JSON.stringify({"failed":failed,"count":result.size(),"fps":fps}))
	quit(0 if report.passed else 1)
