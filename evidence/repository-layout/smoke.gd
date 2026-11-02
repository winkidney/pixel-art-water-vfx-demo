extends SceneTree
var study
var folder := ""
func _initialize() -> void:
	var args=OS.get_cmdline_user_args()
	folder=args[0]
	DirAccess.make_dir_recursive_absolute(folder)
	run.call_deferred()
func frames(count:=4) -> void:
	for i in count:await process_frame
	await RenderingServer.frame_post_draw
func run() -> void:
	study=load("res://main.tscn").instantiate()
	root.add_child(study)
	await frames(16)
	study.set_process(false)
	var report={"godot":Engine.get_version_info().string,"renderer":RenderingServer.get_video_adapter_name(),"parameters":study.parameters.definitions.size(),"legacy":study.legacy,"variants":[]}
	for variant in ["day","night"]:
		if study.legacy and variant=="night":continue
		study.parameters.restore_defaults()
		study.reset_study()
		study.choose_time(variant=="night")
		study.auto_tour=false
		study.frozen=true
		study.clock=6.0
		if not study.legacy:study.player=Vector2(134,213)
		study.target=study.player
		study._refresh_character(Vector2.DOWN)
		study.add_ripple(Vector2(159,217),1.6)
		study.clock=6.9
		study._process(0.0)
		await frames()
		var image=study.viewport.get_texture().get_image()
		image.save_png(folder.path_join(variant+".png"))
		report.variants.append({"time":variant,"size":str(image.get_size()),"water_visible":study.water.visible,"character_visible":study.character.visible})
	report["passed"]=report.parameters==158 and report.variants.all(func(v):return v.water_visible and v.character_visible)
	FileAccess.open(folder.path_join("runtime.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	quit(0 if report.passed else 2)
