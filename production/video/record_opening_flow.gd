extends SceneTree
## Real-GPU close-up source: isolate the receiving basin flow, not the curtain.
var study
var folder := ""
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	folder=args[0] if args.size()>0 else "/tmp/water-opening-flow"
	DirAccess.make_dir_recursive_absolute(folder)
	run.call_deferred()
func run() -> void:
	study=load("res://main.tscn").instantiate()
	root.add_child(study)
	await process_frame
	await process_frame
	study.set_process(false)
	study.parameters.restore_defaults()
	study.reset_study()
	study.auto_tour=false
	study.frozen=true
	study.choose_time(false)
	study.parameters.set_value("wave1_speed",0.0)
	study.parameters.set_value("wave2_speed",0.0)
	study.parameters.set_value("flow_amplitude",1.4)
	study.set_effect("caustics_enabled",false)
	study.set_effect("foam_enabled",false)
	study.set_effect("ripples_enabled",false)
	study.character.visible=false
	study.shadow.visible=false
	study.reflection.visible=false
	study.waterfall.visible=false
	Engine.max_fps=0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var output=FileAccess.open(folder.path_join("intro_flow.rgb"),FileAccess.WRITE)
	if output==null:
		push_error("Cannot create flow capture");quit(2);return
	for frame in 240:
		study.clock=6.0+float(frame)/60.0
		study._process(0.0)
		await RenderingServer.frame_post_draw
		var image: Image=study.viewport.get_texture().get_image()
		image.convert(Image.FORMAT_RGB8)
		output.store_buffer(image.get_data())
		if frame==120: image.save_png(folder.path_join("intro_flow.png"))
	output.close()
	var info={"id":"intro_flow","frames":240,"seconds":4,"bytes":240*480*320*3,"godot":Engine.get_version_info().string,"renderer":RenderingServer.get_video_adapter_name(),"flow_amplitude":1.4,"background_wave_speeds":0,"curtain_animation_visible":false,"opening_crop":[240,124,480,259],"note":"Isolated real shader flow, parameter value labelled on screen. Crop excludes waterfall curtain and impact foam."}
	var receipt=FileAccess.open(folder.path_join("intro-flow-report.json"),FileAccess.WRITE)
	receipt.store_string(JSON.stringify(info,"\t"))
	receipt.close()
	var report_path=folder.path_join("capture-report.json")
	if FileAccess.file_exists(report_path):
		var report: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(report_path))
		var jobs: Array=[]
		for item in report.shots:
			if item.id!="intro_flow": jobs.append(item)
		jobs.append(info)
		report.shots=jobs
		var report_file=FileAccess.open(report_path,FileAccess.WRITE)
		report_file.store_string(JSON.stringify(report,"\t"))
	print("OPENING FLOW COMPLETE")
	quit()
