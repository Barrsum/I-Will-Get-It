class_name PauseMenu
extends CanvasLayer
## Esc / Start pause menu: Resume, Settings, Restart, Quit, plus a controls reference.
## Settings rows are generated from SETTINGS_SCHEMA and bound to the Settings autoload.

const BLUR_SHADER: Shader = preload("res://assets/shaders/ui_blur.gdshader")

const SETTINGS_SCHEMA: Array[Dictionary] = [
	{"section": "CONTROLS"},
	{"key": &"mouse_sensitivity", "label": "Mouse sensitivity", "min": 0.1, "max": 3.0, "step": 0.05, "format": "%.2f"},
	{"key": &"controller_sensitivity", "label": "Controller look sensitivity", "min": 0.2, "max": 3.0, "step": 0.05, "format": "%.2f"},
	{"key": &"invert_look_y", "label": "Invert look (Y axis)"},
	{"key": &"sprint_by_default", "label": "Sprint by default"},
	{"key": &"toggle_crouch", "label": "Toggle crouch (off = hold)"},
	{"section": "VIDEO"},
	{"key": &"fov", "label": "Field of view", "min": 70.0, "max": 100.0, "step": 1.0, "format": "%d"},
	{"key": &"fullscreen", "label": "Fullscreen"},
	{"key": &"vsync", "label": "V-Sync"},
	{"key": &"show_fps", "label": "Show FPS"},
	{"section": "AUDIO"},
	{"key": &"master_volume", "label": "Master volume", "min": 0.0, "max": 1.0, "step": 0.01, "format": "%d%%", "display_scale": 100.0},
]

const CONTROLS: Array[Array] = [
	["Move", "W A S D", "Left stick"],
	["Look", "Mouse", "Right stick"],
	["Jump", "Space", "A"],
	["Sprint", "Hold Shift", "Click L-stick"],
	["Crouch / Slide", "Ctrl or C", "B / Click R-stick"],
	["Aim", "Right mouse", "Left trigger"],
	["Mantle", "Jump into a ledge", "Jump into a ledge"],
	["Emote", "B", "D-pad down"],
	["Menu", "Esc", "Start"],
]

var is_open := false

var _root: Control
var _left: Control
var _right_panel: PanelContainer
var _controls_page: Control
var _settings_page: Control
var _resume_button: Button
var _settings_button: Button
var _setting_widgets: Dictionary = {}


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.hide()
	Settings.changed.connect(_on_setting_changed)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"pause") and not (is_open and event.is_action_pressed(&"ui_cancel")):
		return
	get_viewport().set_input_as_handled()
	if not is_open:
		open()
	elif _settings_page.visible:
		_close_settings()
	else:
		close()


func open() -> void:
	is_open = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_page(_controls_page)
	_root.show()
	_root.modulate.a = 0.0
	var rest_x := 110.0
	_left.position.x = rest_x - 60.0
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(_root, "modulate:a", 1.0, 0.18)
	tween.tween_property(_left, "position:x", rest_x, 0.28)
	_resume_button.grab_focus()


func close() -> void:
	is_open = false
	_root.hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# --- Construction ----------------------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.theme = UIStyle.get_theme()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var blur := ColorRect.new()
	var blur_material := ShaderMaterial.new()
	blur_material.shader = BLUR_SHADER
	blur.material = blur_material
	blur.set_anchors_preset(Control.PRESET_FULL_RECT)
	blur.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(blur)

	# Navy wash from the left so the menu column always reads.
	var wash := TextureRect.new()
	var gradient := GradientTexture2D.new()
	gradient.gradient = Gradient.new()
	gradient.gradient.set_color(0, Color(UIStyle.NAVY, 0.92))
	gradient.gradient.set_color(1, Color(UIStyle.NAVY, 0.0))
	gradient.fill_to = Vector2(1, 0)
	wash.texture = gradient
	wash.stretch_mode = TextureRect.STRETCH_SCALE
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	wash.anchor_right = 0.7
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(wash)

	# Menu column pinned to the left edge, vertically centred; free to slide in on open.
	_left = _build_left_column()
	_left.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT, Control.PRESET_MODE_MINSIZE, 110)
	_left.grow_vertical = Control.GROW_DIRECTION_BOTH
	_root.add_child(_left)

	# Info panel fills the right side, vertically centred, height from its content.
	_right_panel = PanelContainer.new()
	_right_panel.anchor_left = 0.4
	_right_panel.anchor_right = 1.0
	_right_panel.anchor_top = 0.5
	_right_panel.anchor_bottom = 0.5
	_right_panel.offset_right = -110
	_right_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_root.add_child(_right_panel)
	_controls_page = _build_controls_page()
	_settings_page = _build_settings_page()
	_right_panel.add_child(_controls_page)
	_right_panel.add_child(_settings_page)


func _build_left_column() -> Control:
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 560
	column.add_theme_constant_override(&"separation", 12)

	var kicker := _label("I WILL GET IT", UIStyle.heading_font(), 30, UIStyle.ACCENT)
	column.add_child(kicker)
	var title := _label("PAUSED", UIStyle.heading_font(), 132, UIStyle.TEXT)
	title.add_theme_constant_override(&"outline_size", 0)
	column.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 24
	column.add_child(spacer)

	_resume_button = _menu_button(column, "RESUME", close)
	_settings_button = _menu_button(column, "SETTINGS", _open_settings)
	_menu_button(column, "RESTART", _restart)
	_menu_button(column, "QUIT TO DESKTOP", get_tree().quit)
	return column


func _build_controls_page() -> Control:
	var page := VBoxContainer.new()
	page.add_theme_constant_override(&"separation", 14)
	page.add_child(_label("CONTROLS", UIStyle.heading_font(), 52, UIStyle.TEXT))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override(&"h_separation", 48)
	grid.add_theme_constant_override(&"v_separation", 10)
	for header in ["ACTION", "KEYBOARD & MOUSE", "CONTROLLER"]:
		grid.add_child(_label(header, UIStyle.BODY_BOLD_FONT, 22, UIStyle.ACCENT))
	for row in CONTROLS:
		grid.add_child(_label(row[0], UIStyle.BODY_BOLD_FONT, 28, UIStyle.TEXT))
		grid.add_child(_label(row[1], UIStyle.BODY_FONT, 28, UIStyle.TEXT_DIM))
		grid.add_child(_label(row[2], UIStyle.BODY_FONT, 28, UIStyle.TEXT_DIM))
	page.add_child(grid)
	return page


func _build_settings_page() -> Control:
	var page := VBoxContainer.new()
	page.add_theme_constant_override(&"separation", 8)
	page.add_child(_label("SETTINGS", UIStyle.heading_font(), 52, UIStyle.TEXT))

	for entry in SETTINGS_SCHEMA:
		if entry.has("section"):
			var header := _label(entry.section, UIStyle.BODY_BOLD_FONT, 22, UIStyle.ACCENT)
			header.custom_minimum_size.y = 44
			header.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			page.add_child(header)
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 24)
		var name_label := _label(entry.label, UIStyle.BODY_BOLD_FONT, 28, UIStyle.TEXT)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		if entry.has("min"):
			_add_slider(row, entry)
		else:
			var toggle := CheckButton.new()
			toggle.button_pressed = Settings.get(entry.key)
			toggle.toggled.connect(func(on: bool) -> void: Settings.set_value(entry.key, on))
			row.add_child(toggle)
			_setting_widgets[entry.key] = toggle
		page.add_child(row)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override(&"separation", 16)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 16
	page.add_child(spacer)
	_menu_button(buttons, "RESET", Settings.reset_to_defaults, 30)
	_menu_button(buttons, "BACK", _close_settings, 30)
	page.add_child(buttons)
	return page


func _add_slider(row: HBoxContainer, entry: Dictionary) -> void:
	var scale: float = entry.get("display_scale", 1.0)
	var value_label := _label("", UIStyle.BODY_BOLD_FONT, 28, UIStyle.ACCENT)
	value_label.custom_minimum_size.x = 76
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(340, 40)
	slider.min_value = entry.min
	slider.max_value = entry.max
	slider.step = entry.step
	slider.value = Settings.get(entry.key)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var refresh := func(value: float) -> void:
		value_label.text = entry.format % (value * scale)
	refresh.call(slider.value)
	slider.value_changed.connect(func(value: float) -> void:
		refresh.call(value)
		Settings.set_value(entry.key, value))
	row.add_child(slider)
	row.add_child(value_label)
	_setting_widgets[entry.key] = slider


func _menu_button(parent: Control, text: String, action: Callable, font_size := 0) -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size.y = 64 if font_size == 0 else 52
	if font_size > 0:
		button.add_theme_font_size_override(&"font_size", font_size)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _label(text: String, font: Font, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override(&"font", font)
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	return label


func _open_settings() -> void:
	_show_page(_settings_page)
	(_setting_widgets.values()[0] as Control).grab_focus()


func _close_settings() -> void:
	_show_page(_controls_page)
	_settings_button.grab_focus()


func _restart() -> void:
	close()
	get_tree().reload_current_scene()


func _show_page(page: Control) -> void:
	_controls_page.visible = page == _controls_page
	_settings_page.visible = page == _settings_page


## Keeps widgets in sync when a value changes elsewhere (e.g. Reset).
func _on_setting_changed(key: StringName) -> void:
	var widget: Control = _setting_widgets.get(key)
	if widget is HSlider:
		(widget as HSlider).value = Settings.get(key)  # Re-emits to refresh the label; set_value is a no-op.
	elif widget is CheckButton:
		(widget as CheckButton).set_pressed_no_signal(Settings.get(key))
