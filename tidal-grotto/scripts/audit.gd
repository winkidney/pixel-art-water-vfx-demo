extends SceneTree

var study
var evidence := ""
var report := {}

func _initialize() -> void:
	call_deferred("run")

func wait_frames(count := 3) -> void:
	for i in count:
		await process_frame
	await RenderingServer.frame_post_draw

func shot(name: String) -> void:
	await wait_frames()
	root.get_texture().get_image().save_png(evidence.path_join(name+".png"))
	study.viewport.get_texture().get_image().save_png(evidence.path_join(name+"-world.png"))

func run() -> void:
	evidence = ProjectSettings.globalize_path("res://../evidence/parameters/legacy-regression" if "--legacy" in OS.get_cmdline_user_args() else "res://../evidence")
	DirAccess.make_dir_recursive_absolute(evidence)
	study = load("res://main.tscn").instantiate()
	root.add_child(study)
	await wait_frames(15)
	study.auto_tour = false
	study._update_tour_button()
	study.frozen = true
	study.clock = 6.0
	study.player = Vector2(380,235)
	study.target = study.player
	study._refresh_character(Vector2.DOWN)
	await shot("01-complete")
	report["renderer"] = RenderingServer.get_video_adapter_name()
	report["godot"] = Engine.get_version_info().string
	report["atlas_regions"] = []
	for frame in study.atlas:
		report.atlas_regions.append(str(frame.region))
	study.set_original_view(true)
	await shot("02-original")
	study.set_original_view(false)
	study.cycle_view()
	await shot("03-depth-map")
	study.cycle_view()
	report["depth_samples"] = []
	for sample in [study.START,Vector2(415,249),Vector2(396,239),Vector2(355,220),Vector2(278,180)]:
		study.player = sample
		study._refresh_character(Vector2.DOWN)
		report.depth_samples.append({"position":str(sample),"water":study.is_water(sample),"walkable":study.is_walkable(sample),"immersion":study.immersion})
		await shot("depth-%03d-%03d" % [sample.x,roundi(study.immersion*100)])
	study.player = Vector2(278,180)
	study._refresh_character(Vector2.DOWN)
	study.set_effect("submersion_enabled", false)
	await shot("04-submersion-off")
	study.set_effect("submersion_enabled", true)
	study.player = Vector2(380,235)
	study._refresh_character(Vector2.DOWN)
	study.add_ripple(Vector2(360,220),1.6)
	study.clock += 1.0
	await shot("05-ripples")
	study.clock += 1.0
	await shot("06-animation")
	for effect in ["depth_enabled","refraction_enabled","caustics_enabled","foam_enabled","ripples_enabled","reflection_enabled"]:
		study.set_effect(effect, false)
		await shot("layer-off-"+effect)
		study.set_effect(effect, true)
	# Real input dispatch verifies the keyboard route, rather than assigning a direction.
	study.frozen = false
	study.auto_tour = false
	study.target = study.player
	var start: Vector2 = study.player
	var key := InputEventKey.new()
	key.physical_keycode = KEY_A
	key.pressed = true
	Input.parse_input_event(key)
	await create_timer(.25).timeout
	key = InputEventKey.new()
	key.physical_keycode = KEY_A
	key.pressed = false
	Input.parse_input_event(key)
	await wait_frames(2)
	report["keyboard_movement_pixels"] = start.distance_to(study.player)
	study.frozen = true
	# A cliff and the palm are solid; a deep-water click remains navigable.
	report["cliff_blocked"] = not study.is_walkable(Vector2(10,10))
	report["palm_blocked"] = not study.is_walkable(Vector2(368,104))
	report["deep_water_walkable"] = study.is_walkable(Vector2(278,180))
	study.player = Vector2(396,239)
	study.parameters.set_value("water_level",-.7)
	study._refresh_character(Vector2.ZERO)
	var low: float = study.immersion
	study.parameters.set_value("water_level",.7)
	study._refresh_character(Vector2.ZERO)
	report["tide_changes_immersion"] = study.immersion > low
	# A real mouse event on the scene control chooses a target and emits a ripple.
	var click := InputEventMouseButton.new()
	click.position = Vector2(320,200)*2
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	study.display.gui_input.emit(click)
	report["click_target"] = study.target == Vector2(320,200)
	# Reset restores initial controls and removes all transient ripples.
	study.reset_study()
	report["reset_restored"] = study.player == study.START and study.auto_tour and not study.frozen and is_equal_approx(study.level,.7)
	study.frozen = true
	await shot("07-reset")
	study.parameters.restore_defaults()
	# Check the full round trip in deterministic simulation steps, without file I/O.
	study.reset_study()
	var shore_seen := false
	var shallow_seen := false
	var deep_seen := false
	var completed := false
	for frame_index in 4800:
		var previous: int = study.tour_index
		study.clock += 1.0/60
		study._move_player(1.0/60)
		shore_seen = shore_seen or study.immersion < .03
		shallow_seen = shallow_seen or (study.immersion > .03 and study.immersion < .3)
		deep_seen = deep_seen or study.immersion > .7
		if previous == study.TOUR.size()-1 and study.tour_index == 0:
			completed = true
			break
	report["tour_round_trip"] = completed
	report["tour_has_shore_shallow_deep"] = shore_seen and shallow_seen and deep_seen
	report["tour_end_position"] = str(study.player)
	study.player = Vector2(321,112)
	study.target = Vector2(406,112)
	study.auto_tour = false
	study.route_goal = Vector2.INF
	var island_blocks_line: bool = not study._clear_line(study.player, study.target)
	for i in 1800:
		study._move_player(1.0/60)
		if study.player.distance_to(study.target)<2: break
	report["island_detour"] = island_blocks_line and study.player.distance_to(study.target)<2
	# Windowed GPU run, warm-up first. Screenshot I/O is excluded from timing.
	study.reset_study()
	await create_timer(2.0).timeout
	var rendered_frames := Engine.get_frames_drawn()
	var ticks := Time.get_ticks_usec()
	await create_timer(3.0).timeout
	var seconds := (Time.get_ticks_usec()-ticks)/1000000.0
	report["windowed_render_fps"] = (Engine.get_frames_drawn()-rendered_frames)/seconds
	report["timing_seconds"] = seconds
	report["frame_cpu_ms"] = Performance.get_monitor(Performance.TIME_PROCESS)*1000
	report["render_objects"] = Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	var passed := true
	for check in ["click_target","cliff_blocked","palm_blocked","deep_water_walkable","reset_restored","tide_changes_immersion","tour_round_trip","tour_has_shore_shallow_deep","island_detour"]:
		passed = passed and report[check]
	passed = passed and report.keyboard_movement_pixels > 1
	report["passed"] = passed
	var file := FileAccess.open(evidence.path_join("runtime-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print("AUDIT_RESULT ",JSON.stringify(report))
	quit(0 if passed else 1)
