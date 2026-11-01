extends PanelContainer

var store
var study
var editors := {}
var group_boxes := {}
var color_swatches := {}
var search: LineEdit
var advanced: CheckButton
var name_input: LineEdit
var choices: OptionButton
var message: Label
var dirty_label: Label
var day_button: Button
var night_button: Button
var file_dialog: FileDialog
var saved_values := {}
var saved_night := false
var import_mode := true

func setup(model, scene) -> void:
	store = model
	study = scene
	saved_values = store.values.duplicate(true)
	position = Vector2(1008,95)
	size = Vector2(408,642)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("112125")
	style.border_color = Color("314842")
	style.set_border_width_all(1)
	add_theme_stylebox_override("panel",style)
	var margin := MarginContainer.new()
	for side in ["left","top","right","bottom"]: margin.add_theme_constant_override("margin_"+side,12)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",6)
	margin.add_child(column)
	var title := HBoxContainer.new()
	column.add_child(title)
	label(title,"水体调参",19).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dirty_label = label(title,"默认效果",11,Color("98cbb0"))
	var times := HBoxContainer.new()
	column.add_child(times)
	day_button = button(times,"白天",func(): study.choose_time(false))
	night_button = button(times,"夜晚",func(): study.choose_time(true))
	day_button.toggle_mode = true
	night_button.toggle_mode = true
	day_button.disabled = study.legacy
	night_button.disabled = study.legacy
	var preset := HBoxContainer.new()
	column.add_child(preset)
	name_input = LineEdit.new()
	name_input.placeholder_text = "预设名称…"
	name_input.max_length = 80
	name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_input.custom_minimum_size.x = 140
	preset.add_child(name_input)
	choices = OptionButton.new()
	choices.fit_to_longest_item = false
	choices.clip_text = true
	choices.custom_minimum_size.x = 160
	choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preset.add_child(choices)
	var files := HBoxContainer.new()
	column.add_child(files)
	button(files,"保存",save_current)
	button(files,"加载",load_selected)
	button(files,"导入",open_import)
	button(files,"导出",open_export)
	message = label(column,"手动保存 · 白天与夜晚共用调整",11,Color("819b94"))
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.custom_minimum_size.y = 29
	var filter_row := HBoxContainer.new()
	column.add_child(filter_row)
	search = LineEdit.new()
	search.placeholder_text = "搜索参数…"
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filter_row.add_child(search)
	search.text_changed.connect(func(_text): refresh_filters())
	advanced = CheckButton.new()
	advanced.text = "高级"
	advanced.tooltip_text = "显示高级参数与相对调色"
	advanced.focus_mode = Control.FOCUS_NONE
	filter_row.add_child(advanced)
	advanced.toggled.connect(func(_value): refresh_filters())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = 160
	column.add_child(scroll)
	var groups := VBoxContainer.new()
	groups.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	groups.add_theme_constant_override("separation",7)
	scroll.add_child(groups)
	for definition in store.definitions:
		if group_boxes.has(definition.group): continue
		var container := VBoxContainer.new()
		groups.add_child(container)
		var header := HBoxContainer.new()
		container.add_child(header)
		var toggle := button(header,definition.group_label,func(): refresh_filters())
		toggle.toggle_mode = true
		toggle.set_pressed_no_signal(definition.group == "water")
		var reset := button(header,"↺",func(): store.restore_defaults(definition.group))
		reset.size_flags_horizontal = Control.SIZE_SHRINK_END
		reset.custom_minimum_size.x = 30
		reset.tooltip_text = "恢复本组全部参数默认值"
		var body := VBoxContainer.new()
		body.add_theme_constant_override("separation",7)
		container.add_child(body)
		group_boxes[definition.group] = {"container":container,"toggle":toggle,"body":body,"rows":[]}
	for definition in store.definitions:
		add_parameter(definition)
	var transport := HBoxContainer.new()
	column.add_child(transport)
	study.tour_button = button(transport,"暂停自动漫游",study.toggle_tour)
	study.pause_button = button(transport,"冻结时间",study.toggle_pause)
	button(transport,"原图",func(): study.set_original_view(study.view_mode != 2))
	var actions := HBoxContainer.new()
	column.add_child(actions)
	button(actions,"恢复参数",func(): store.restore_defaults())
	button(actions,"重置场景",study.reset_study)
	button(actions,"深度图",study.cycle_view)
	file_dialog = FileDialog.new()
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.size = Vector2i(760,520)
	file_dialog.file_selected.connect(import_path)
	file_dialog.dir_selected.connect(export_directory)
	add_child(file_dialog)
	store.changed.connect(_on_changed)
	refresh_presets()
	refresh_filters()
	sync_all()

func label(parent: Node, text: String, font_size := 13, color := Color("dce9de")) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",color)
	parent.add_child(node)
	return node

func button(parent: Node, text: String, action: Callable) -> Button:
	var node := Button.new()
	node.text = text
	node.focus_mode = Control.FOCUS_NONE
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.custom_minimum_size.y = 29
	node.pressed.connect(action)
	parent.add_child(node)
	return node

func number(value: float) -> String:
	return String.num(value,4)

func add_color_reference(item: Dictionary) -> void:
	var row := HBoxContainer.new()
	label(row,item.label+" 参考色",11,Color("819b94")).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var base := ColorRect.new()
	base.custom_minimum_size = Vector2(25,16)
	row.add_child(base)
	label(row,"→",12)
	var result := ColorRect.new()
	result.custom_minimum_size = Vector2(25,16)
	row.add_child(result)
	group_boxes[item.group].body.add_child(row)
	group_boxes[item.group].rows.append({"node":row,"common":false,"text":item.label+" 颜色 调色"})
	color_swatches[item.id] = [base,result]

func add_parameter(definition: Dictionary) -> void:
	if definition.has("color") and not color_swatches.has(definition.color):
		for item in store.colors:
			if item.id == definition.color: add_color_reference(item)
	var box: VBoxContainer = group_boxes[definition.group].body
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation",2)
	box.add_child(row)
	group_boxes[definition.group].rows.append({"node":row,"common":definition.common,"text":definition.label+" "+definition.id+(" 颜色 调色" if definition.has("color") else "")})
	if definition.get("type","") == "bool":
		var line := HBoxContainer.new()
		row.add_child(line)
		var check := CheckButton.new()
		check.text = definition.label
		check.focus_mode = Control.FOCUS_NONE
		check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		check.set_pressed_no_signal(store.values[definition.id])
		line.add_child(check)
		label(line,"默认 开",10,Color("819b94"))
		button(line,"↺",func(): store.restore_defaults("",definition.id)).size_flags_horizontal = Control.SIZE_SHRINK_END
		check.toggled.connect(func(value): store.set_value(definition.id,value))
		editors[definition.id] = {"check":check}
		study.toggles[definition.id] = check
		return
	label(row,definition.label+ ("  ["+definition.unit+"]" if not definition.unit.is_empty() else ""),12)
	var line := HBoxContainer.new()
	row.add_child(line)
	var slider := HSlider.new()
	slider.focus_mode = Control.FOCUS_NONE
	slider.min_value = definition.min
	slider.max_value = definition.max
	slider.step = definition.step
	slider.value = definition.default
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.y = 24
	line.add_child(slider)
	var input := LineEdit.new()
	input.text = number(store.values[definition.id])
	input.custom_minimum_size.x = 76
	input.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	input.tooltip_text = "输入数值后回车；范围 %s–%s" % [number(definition.min),number(definition.max)]
	line.add_child(input)
	var reset := button(line,"↺",func(): store.restore_defaults("",definition.id))
	reset.custom_minimum_size.x = 28
	reset.size_flags_horizontal = Control.SIZE_SHRINK_END
	reset.tooltip_text = "恢复默认 "+number(definition.default)
	label(row,"默认 %s   ·   %s 至 %s" % [number(definition.default),number(definition.min),number(definition.max)],10,Color("819b94"))
	slider.value_changed.connect(func(value): store.set_value(definition.id,value))
	input.text_submitted.connect(func(text):
		submit_number(definition.id,text)
		input.release_focus())
	input.focus_exited.connect(func():
		if input.text != number(store.values[definition.id]): submit_number(definition.id,input.text))
	editors[definition.id] = {"slider":slider,"input":input}
	if definition.id == "strength": study.waves_slider = slider
	if definition.id == "water_level": study.tide_slider = slider

func submit_number(id: String, text: String) -> void:
	if not text.is_valid_float() or not store.set_value(id,text.to_float()):
		notify("%s 无效，当前仍为 %s" % [store.by_id[id].label,number(store.values[id])],true)
	editors[id].input.text = number(store.values[id])

func refresh_filters() -> void:
	var query := search.text.strip_edges().to_lower()
	for key in group_boxes:
		var group: Dictionary = group_boxes[key]
		var any_visible := false
		for row in group.rows:
			var matches: bool = query.is_empty() or query in row.text.to_lower() or query in group.toggle.text.to_lower()
			row.node.visible = matches and (advanced.button_pressed or row.common or not query.is_empty())
			any_visible = any_visible or row.node.visible
		group.container.visible = any_visible
		group.body.visible = group.toggle.button_pressed or not query.is_empty()

func _on_changed(ids: PackedStringArray, _reason: String) -> void:
	for id in ids:
		if not editors.has(id): continue
		if editors[id].has("check"): editors[id].check.set_pressed_no_signal(store.values[id])
		else:
			editors[id].slider.set_value_no_signal(store.values[id])
			editors[id].input.text = number(store.values[id])
	update_context()
	if _reason == "edit" and not ids.is_empty(): notify("实时调整："+store.by_id[ids[0]].label)
	elif _reason == "defaults": notify("已恢复参数默认，场景状态保留")

func sync_all() -> void:
	_on_changed(PackedStringArray(store.values.keys()),"")

func update_context() -> void:
	day_button.set_pressed_no_signal(not study.night)
	night_button.set_pressed_no_signal(study.night)
	dirty_label.text = "未保存修改" if store.values != saved_values or study.night != saved_night else "已保存 / 默认"
	for id in color_swatches:
		color_swatches[id][0].color = store.base_color(id,study.night)
		color_swatches[id][1].color = store.graded_color(id,study.night)

func notify(text: String, failed := false) -> void:
	message.text = text
	message.add_theme_color_override("font_color",Color("e4a58b") if failed else Color("98cbb0"))

func refresh_presets() -> void:
	choices.clear()
	choices.add_item("选择已保存预设")
	for item in store.list_presets():
		choices.add_item(item.name)
		choices.set_item_metadata(choices.item_count-1,item.path)

func save_current() -> void:
	var data: Dictionary = store.save_named(name_input.text,study.night)
	if data.is_empty():
		notify(store.error,true)
		return
	saved_values = store.values.duplicate(true)
	saved_night = study.night
	refresh_presets()
	update_context()
	notify("已保存："+data.name)

func load_selected() -> void:
	if choices.selected <= 0:
		notify("先选择一个预设",true)
		return
	var data: Dictionary = store.read_file(choices.get_item_metadata(choices.selected))
	if data.is_empty():
		notify(store.error,true)
		return
	accept_preset(store.apply_snapshot(data))

func accept_preset(data: Dictionary) -> void:
	if data.is_empty():
		notify(store.error,true)
		return
	study.choose_time(data.night)
	name_input.text = data.name
	saved_values = store.values.duplicate(true)
	saved_night = study.night
	update_context()
	notify("已加载："+data.name)

func open_import() -> void:
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.filters = PackedStringArray(["*.json ; 水体预设"])
	file_dialog.title = "导入水体预设"
	file_dialog.popup_centered()

func import_path(path: String) -> void:
	var data: Dictionary = store.import_file(path)
	if data.is_empty():
		notify(store.error,true)
		return
	refresh_presets()
	accept_preset(data)

func open_export() -> void:
	if name_input.text.strip_edges().is_empty():
		notify("先输入预设名称，再选择导出目录",true)
		return
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	file_dialog.filters = PackedStringArray()
	file_dialog.title = "选择导出目录："+name_input.text.validate_filename()+".json"
	file_dialog.popup_centered()

func export_directory(path: String) -> void:
	var filename := name_input.text.strip_edges().validate_filename()+".json"
	if store.export_file(path.path_join(filename),name_input.text,study.night): notify("已导出："+filename)
	else: notify(store.error,true)
