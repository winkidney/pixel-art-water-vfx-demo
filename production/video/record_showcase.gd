extends SceneTree
## Deterministic real-GPU footage. Does not modify production assets or presets.
var study
var folder := ""
var jobs := ["day","night","entry","refraction_off","refraction_on","depth_off","depth_on","caustics_off","caustics_on","foam_off","foam_on","ripples","falls","environment","occlusion_off","occlusion_on","deep","waterline_bad","color_day","color_night"]

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	folder=args[0] if args.size()>0 else "/tmp/water-showcase"
	DirAccess.make_dir_recursive_absolute(folder)
	run.call_deferred()

func run() -> void:
	study=load("res://main.tscn").instantiate()
	root.add_child(study)
	await process_frame
	await process_frame
	study.set_process(false)
	Engine.max_fps=0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var report := {"godot":Engine.get_version_info().string,"renderer":RenderingServer.get_video_adapter_name(),"size":[480,320],"fps":60,"shots":[]}
	for job in jobs:
		study.parameters.restore_defaults()
		study.reset_study()
		study.auto_tour=false
		study.frozen=true
		study.choose_time(job in ["night","environment","color_night"])
		study.player=Vector2(134,213)
		study.target=study.player
		study.character.visible=true
		study.shadow.visible=true
		study.reflection.visible=true
		study.foreground.visible=true
		if job.begins_with("occlusion"):
			study.player=Vector2(176,103)
			study.foreground.visible=job.ends_with("on")
		if job in ["deep","waterline_bad"]:
			study.player=Vector2(245,160)
		if job=="waterline_bad": study.parameters.set_value("waterline_height",0.8)
		if job in ["falls","environment"]:
			study.character.visible=false
			study.shadow.visible=false
			study.reflection.visible=false
		if job.ends_with("_off") and not job.begins_with("occlusion"):
			study.set_effect(job.replace("_off","_enabled"),false)
		var seconds: int=6 if job in ["day","night","entry","ripples","falls","environment","deep","waterline_bad","color_day","color_night"] else 4
		var frame_count: int=seconds*60
		var output=FileAccess.open(folder.path_join(job+".rgb.part"),FileAccess.WRITE)
		if output==null:
			push_error("Cannot open capture output");quit(2);return
		for frame in frame_count:
			study.clock=6.0+float(frame)/60.0
			if job in ["day","night","entry"]:
				study.player=Vector2(113,207).lerp(Vector2(245,160),float(frame)/float(frame_count-1))
				if frame%25==0: study.add_ripple(study._surface_point(),0.65)
			if job=="ripples" and frame%120==0:
				study.add_ripple(Vector2(207,208),1.5)
				study.add_ripple(Vector2(280,180),0.9)
			if job.begins_with("color"):
				study.parameters.set_value("shallow_grade_hue",sin(float(frame)/float(frame_count)*PI)*24.0)
			study.target=study.player
			study._refresh_character(Vector2.DOWN)
			study._process(0.0)
			await RenderingServer.frame_post_draw
			var image: Image=study.viewport.get_texture().get_image()
			image.convert(Image.FORMAT_RGB8)
			output.store_buffer(image.get_data())
			if frame==frame_count/2: image.save_png(folder.path_join(job+".png"))
		output.close()
		DirAccess.rename_absolute(folder.path_join(job+".rgb.part"),folder.path_join(job+".rgb"))
		report.shots.append({"id":job,"frames":frame_count,"seconds":seconds,"bytes":frame_count*480*320*3})
		print("CAPTURE ",job," ",frame_count)
	var receipt=FileAccess.open(folder.path_join("capture-report.json"),FileAccess.WRITE)
	receipt.store_string(JSON.stringify(report,"\t"))
	print("CAPTURE COMPLETE")
	quit()
