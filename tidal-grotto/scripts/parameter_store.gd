extends RefCounted
## One definition is shared by runtime, controls and preset validation.
signal changed(ids: PackedStringArray, reason: String)
var definitions: Array = []
var by_id: Dictionary = {}
var colors: Array = []
var values: Dictionary = {}
var defaults: Dictionary = {}
var error := ""
var folder := "user://water-presets"

func _init(preset_folder := "user://water-presets") -> void:
	folder = preset_folder
	var schema: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/water-parameters.json"))
	definitions = schema.parameters
	colors = schema.colors
	for definition in definitions:
		by_id[definition.id] = definition
		defaults[definition.id] = definition.default
	values = defaults.duplicate(true)

func valid_value(id: String, value: Variant) -> bool:
	if not by_id.has(id):
		error = "未知参数：" + id
		return false
	var definition: Dictionary = by_id[id]
	if definition.get("type", "float") == "bool":
		if value is bool: return true
	else:
		if (value is float or value is int) and is_finite(float(value)) and float(value) >= float(definition.min) and float(value) <= float(definition.max): return true
	error = "%s 的输入无效，未应用" % definition.label
	return false

func set_value(id: String, value: Variant) -> bool:
	error = ""
	if not valid_value(id,value): return false
	if values[id] == value: return true
	values[id] = value
	changed.emit(PackedStringArray([id]),"edit")
	return true

func restore_defaults(group := "", single := "") -> void:
	var ids := PackedStringArray()
	for definition in definitions:
		if (group.is_empty() or definition.group == group) and (single.is_empty() or definition.id == single):
			values[definition.id] = defaults[definition.id]
			ids.append(definition.id)
	changed.emit(ids,"defaults")

func grade(id: String) -> Vector3:
	return Vector3(values[id+"_grade_hue"],values[id+"_grade_saturation"],values[id+"_grade_brightness"])

func base_color(id: String, night: bool) -> Color:
	for item in colors:
		if item.id == id:
			var rgb: Array = item.night if night else item.day
			return Color(rgb[0],rgb[1],rgb[2])
	return Color.WHITE

func graded_color(id: String, night: bool) -> Color:
	var base := base_color(id,night)
	var adjustment := grade(id)
	if adjustment == Vector3(0,1,1): return base
	return Color.from_hsv(fposmod(base.h+adjustment.x/360.0,1.0),clampf(base.s*adjustment.y,0,1),base.v*adjustment.z)

func snapshot(name: String, night: bool) -> Dictionary:
	return {"version":1,"name":name.strip_edges(),"night":night,"values":values.duplicate(true)}

func validate_snapshot(data: Variant) -> Dictionary:
	error = ""
	if not data is Dictionary:
		error = "预设文件不是有效对象"
		return {}
	if data.get("version") != 1 or not data.get("name") is String or not data.get("night") is bool or not data.get("values") is Dictionary:
		error = "预设格式或版本不支持"
		return {}
	var name: String = data.name.strip_edges()
	if name.is_empty() or name.length()>80 or name != name.validate_filename() or name in [".",".."]:
		error = "预设名称需为 1–80 个有效文件名字符"
		return {}
	var merged := defaults.duplicate(true)
	for id in data.values:
		if not valid_value(str(id),data.values[id]): return {}
		merged[id] = data.values[id]
	return {"version":1,"name":name,"night":data.night,"values":merged}

func apply_snapshot(data: Variant) -> Dictionary:
	var checked := validate_snapshot(data)
	if checked.is_empty(): return {}
	values = checked["values"].duplicate(true)
	changed.emit(PackedStringArray(values.keys()),"preset")
	return checked

func read_file(path: String) -> Dictionary:
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null:
		error = "无法读取预设文件"
		return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		error = "预设文件内容损坏，未应用"
		return {}
	return validate_snapshot(parser.data)

func _write(path: String, data: Dictionary) -> bool:
	var destination := ProjectSettings.globalize_path(path)
	if DirAccess.make_dir_recursive_absolute(destination.get_base_dir()) != OK:
		error = "无法创建预设目录"
		return false
	var temporary := destination + ".tmp"
	var file := FileAccess.open(temporary,FileAccess.WRITE)
	if file == null:
		error = "无法保存预设"
		return false
	file.store_string(JSON.stringify(data,"  ")+"\n")
	file.close()
	if DirAccess.rename_absolute(temporary,destination) != OK:
		DirAccess.remove_absolute(temporary)
		error = "无法完成预设保存"
		return false
	return true

func save_named(name: String, night: bool) -> Dictionary:
	var data := validate_snapshot(snapshot(name,night))
	if data.is_empty(): return {}
	if not _write(folder.path_join(data.name.validate_filename()+".json"),data): return {}
	return data

func list_presets() -> Array:
	var result: Array = []
	var directory := DirAccess.open(folder)
	if directory == null: return result
	for filename in directory.get_files():
		if filename.ends_with(".json"):
			var data := read_file(folder.path_join(filename))
			if not data.is_empty(): result.append({"name":data.name,"path":folder.path_join(filename)})
	result.sort_custom(func(a,b): return a.name.naturalnocasecmp_to(b.name)<0)
	return result

func export_file(path: String, name: String, night: bool) -> bool:
	var data := validate_snapshot(snapshot(name,night))
	return not data.is_empty() and _write(path,data)

func import_file(path: String) -> Dictionary:
	var data := read_file(path)
	if data.is_empty(): return {}
	# Persist before applying: an I/O error cannot partially change the scene.
	if not _write(folder.path_join(data.name.validate_filename()+".json"),data): return {}
	return apply_snapshot(data)
