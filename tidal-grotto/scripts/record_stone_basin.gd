extends SceneTree

var study
var frame := 0

func _initialize() -> void:
	study=load("res://main.tscn").instantiate()
	root.add_child.call_deferred(study)

func _process(_delta: float) -> bool:
	frame+=1
	if frame==901:
		study.reset_study()
		study.choose_time(true)
	if frame==1801: quit()
	return false
