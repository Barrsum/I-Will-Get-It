class_name PauseMenu
extends CanvasLayer
## Esc / Start pause menu: Resume, Settings, Restart, Main Menu, Quit, plus a controls reference.

const BLUR_SHADER: Shader = preload("res://assets/shaders/ui_blur.gdshader")
const MENU_X := 110.0

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
var _controls_page: Control
var _settings_page: SettingsPanel
var _resume_button: Button
var _settings_button: Button
## Mouse mode to restore on close (captured in 3D play, visible on end screens).
var _mouse_mode_before := Input.MOUSE_MODE_CAPTURED


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.hide()


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
	_mouse_mode_before = Input.mouse_mode
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_page(_controls_page)
	_root.show()
	_root.modulate.a = 0.0
	_left.position.x = MENU_X - 60.0
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(_root, "modulate:a", 1.0, 0.18)
	tween.tween_property(_left, "position:x", MENU_X, 0.28)
	_resume_button.grab_focus()


func close() -> void:
	is_open = false
	_root.hide()
	get_tree().paused = false
	Input.mouse_mode = _mouse_mode_before


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
	UIStyle.add_left_wash(_root)

	# Menu column pinned to the left edge, vertically centred; free to slide in on open.
	_left = _build_left_column()
	_left.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT, Control.PRESET_MODE_MINSIZE, int(MENU_X))
	_left.grow_vertical = Control.GROW_DIRECTION_BOTH
	_root.add_child(_left)

	# Info panel fills the right side, vertically centred, height from its content.
	var right_panel := PanelContainer.new()
	right_panel.anchor_left = 0.4
	right_panel.anchor_right = 1.0
	right_panel.anchor_top = 0.5
	right_panel.anchor_bottom = 0.5
	right_panel.offset_right = -MENU_X
	right_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_root.add_child(right_panel)
	_controls_page = _build_controls_page()
	right_panel.add_child(_controls_page)
	_settings_page = SettingsPanel.new()
	_settings_page.back_requested.connect(_close_settings)
	right_panel.add_child(_settings_page)


func _build_left_column() -> Control:
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 560
	column.add_theme_constant_override(&"separation", 12)
	column.add_child(UIStyle.label("I WILL GET IT", UIStyle.heading_font(), 30, UIStyle.ACCENT))
	column.add_child(UIStyle.label("PAUSED", UIStyle.heading_font(), 132))
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 24
	column.add_child(spacer)
	_resume_button = UIStyle.menu_button(column, "RESUME", close)
	_settings_button = UIStyle.menu_button(column, "SETTINGS", _open_settings)
	UIStyle.menu_button(column, "RESTART", Game.restart_level)
	UIStyle.menu_button(column, "MAIN MENU", Game.goto_main_menu)
	UIStyle.menu_button(column, "QUIT TO DESKTOP", get_tree().quit)
	return column


func _build_controls_page() -> Control:
	var page := VBoxContainer.new()
	page.add_theme_constant_override(&"separation", 14)
	page.add_child(UIStyle.label("CONTROLS", UIStyle.heading_font(), 52))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override(&"h_separation", 48)
	grid.add_theme_constant_override(&"v_separation", 10)
	for header in ["ACTION", "KEYBOARD & MOUSE", "CONTROLLER"]:
		grid.add_child(UIStyle.label(header, UIStyle.BODY_BOLD_FONT, 22, UIStyle.ACCENT))
	for row in CONTROLS:
		grid.add_child(UIStyle.label(row[0], UIStyle.BODY_BOLD_FONT, 28))
		grid.add_child(UIStyle.label(row[1], UIStyle.BODY_FONT, 28, UIStyle.TEXT_DIM))
		grid.add_child(UIStyle.label(row[2], UIStyle.BODY_FONT, 28, UIStyle.TEXT_DIM))
	page.add_child(grid)
	return page


func _open_settings() -> void:
	_show_page(_settings_page)
	_settings_page.focus_first()


func _close_settings() -> void:
	_show_page(_controls_page)
	_settings_button.grab_focus()


func _show_page(page: Control) -> void:
	_controls_page.visible = page == _controls_page
	_settings_page.visible = page == _settings_page
