extends SceneTree
var study
var folder := ""
var report := {"checks":{}}
func _initialize() -> void:
	call_deferred("run")
func frames(count := 3) -> void:
	for i in count: await process_frame
	await RenderingServer.frame_post_draw
func shot(name: String) -> void:
	await frames()
	root.get_texture().get_image().save_png(folder.path_join(name+"-full.png"))
	study.viewport.get_texture().get_image().save_png(folder.path_join(name+"-world.png"))
func check(name: String, value: bool) -> void:
	report.checks[name]=value
	if not value: push_error("CHECK FAILED: "+name)
func run() -> void:
	folder=ProjectSettings.globalize_path("res://../evidence/parameters")
	DirAccess.make_dir_recursive_absolute(folder)
	study=load("res://main.tscn").instantiate()
	root.add_child(study)
	await frames(20)
	study.parameters.folder=ProjectSettings.globalize_path("res://../work/preset-audit")
	study.parameter_panel.refresh_presets()
	study.auto_tour=false
	study._update_tour_button()
	study.frozen=true
	study.clock=6.0
	study.player=Vector2(134,213)
	study.target=study.player
	study._refresh_character(Vector2.DOWN)
	study.add_ripple(Vector2(159,217),1.6)
	study.clock=6.9
	await shot("day-default")
	study.choose_time(true)
	await shot("night-default")
	report.renderer=RenderingServer.get_video_adapter_name()
	report.parameter_count=study.parameters.definitions.size()
	check("every_control_created",study.parameter_panel.editors.size()==study.parameters.definitions.size())
	var before: Dictionary=study.parameters.values.duplicate(true)
	check("reject_nan",not study.parameters.set_value("clarity",NAN))
	check("reject_out_of_range",not study.parameters.set_value("clarity",5))
	check("invalid_preserves_values",before==study.parameters.values)
	var slider: HSlider=study.parameter_panel.editors.clarity.slider
	var click:=InputEventMouseButton.new()
	click.position=slider.global_position+Vector2(slider.size.x*.3,slider.size.y*.5)
	click.button_index=MOUSE_BUTTON_LEFT
	click.pressed=true
	Input.parse_input_event(click)
	await frames()
	click=InputEventMouseButton.new()
	click.position=slider.global_position+slider.size*.5
	click.button_index=MOUSE_BUTTON_LEFT
	click.pressed=false
	Input.parse_input_event(click)
	await frames()
	check("real_mouse_operates_slider",not is_equal_approx(study.value("clarity"),.65))
	study.parameter_panel.editors.clarity.slider.value=.4
	check("slider_updates_model",is_equal_approx(study.value("clarity"),.4))
	study.parameter_panel.submit_number("clarity","0.75")
	check("number_updates_shader",is_equal_approx(study.water_material.get_shader_parameter("clarity"),.75))
	study.parameter_panel.submit_number("clarity","500")
	check("invalid_number_keeps_last_value",is_equal_approx(study.value("clarity"),.75))
	study.parameters.set_value("foam_strength",.85)
	study.parameters.restore_defaults("water", "clarity")
	check("single_reset_isolated",is_equal_approx(study.value("clarity"),.65) and is_equal_approx(study.value("foam_strength"),.85))
	var position: Vector2=study.player
	var clock: float=study.clock
	study.parameters.restore_defaults("foam")
	check("group_reset_preserves_scene",study.player==position and study.clock==clock and study.frozen and study.night)
	study.parameters.set_value("strength",2.2)
	study.reset_study()
	check("scene_reset_preserves_parameters",is_equal_approx(study.value("strength"),2.2) and study.player==study.start_point and study.night)
	study.frozen=true
	study.auto_tour=false
	study.clock=8
	study.player=Vector2(134,213)
	study.target=study.player
	var phase: float=study.motion_phase("fall_speed")
	study.parameters.set_value("fall_speed",3.0)
	check("speed_change_keeps_phase",is_equal_approx(phase,study.motion_phase("fall_speed")))
	study.parameters.set_value("shallow_grade_hue",45)
	var shared: Dictionary=study.parameters.values.duplicate(true)
	study.choose_time(false)
	study.choose_time(true)
	check("time_switch_keeps_shared_values",shared==study.parameters.values)
	study.parameters.restore_defaults()
	var defaults: Dictionary=study.parameters.values.duplicate(true)
	study.parameters.set_value("clarity",.42)
	study.parameters.set_value("moon_strength",1.2)
	study.choose_time(true)
	study.parameter_panel.name_input.text="测试方案"
	study.parameter_panel.save_current()
	var path: String=study.parameters.folder.path_join("测试方案.json")
	check("preset_saved",FileAccess.file_exists(path))
	study.parameters.set_value("clarity",.8)
	study.choose_time(false)
	position=study.player
	clock=study.clock
	study.parameter_panel.refresh_presets()
	study.parameter_panel.choices.select(1)
	study.parameter_panel.load_selected()
	check("load_values_and_saved_time",is_equal_approx(study.value("clarity"),.42) and study.night)
	check("load_preserves_scene",study.player==position and study.clock==clock and study.frozen and not study.auto_tour)
	var exported: String=study.parameters.folder.path_join("export/测试导出.json")
	check("export_valid",study.parameters.export_file(exported,"测试导出",study.night))
	study.parameters.set_value("clarity",.9)
	var imported: Dictionary=study.parameters.import_file(exported)
	check("import_round_trip",not imported.is_empty() and is_equal_approx(study.value("clarity"),.42))
	var invalid: Dictionary=study.parameters.snapshot("invalid",false)
	invalid.values.clarity=8
	before=study.parameters.values.duplicate(true)
	check("invalid_preset_atomic",study.parameters.apply_snapshot(invalid).is_empty() and before==study.parameters.values)
	var bad_path: String=study.parameters.folder.path_join("damaged.json")
	var bad_file:=FileAccess.open(bad_path,FileAccess.WRITE)
	bad_file.store_string("{bad json")
	bad_file.close()
	before=study.parameters.values.duplicate(true)
	check("damaged_import_atomic",study.parameters.import_file(bad_path).is_empty() and before==study.parameters.values)
	DirAccess.remove_absolute(bad_path)
	check("invalid_preset_name_rejected",study.parameters.save_named("../escape",false).is_empty())
	var continuous:=true
	for definition in study.parameters.definitions:
		if not definition.motion: continue
		var old_phase: float=study.motion_phase(definition.id)
		study.parameters.set_value(definition.id,definition.max)
		continuous=continuous and is_equal_approx(old_phase,study.motion_phase(definition.id))
	check("all_speed_controls_keep_phase",continuous)
	var offset: float=study.phase_offsets.get("fall_speed",0.0)
	study.parameters.restore_defaults("water", "clarity")
	check("single_reset_preserves_other_motion",is_equal_approx(offset,study.phase_offsets.get("fall_speed",0.0)))
	study.parameters.restore_defaults()
	check("original_defaults_immutable",study.parameters.values==defaults)
	study.parameter_panel.search.text="焦散"
	study.parameter_panel.search.text_changed.emit("焦散")
	check("search_finds_group",study.parameter_panel.group_boxes.caustics.container.visible and not study.parameter_panel.group_boxes.water.container.visible)
	study.parameter_panel.search.text=""
	study.parameter_panel.search.text_changed.emit("")
	study.parameter_panel.advanced.button_pressed=true
	check("advanced_reveals_controls",study.parameter_panel.group_boxes.water.rows.size()>2)
	study.parameter_panel.advanced.button_pressed=false
	study.parameter_panel.name_input.grab_focus()
	await frames()
	var key:=InputEventKey.new()
	key.physical_keycode=KEY_W
	key.pressed=true
	Input.parse_input_event(key)
	study.frozen=false
	position=study.player
	await create_timer(.15).timeout
	key=InputEventKey.new()
	key.physical_keycode=KEY_W
	key.pressed=false
	Input.parse_input_event(key)
	await frames()
	check("text_focus_blocks_movement",study.player==position)
	study.parameter_panel.name_input.release_focus()
	study.frozen=true
	study.parameters.restore_defaults()
	study.clock=6.9
	study.player=Vector2(134,213)
	study.target=study.player
	study._refresh_character(Vector2.DOWN)
	study.choose_time(false)
	study.parameters.set_value("shallow_grade_hue",60)
	study.parameters.set_value("caustic_strength",1.2)
	study.parameters.set_value("foam_strength",.8)
	await shot("day-adjusted")
	study.choose_time(true)
	await shot("night-adjusted")
	report.passed=not report.checks.values().has(false)
	var file:=FileAccess.open(folder.path_join("runtime-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print("PARAMETER_AUDIT ",JSON.stringify(report))
	quit(0 if report.passed else 1)
