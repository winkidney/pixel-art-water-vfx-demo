extends SceneTree
var study
var frame := 0
func _initialize() -> void:
	study=load("res://main.tscn").instantiate()
	root.add_child.call_deferred(study)
func query(text: String) -> void:
	study.parameter_panel.search.text=text
	study.parameter_panel.search.text_changed.emit(text)
func _process(_delta: float) -> bool:
	frame+=1
	if frame==2:
		study.parameters.folder=ProjectSettings.globalize_path("res://../.local/work/demo-presets")
		study.parameter_panel.refresh_presets()
		study.auto_tour=false
		study._update_tour_button()
		study.player=Vector2(134,213)
		study.target=study.player
	if frame==60:query("焦散")
	if frame>=90 and frame<240:study.parameters.set_value("caustic_strength",lerpf(.27,1.1,float(frame-90)/150))
	if frame==300:query("浅水")
	if frame>=330 and frame<450:study.parameters.set_value("shallow_grade_hue",lerpf(0,70,float(frame-330)/120))
	if frame==480:study.choose_time(true)
	if frame==600:
		study.parameters.restore_defaults()
		query("瀑布")
	if frame>=660 and frame<810:study.parameters.set_value("fall_speed",lerpf(1.5,3.5,float(frame-660)/150))
	if frame==870:
		study.parameter_panel.name_input.text="夜色流动"
		study.parameter_panel.save_current()
	if frame==930:
		study.choose_time(false)
		study.parameters.set_value("fall_speed",.5)
	if frame==1020:
		study.parameter_panel.choices.select(1)
		study.parameter_panel.load_selected()
	if frame==1140:
		study.parameters.restore_defaults()
		study.choose_time(false)
		query("")
	if frame==1261:quit()
	return false
