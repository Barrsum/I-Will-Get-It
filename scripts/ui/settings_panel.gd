class_name SettingsPanel
extends VBoxContainer
## Settings page used by both the main menu and the pause menu. Rows are generated from SCHEMA
## and bound to the Settings autoload; widgets stay in sync when values change elsewhere.

signal back_requested

const SCHEMA: Array[Dictionary] = [
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

var _widgets: Dictionary = {}


func _ready() -> void:
	add_theme_constant_override(&"separation", 8)
	add_child(UIStyle.label("SETTINGS", UIStyle.heading_font(), 52))
	for entry in SCHEMA:
		if entry.has("section"):
			var header := UIStyle.label(entry.section, UIStyle.BODY_BOLD_FONT, 22, UIStyle.ACCENT)
			header.custom_minimum_size.y = 44
			header.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			add_child(header)
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 24)
		var name_label := UIStyle.label(entry.label, UIStyle.BODY_BOLD_FONT, 28)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		if entry.has("min"):
			_add_slider(row, entry)
		else:
			var toggle := CheckButton.new()
			toggle.button_pressed = Settings.get(entry.key)
			toggle.toggled.connect(func(on: bool) -> void: Settings.set_value(entry.key, on))
			row.add_child(toggle)
			_widgets[entry.key] = toggle
		add_child(row)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 16
	add_child(spacer)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override(&"separation", 16)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	UIStyle.menu_button(buttons, "RESET", Settings.reset_to_defaults, 30)
	UIStyle.menu_button(buttons, "BACK", back_requested.emit, 30)
	add_child(buttons)
	Settings.changed.connect(_on_setting_changed)


func focus_first() -> void:
	(_widgets.values()[0] as Control).grab_focus()


func _add_slider(row: HBoxContainer, entry: Dictionary) -> void:
	var scale: float = entry.get("display_scale", 1.0)
	var value_label := UIStyle.label("", UIStyle.BODY_BOLD_FONT, 28, UIStyle.ACCENT)
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
	_widgets[entry.key] = slider


## Keeps widgets in sync when a value changes elsewhere (e.g. Reset).
func _on_setting_changed(key: StringName) -> void:
	var widget: Control = _widgets.get(key)
	if widget is HSlider:
		(widget as HSlider).value = Settings.get(key)  # Re-emits to refresh the label; set_value is a no-op.
	elif widget is CheckButton:
		(widget as CheckButton).set_pressed_no_signal(Settings.get(key))
