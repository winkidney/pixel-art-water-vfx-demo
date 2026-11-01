extends SceneTree

var study
var evidence: String
var report := {}

func _initialize() -> void:
	call_deferred("run")

func frames(count := 3) -> void:
	for i in count: await process_frame
	await RenderingServer.frame_post_draw

func shot(name: String, full := false) -> void:
	await frames()
	study.viewport.get_texture().get_image().save_png(evidence.path_join(name+".png"))
	if full: root.get_texture().get_image().save_png(evidence.path_join(name+"-full.png"))

func actor_visible(value: bool) -> void:
	study.character.visible=value
	study.shadow.visible=value
	study.reflection.visible=value

func run() -> void:
	var base := ProjectSettings.globalize_path("res://../evidence/stone-basin")
	study=load("res://main.tscn").instantiate()
	root.add_child(study)
	await frames(20)
	report["renderer"]=RenderingServer.get_video_adapter_name()
	report["godot"]=Engine.get_version_info().string
	report["variants"]={}
	for variant in ["day","night"]:
		evidence=base.path_join(variant)
		DirAccess.make_dir_recursive_absolute(evidence)
		study.reset_study()
		study.choose_time(variant=="night")
		study.auto_tour=false
		study._update_tour_button()
		study.frozen=true
		study.clock=6.0
		study.player=Vector2(134,213)
		study.target=study.player
		study._refresh_character(Vector2.DOWN)
		study.add_ripple(Vector2(159,217),1.6)
		study.clock=6.9
		await shot("complete",true)
		await shot("freeze-repeat")
		var result := {}
		study.set_original_view(true)
		study.cycle_view()
		result["original_depth_restores_actor"]=study.character.visible and study.water.visible and study.waterfall.visible and study.view_mode==1
		study.cycle_view()
		result["depth_samples"]=[]
		for point in [study.start_point,Vector2(113,207),Vector2(134,213),Vector2(181,196),Vector2(245,160)]:
			study.player=point
			study._refresh_character(Vector2.DOWN)
			result.depth_samples.append({"position":str(point),"immersion":study.immersion,"walkable":study.is_walkable(point)})
			await shot("depth-%03d" % roundi(study.immersion*100))
		study.set_effect("submersion_enabled",false)
		await shot("submersion-off")
		study.set_effect("submersion_enabled",true)
		study.player=Vector2(134,213)
		study._refresh_character(Vector2.DOWN)
		await shot("layers-on")
		for effect in study.toggles:
			study.set_effect(effect,false)
			await shot("off-"+effect)
			study.set_effect(effect,true)
		# Isolate environmental animation and prove no leakage onto dry artwork.
		actor_visible(false)
		await shot("environment-a")
		study.clock=7.4
		await shot("environment-b")
		study.set_original_view(true)
		await shot("plate")
		study.set_original_view(false)
		actor_visible(false)
		study.water.visible=false
		study.clock=6.0
		await shot("fall-a")
		study.clock=6.5
		await shot("fall-b")
		study.water.visible=true
		actor_visible(true)
		study.player=Vector2(176,103)
		study.target=study.player
		study._refresh_character(Vector2.DOWN)
		await shot("occlusion-on")
		study.foreground.visible=false
		await shot("occlusion-off")
		study.foreground.visible=true
		study.player=Vector2(176,112)
		study._refresh_character(Vector2.DOWN)
		await shot("foreground-front-on")
		study.foreground.visible=false
		await shot("foreground-front-off")
		study.foreground.visible=true
		# Real keyboard dispatch and a mouse event on the actual scene control.
		study.player=Vector2(245,160)
		study.target=study.player
		study.frozen=false
		var before: Vector2=study.player
		var key:=InputEventKey.new()
		key.physical_keycode=KEY_A
		key.pressed=true
		Input.parse_input_event(key)
		await create_timer(.25).timeout
		key=InputEventKey.new()
		key.physical_keycode=KEY_A
		key.pressed=false
		Input.parse_input_event(key)
		await frames(2)
		result["keyboard_movement_pixels"]=before.distance_to(study.player)
		study.frozen=true
		var click:=InputEventMouseButton.new()
		click.position=Vector2(280,170)*2
		click.button_index=MOUSE_BUTTON_LEFT
		click.pressed=true
		study.display.gui_input.emit(click)
		result["click_target"]=study.target==Vector2(280,170)
		result["cliff_blocked"]=not study.is_walkable(Vector2(150,90))
		result["reef_blocked"]=not study.is_walkable(Vector2(350,210))
		result["deep_water_walkable"]=study.is_walkable(Vector2(245,160))
		study.player=Vector2(134,213)
		study.level=-.7
		study._refresh_character(Vector2.ZERO)
		var low: float=study.immersion
		study.level=.7
		study._refresh_character(Vector2.ZERO)
		result["tide_changes_immersion"]=study.immersion>low
		study.reset_study()
		result["reset_restored"]=study.player==study.start_point and study.auto_tour and not study.frozen and study.level==0 and study.night==(variant=="night")
		study.frozen=true
		var shore:=false
		var shallow:=false
		var deep:=false
		var completed:=false
		var all_walkable:=true
		for tick in 6000:
			var previous: int=study.tour_index
			study.clock+=1.0/60
			study._move_player(1.0/60)
			shore=shore or study.immersion<.03
			shallow=shallow or (study.immersion>.03 and study.immersion<.3)
			deep=deep or study.immersion>.7
			all_walkable=all_walkable and study.is_walkable(study.player)
			if previous==study.tour_points.size()-1 and study.tour_index==0:
				completed=true
				break
		result["tour_round_trip"]=completed
		result["tour_has_shore_shallow_deep"]=shore and shallow and deep
		result["tour_stays_walkable"]=all_walkable
		result["tour_end_position"]=str(study.player)
		study.player=Vector2(321,211)
		study.target=Vector2(418,211)
		study.auto_tour=false
		study.route_goal=Vector2.INF
		var blocked: bool=not study._clear_line(study.player,study.target)
		for tick in 2400:
			study._move_player(1.0/60)
			if study.player.distance_to(study.target)<2: break
		result["reef_detour"]=blocked and study.player.distance_to(study.target)<2
		study.reset_study()
		await create_timer(2.0).timeout
		var rendered:=Engine.get_frames_drawn()
		var ticks:=Time.get_ticks_usec()
		var cpu_samples: Array[float]=[]
		for frame in 180:
			await process_frame
			cpu_samples.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000)
		result["windowed_render_fps"]=(Engine.get_frames_drawn()-rendered)/((Time.get_ticks_usec()-ticks)/1000000.0)
		cpu_samples.sort()
		result["frame_cpu_ms_median"]=cpu_samples[90]
		result["frame_cpu_ms_p95"]=cpu_samples[171]
		result["frame_cpu_ms_max"]=cpu_samples[179]
		result["passed"]=result.keyboard_movement_pixels>1 and result.windowed_render_fps>55
		for check in ["original_depth_restores_actor","click_target","cliff_blocked","reef_blocked","deep_water_walkable","tide_changes_immersion","reset_restored","tour_round_trip","tour_has_shore_shallow_deep","tour_stays_walkable","reef_detour"]:
			result.passed=result.passed and result[check]
		report.variants[variant]=result
	report["passed"]=report.variants.day.passed and report.variants.night.passed
	var file:=FileAccess.open(base.path_join("runtime-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print("STONE_BASIN_AUDIT ",JSON.stringify(report))
	quit(0 if report.passed else 1)
