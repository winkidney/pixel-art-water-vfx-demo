extends Control

const WORLD := Vector2(480, 320)
const START := Vector2(425, 251)
const TOUR := [Vector2(406,244), Vector2(374,225), Vector2(333,207), Vector2(286,188), Vector2(240,164), Vector2(262,141), Vector2(313,153), Vector2(333,187), Vector2(381,223), START]
const INK := Color("dce9de")
const MUTED := Color("819b94")
const MINT := Color("98cbb0")

var parameters
var parameter_panel
var applied_values := {}
var phase_offsets := {}
var ripple_offsets := PackedFloat32Array()
var legacy := false
var night := false
var start_point := START
var tour_points := TOUR.duplicate()
var background: Sprite2D
var waterfall: ColorRect
var waterfall_material: ShaderMaterial
var occlusion_material: ShaderMaterial
var foreground: ColorRect
var viewport: SubViewport
var world_root: Node2D
var display: TextureRect
var water: ColorRect
var water_material: ShaderMaterial
var character: Sprite2D
var reflection: Sprite2D
var character_material: ShaderMaterial
var reflection_material: ShaderMaterial
var shadow: Polygon2D
var bathymetry: Image
var atlas: Array[AtlasTexture] = []
var player := START
var target := START
var clock := 0.0
var level := 0.0
var immersion := 0.0
var frozen := false
var auto_tour := true
var tour_index := 0
var moving := false
var ripple_timer := 0.0
var ripple_cursor := 0
var ripples := PackedVector4Array()
var last_direction := 0
var state_label: Label
var depth_label: Label
var performance_label: Label
var depth_bar: ProgressBar
var tour_button: Button
var pause_button: Button
var toggles: Dictionary = {}
var screenshot_counter := 0
var elapsed := 0.0
var view_mode := 0
var tide_slider: HSlider
var waves_slider: HSlider
var hint_label: Label
var navigation := AStarGrid2D.new()
var route := PackedVector2Array()
var route_goal := Vector2.INF

func _ready() -> void:
	Engine.max_fps = 60
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var ui_theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Noto Sans CJK SC", "Noto Sans", "sans-serif"])
	ui_theme.default_font = font
	ui_theme.default_font_size = 14
	theme = ui_theme
	legacy = "--legacy" in OS.get_cmdline_user_args()
	if not legacy:
		start_point = Vector2(62,155)
		tour_points = [Vector2(103,192),Vector2(140,215),Vector2(181,207),Vector2(236,170),Vector2(288,152),Vector2(309,201),Vector2(213,234),Vector2(139,225),Vector2(91,210),start_point]
	player = start_point
	target = start_point
	parameters = preload("res://scripts/parameter_store.gd").new()
	applied_values = parameters.values.duplicate(true)
	ripple_offsets.resize(16)
	ripple_offsets.fill(0)
	_build_world()
	parameters.changed.connect(_parameters_changed)
	_parameters_changed(PackedStringArray(parameters.values.keys()),"init")
	_build_navigation()
	_build_ui()
	for i in 16:
		ripples.append(Vector4(0,0,-1000,0))
	_refresh_character(Vector2.ZERO)

func _build_world() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(WORLD)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(viewport)
	world_root = Node2D.new()
	viewport.add_child(world_root)
	background = Sprite2D.new()
	background.texture = load("res://assets/grotto-imagegen.png" if legacy else "res://assets/stone-basin/day-imagegen.png")
	background.centered = false
	background.scale = WORLD / background.texture.get_size()
	world_root.add_child(background)
	var map_texture: Texture2D = load("res://assets/bathymetry.png" if legacy else "res://assets/stone-basin/bathymetry.png")
	bathymetry = map_texture.get_image()
	water = ColorRect.new()
	water.size = WORLD
	water.mouse_filter = Control.MOUSE_FILTER_IGNORE
	water_material = ShaderMaterial.new()
	water_material.shader = load("res://shaders/water.gdshader")
	water_material.set_shader_parameter("seabed", background.texture)
	water_material.set_shader_parameter("bathymetry", map_texture)
	water_material.set_shader_parameter("basin_scene",not legacy)
	water.material = water_material
	world_root.add_child(water)
	if not legacy:
		waterfall = ColorRect.new()
		waterfall.size = WORLD
		waterfall_material = ShaderMaterial.new()
		waterfall_material.shader = load("res://shaders/waterfall.gdshader")
		waterfall_material.set_shader_parameter("scene_plate", background.texture)
		waterfall_material.set_shader_parameter("fall_mask",load("res://assets/stone-basin/waterfall-mask.png"))
		waterfall.material = waterfall_material
		world_root.add_child(waterfall)
	_load_atlas()
	reflection = Sprite2D.new()
	reflection_material = ShaderMaterial.new()
	reflection_material.shader = load("res://shaders/reflection.gdshader")
	reflection_material.set_shader_parameter("bathymetry", map_texture)
	reflection.material = reflection_material
	world_root.add_child(reflection)
	shadow = Polygon2D.new()
	var ellipse := PackedVector2Array()
	for i in 24:
		var angle := i * TAU / 24
		ellipse.append(Vector2(cos(angle)*8, sin(angle)*2.8))
	shadow.polygon = ellipse
	shadow.color = Color(0.035, 0.09, 0.12, .22)
	world_root.add_child(shadow)
	character = Sprite2D.new()
	character_material = ShaderMaterial.new()
	character_material.shader = load("res://shaders/character.gdshader")
	character.material = character_material
	world_root.add_child(character)
	if not legacy:
		foreground = ColorRect.new()
		foreground.size = WORLD
		occlusion_material = ShaderMaterial.new()
		occlusion_material.shader = load("res://shaders/occlusion.gdshader")
		occlusion_material.set_shader_parameter("scene_plate",background.texture)
		occlusion_material.set_shader_parameter("occlusion_map",load("res://assets/stone-basin/occlusion-mask.png"))
		foreground.material = occlusion_material
		world_root.add_child(foreground)

func _build_navigation() -> void:
	navigation.region = Rect2i(0,0,240,160)
	navigation.cell_size = Vector2(2,2)
	navigation.offset = Vector2(1,1)
	navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	navigation.update()
	for y in 160:
		for x in 240:
			var clear := true
			for oy in [-1,0,1]:
				for ox in [-1,0,1]:
					clear = clear and is_walkable(Vector2(x*2+1+ox,y*2+1+oy))
			navigation.set_point_solid(Vector2i(x,y),not clear)

func _nearest_navigation_id(point: Vector2) -> Vector2i:
	var cell := Vector2i(point/2)
	for radius in 8:
		for y in range(-radius,radius+1):
			for x in range(-radius,radius+1):
				var candidate := cell + Vector2i(x,y)
				if navigation.is_in_boundsv(candidate) and not navigation.is_point_solid(candidate): return candidate
	return cell

func _clear_line(a: Vector2, b: Vector2) -> bool:
	var steps := ceili(a.distance_to(b))
	for i in range(1,steps+1):
		if not is_walkable(a.lerp(b,float(i)/steps)): return false
	return true

func _route_direction(goal: Vector2) -> Vector2:
	if _clear_line(player,goal):
		route.clear()
		route_goal = Vector2.INF
		return goal-player
	if route_goal != goal:
		route_goal = goal
		route = navigation.get_point_path(_nearest_navigation_id(player),_nearest_navigation_id(goal))
	while not route.is_empty() and player.distance_to(route[0]) < 1.5:
		route.remove_at(0)
	return route[0]-player if not route.is_empty() else Vector2.ZERO

func _load_atlas() -> void:
	var texture: Texture2D = load("res://assets/adventurer-imagegen.png")
	var image := texture.get_image()
	var cell := image.get_size() / 2
	for i in 4:
		var origin := Vector2i((i % 2) * cell.x, (i / 2) * cell.y)
		var crop := image.get_region(Rect2i(origin, cell))
		# ImageGen alpha can contain nearly invisible stray pixels. Fit bounds to
		# actual opaque artwork rather than letting those pixels shrink the sprite.
		var minimum := cell
		var maximum := Vector2i.ZERO
		for y in cell.y:
			for x in cell.x:
				if crop.get_pixel(x,y).a > .25:
					minimum = minimum.min(Vector2i(x,y))
					maximum = maximum.max(Vector2i(x,y))
		var used := Rect2i(minimum, maximum-minimum+Vector2i.ONE)
		var frame := AtlasTexture.new()
		frame.atlas = texture
		frame.region = Rect2(origin + used.position, used.size)
		frame.filter_clip = true
		atlas.append(frame)

func _label(text: String, pos: Vector2, font_size: int, color := INK) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	return label

func _panel(rect: Rect2, color: Color, border := Color("293f3d")) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	return panel

func _button(text: String, pos: Vector2, dimensions: Vector2, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.position = pos
	button.size = dimensions
	button.pressed.connect(action)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1d3430")
	style.border_color = Color("456258")
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	button.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color("2a4940")
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_color_override("font_color", INK)
	add_child(button)
	return button

func _build_ui() -> void:
	_panel(Rect2(0,0,1440,800), Color("0c171b"), Color("0c171b"))
	_label("FIELD STUDY    /    001", Vector2(25,17), 11, MINT)
	_label("潮汐洞窟" if legacy else "石桥清潭", Vector2(23,34), 30)
	_label("PIXEL WATER     ·     白天 / 夜晚", Vector2(180,49), 12, MUTED)
	_label("GODOT 4    /    IMAGEGEN ART", Vector2(1012,25), 11, MUTED)
	_label("480 × 320  ·  2× 像素网格", Vector2(1012,47), 13, INK)
	_panel(Rect2(23,95,962,642), Color("14282a"))
	display = TextureRect.new()
	display.texture = viewport.get_texture()
	display.position = Vector2(24,96)
	display.size = WORLD * 2
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.stretch_mode = TextureRect.STRETCH_SCALE
	display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	display.mouse_default_cursor_shape = Control.CURSOR_CROSS
	display.gui_input.connect(_scene_input)
	add_child(display)
	parameter_panel = preload("res://scripts/parameter_panel.gd").new()
	add_child(parameter_panel)
	parameter_panel.setup(parameters,self)
	_label("WASD / 方向键 移动    ·    点击前往    ·    空格 溅水    ·    Tab 原图", Vector2(25,752), 12, MUTED)
	_label("P 冻结    ·    R 重置    ·    F12 截图", Vector2(25,776), 10, MUTED)
	state_label = _label("", Vector2(25,108), 12, INK)
	state_label.add_theme_color_override("font_shadow_color", Color("112329"))
	state_label.add_theme_constant_override("shadow_offset_x", 1)
	state_label.add_theme_constant_override("shadow_offset_y", 1)
	depth_label = _label("", Vector2(720,752), 12, INK)
	performance_label = _label("", Vector2(1012,755), 11, MUTED)
	depth_bar = ProgressBar.new()
	depth_bar.position = Vector2(888,758)
	depth_bar.size = Vector2(96,5)
	depth_bar.max_value = 1
	depth_bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = MINT
	var track := StyleBoxFlat.new()
	track.bg_color = Color("25423c")
	depth_bar.add_theme_stylebox_override("fill",fill)
	depth_bar.add_theme_stylebox_override("background",track)
	add_child(depth_bar)
	hint_label = _label("", Vector2(720,776), 10, MINT)

func _slider(pos: Vector2, minimum: float, maximum: float, initial: float, increment: float) -> HSlider:
	var slider := HSlider.new()
	slider.position = pos
	slider.focus_mode = Control.FOCUS_NONE
	slider.size = Vector2(212,20)
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = increment
	slider.value = initial
	add_child(slider)
	return slider

func _scene_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var focus := get_viewport().gui_get_focus_owner()
		if focus: focus.release_focus()
		var where: Vector2 = event.position / 2.0
		if is_water(where):
			add_ripple(where, value("click_amplitude"))
		if is_walkable(where):
			target = where
			auto_tour = false
			_update_tour_button()

func _unhandled_key_input(event: InputEvent) -> void:
	if _editing_parameter(): return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_SPACE: add_ripple(_surface_point(), value("splash_amplitude"))
		KEY_P: toggle_pause()
		KEY_R: reset_study()
		KEY_TAB: set_original_view(view_mode != 2)
		KEY_F12: save_screenshot()

func _process(delta: float) -> void:
	elapsed += delta
	if not frozen:
		clock += delta
		_move_player(delta)
		_refresh_character(Vector2.ZERO)
	pause_button.text = "继续时间" if frozen else "冻结时间"
	water_material.set_shader_parameter("clock", clock)
	water_material.set_shader_parameter("ripples", ripples)
	water_material.set_shader_parameter("water_level", level)
	character_material.set_shader_parameter("clock", clock)
	reflection_material.set_shader_parameter("clock", clock)
	_sync_motion()
	water_material.set_shader_parameter("ripple_offsets",ripple_offsets)
	if waterfall_material: waterfall_material.set_shader_parameter("clock",clock)
	if occlusion_material: occlusion_material.set_shader_parameter("foot_y",player.y)
	var location := "沙滩"
	if immersion > .04:
		location = "浅滩" if immersion < .33 else ("涉水" if immersion < .66 else "游泳")
	state_label.text = "  %s  ·  %s  " % [location, "自动漫游" if auto_tour else "自由探索"]
	depth_label.text = "水深  %02d%%" % roundi(immersion*100)
	depth_bar.value = immersion
	performance_label.text = "时间已冻结 · 固定采样" if frozen else "%d FPS    ·    实时运行" % Engine.get_frames_per_second()
	hint_label.text = ["完整效果", "水深可视化", "ImageGen 原始底图"][view_mode]

func _move_player(delta: float) -> void:
	var direction := Vector2.ZERO
	if _editing_parameter():
		moving = false
		return
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): direction.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): direction.y += 1
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): direction.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): direction.x += 1
	if direction != Vector2.ZERO:
		auto_tour = false
		target = player
		_update_tour_button()
	elif auto_tour:
		target = tour_points[tour_index]
		if player.distance_to(target) < 1.5:
			tour_index = (tour_index + 1) % tour_points.size()
			target = tour_points[tour_index]
		direction = _route_direction(target)
	elif player.distance_to(target) > 1.0:
		direction = _route_direction(target)
	moving = direction.length() > .1
	if moving:
		var speed := lerpf(28,20,immersion)
		var step := direction.normalized() * minf(speed*delta,direction.length())
		var next := player + step
		if is_walkable(next): player = next
		else:
			var slide_x := player + Vector2(step.x,0)
			var slide_y := player + Vector2(0,step.y)
			if is_walkable(slide_x): player = slide_x
			elif is_walkable(slide_y): player = slide_y
			else: target = player
		_refresh_character(direction)
		ripple_timer -= delta
		if ripple_timer <= 0 and is_water(player):
			add_ripple(_surface_point(), value("move_amplitude"))
			ripple_timer = value("move_interval")

func _refresh_character(direction: Vector2) -> void:
	var depth := sample_map(player).b
	immersion = clampf(depth * value("immersion_scale") + (level*value("tide_influence") if is_water(player) else 0),0, .96) if is_water(player) else 0.0
	if absf(direction.x) > absf(direction.y):
		last_direction = 1 if direction.x > 0 else 3
	elif direction.length() > .1:
		last_direction = 0 if direction.y > 0 else 2
	var frame := atlas[last_direction]
	var character_height := value("character_height")
	var scale_factor := character_height / frame.get_height()
	var bob := sin(motion_phase("move_bob_speed") if moving and immersion < .3 else motion_phase("idle_bob_speed")) * (value("move_bob") if moving else value("idle_bob"))
	var surface_shift := immersion * value("sink_offset")
	character.texture = frame
	character.scale = Vector2.ONE * scale_factor
	character.position = (player + Vector2(0,-character_height*.5+surface_shift+bob)).round()
	character.rotation = sin(motion_phase("rotation_speed"))*value("rotation_amplitude") if moving and immersion < .3 else 0.0
	character_material.set_shader_parameter("immersion", immersion)
	character_material.set_shader_parameter("sprite_rect", Vector4(frame.region.position.x,frame.region.position.y,frame.region.size.x,frame.region.size.y))
	character_material.set_shader_parameter("world_texel", Vector2.ONE / frame.atlas.get_size() / scale_factor)
	shadow.position = player.round()
	shadow.color.a = value("shadow_alpha") * (1.0 - immersion*value("shadow_fade"))
	reflection.texture = frame
	reflection.flip_v = true
	reflection.scale = Vector2(scale_factor, scale_factor*value("reflection_scale"))
	reflection.position = (player + Vector2(0,character_height*value("reflection_scale")*.5)).round()
	reflection_material.set_shader_parameter("foot", player)
	reflection_material.set_shader_parameter("sprite_rect", Vector4(frame.region.position.x,frame.region.position.y,frame.region.size.x,frame.region.size.y))
	reflection_material.set_shader_parameter("dimensions", Vector2(frame.get_width()*scale_factor,character_height*value("reflection_scale")))
	reflection_material.set_shader_parameter("opacity", value("reflection_alpha")*(1.0-immersion*value("reflection_fade")))

func _surface_point() -> Vector2:
	return player + Vector2(0,-value("character_height")*immersion*value("waterline_height")+immersion*value("sink_offset"))

func sample_map(where: Vector2) -> Color:
	if where.x < 0 or where.y < 0 or where.x >= WORLD.x or where.y >= WORLD.y: return Color(0,0,0,0)
	return bathymetry.get_pixel(int(where.x), int(where.y))

func is_water(where: Vector2) -> bool:
	return sample_map(where).r > .5

func is_walkable(where: Vector2) -> bool:
	return sample_map(where).a > .5

func add_ripple(where: Vector2, amplitude: float) -> void:
	if not is_water(where): return
	ripples[ripple_cursor] = Vector4(where.x, where.y, clock, amplitude)
	ripple_offsets[ripple_cursor] = 0
	ripple_cursor = (ripple_cursor + 1) % 16

func set_effect(parameter: String, enabled: bool) -> void:
	parameters.set_value(parameter,enabled)

func _apply_effect(parameter: String, enabled: bool) -> void:
	match parameter:
		"waterfall_enabled":
			if waterfall: waterfall.visible = enabled and view_mode != 2
			water_material.set_shader_parameter(parameter,enabled)
		"reflection_enabled": reflection.visible = enabled and view_mode != 2
		"submersion_enabled": character_material.set_shader_parameter(parameter,enabled)
		_: water_material.set_shader_parameter(parameter,enabled)
	if toggles.has(parameter): toggles[parameter].set_pressed_no_signal(enabled)

func toggle_tour() -> void:
	auto_tour = not auto_tour
	if auto_tour:
		var closest := INF
		for i in tour_points.size():
			var distance := player.distance_to(tour_points[i])
			if distance < closest:
				closest = distance
				tour_index = i
	_update_tour_button()

func _update_tour_button() -> void:
	if tour_button: tour_button.text = "暂停自动漫游" if auto_tour else "开始自动漫游"

func toggle_pause() -> void:
	frozen = not frozen

func cycle_view() -> void:
	var next_view := (view_mode+1)%2
	set_original_view(false)
	view_mode = next_view
	water_material.set_shader_parameter("debug_depth", view_mode==1)

func set_original_view(enabled: bool) -> void:
	view_mode = 2 if enabled else 0
	water.visible = not enabled
	character.visible = not enabled
	shadow.visible = not enabled
	reflection.visible = not enabled and (not toggles.has("reflection_enabled") or toggles["reflection_enabled"].button_pressed)
	if waterfall: waterfall.visible = not enabled and toggles["waterfall_enabled"].button_pressed
	water_material.set_shader_parameter("debug_depth", false)

func choose_time(is_night: bool) -> void:
	if legacy: return
	night = is_night
	background.texture = load("res://assets/stone-basin/night-imagegen.png" if night else "res://assets/stone-basin/day-imagegen.png")
	water_material.set_shader_parameter("seabed",background.texture)
	water_material.set_shader_parameter("night",float(night))
	waterfall_material.set_shader_parameter("scene_plate",background.texture)
	waterfall_material.set_shader_parameter("night",float(night))
	occlusion_material.set_shader_parameter("scene_plate",background.texture)
	character_material.set_shader_parameter("night",float(night))
	if parameter_panel: parameter_panel.update_context()

func reset_study() -> void:
	player = start_point
	target = start_point
	clock = 0
	phase_offsets.clear()
	ripple_offsets.fill(0)
	ripple_timer = 0
	moving = false
	route.clear()
	route_goal = Vector2.INF
	tour_index = 0
	auto_tour = true
	frozen = false
	for i in 16: ripples[i] = Vector4(0,0,-1000,0)
	set_original_view(false)
	_refresh_character(Vector2.ZERO)
	_update_tour_button()

func save_screenshot() -> void:
	await RenderingServer.frame_post_draw
	screenshot_counter += 1
	var folder := "res://captures"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	get_viewport().get_texture().get_image().save_png("%s/capture-%03d.png" % [folder,screenshot_counter])

func value(id: String) -> float:
	return float(parameters.values[id])

func _editing_parameter() -> bool:
	return get_viewport().gui_get_focus_owner() is LineEdit or (parameter_panel != null and parameter_panel.file_dialog.visible)

func motion_phase(id: String) -> float:
	return clock*value(id)+float(phase_offsets.get(id,0.0))

func _material(target_name: String) -> ShaderMaterial:
	match target_name:
		"water": return water_material
		"fall": return waterfall_material
		"character": return character_material
		"reflection": return reflection_material
	return null

func _parameters_changed(ids: PackedStringArray, reason: String) -> void:
	for wave in ["wave1_speed","wave2_speed"]:
		if not wave in ids and not "wave_axis_speed" in ids: continue
		var key: String = wave+"_axis"
		var old_rate: float = float(applied_values[wave])*float(applied_values.wave_axis_speed)
		var rate: float = value(wave)*value("wave_axis_speed")
		if reason == "edit": phase_offsets[key] = float(phase_offsets.get(key,0.0))+clock*(old_rate-rate)
		else: phase_offsets[key] = 0.0
	if "ripple_speed" in ids:
		for i in ripples.size():
			if reason == "edit": ripple_offsets[i] += maxf(0,clock-ripples[i].z)*(float(applied_values.ripple_speed)-value("ripple_speed"))
			else: ripple_offsets[i] = 0.0
	for id in ids:
		var definition: Dictionary = parameters.by_id[id]
		if definition.motion:
			if reason == "edit": phase_offsets[id] = float(phase_offsets.get(id,0.0))+clock*(float(applied_values[id])-value(id))
			else: phase_offsets[id] = 0.0
		var material := _material(definition.target)
		if definition.get("type","") == "bool": _apply_effect(id,parameters.values[id])
		elif definition.has("color"):
			if material: material.set_shader_parameter(definition.color+"_grade",parameters.grade(definition.color))
		elif material and not definition.motion: material.set_shader_parameter(id,value(id))
		applied_values[id] = parameters.values[id]
	level = value("water_level")
	if not atlas.is_empty(): _refresh_character(Vector2.ZERO)
	_sync_motion()

func _sync_motion() -> void:
	for definition in parameters.definitions:
		if definition.motion:
			var material := _material(definition.target)
			if material:
				material.set_shader_parameter(definition.id,value(definition.id))
				material.set_shader_parameter("offset_"+definition.id,float(phase_offsets.get(definition.id,0.0)))
	for wave in ["wave1_speed","wave2_speed"]:
		water_material.set_shader_parameter("offset_"+wave+"_axis",float(phase_offsets.get(wave+"_axis",0.0)))
