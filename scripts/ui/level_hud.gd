class_name LevelHUD
extends CanvasLayer
## Shared overlay pieces for playable levels: level intro card, pop-up toasts, floating world
## text, and the end-of-level results card (NEXT LEVEL / PLAY AGAIN / MAIN MENU).
## Level-specific HUDs extend this and add their own counters in _build().

var root: Control
var _toast: Label
var _toast_tween: Tween


func _init() -> void:
	layer = 5


## Creates the root Control and shared widgets, then calls _build() for the subclass.
func setup_root() -> void:
	root = Control.new()
	root.theme = UIStyle.get_theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_toast = label("", 72, UIStyle.ACCENT)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 170)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.modulate.a = 0.0
	root.add_child(_toast)


## Outlined slanted heading label, readable over any 3D background.
func label(text: String, font_size: int, color := UIStyle.TEXT) -> Label:
	var node := UIStyle.label(text, UIStyle.heading_font(), font_size, color)
	node.add_theme_constant_override(&"outline_size", 12)
	node.add_theme_color_override(&"font_outline_color", Color(UIStyle.NAVY, 0.8))
	return node


func toast(text: String, color := UIStyle.ACCENT) -> void:
	_toast.text = text
	_toast.add_theme_color_override(&"font_color", color)
	_toast.pivot_offset = _toast.size * 0.5
	if _toast_tween:
		_toast_tween.kill()
	_toast.scale = Vector2.ONE * 0.6
	_toast_tween = create_tween()
	_toast_tween.set_parallel()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.12)
	_toast_tween.tween_property(_toast, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_toast_tween.chain().tween_interval(0.9)
	_toast_tween.chain().tween_property(_toast, "modulate:a", 0.0, 0.3)


## Text that pops up at a 3D position and floats away (score popups).
func popup_at(camera: Camera3D, world_position: Vector3, text: String, color := UIStyle.ACCENT) -> void:
	if camera.is_position_behind(world_position):
		return
	var node := label(text, 46, color)
	root.add_child(node)
	node.position = camera.unproject_position(world_position) - node.get_combined_minimum_size() * 0.5
	var tween := node.create_tween().set_parallel()
	tween.tween_property(node, "position:y", node.position.y - 70.0, 0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(node, "modulate:a", 0.0, 0.3).set_delay(0.4)
	tween.chain().tween_callback(node.queue_free)


## Big "LEVEL N / TITLE / boast" card at the start of a fresh run.
func show_intro(title: String, boast: String) -> void:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var number := "LEVEL %d" % Game.current_level.number if not Game.current_level.is_empty() else "LEVEL"
	for part: Array in [[number, 40, UIStyle.ACCENT], [title, 130, UIStyle.TEXT]]:
		var node := label(part[0], part[1], part[2])
		node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(node)
	if boast != "":
		var quote := label(boast, 34, Color(UIStyle.TEXT, 0.9))
		quote.add_theme_font_override(&"font", UIStyle.BODY_BOLD_FONT)
		quote.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(quote)
	root.add_child(box)
	box.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(box, "modulate:a", 1.0, 0.3)
	tween.tween_interval(2.4)
	tween.tween_property(box, "modulate:a", 0.0, 0.5)
	tween.tween_callback(box.queue_free)


## Results card. `rows` = [[name, value], ...]; `headline` e.g. "LEVEL COMPLETE!".
## `extra` is an optional Control shown under the headline (e.g. a rank badge).
func show_results(headline: String, rows: Array, extra: Control = null) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var dim := ColorRect.new()
	dim.color = Color(UIStyle.NAVY, 0.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	dim.create_tween().tween_property(dim, "color:a", 0.55, 0.3)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 14)
	column.custom_minimum_size.x = 680
	panel.add_child(column)
	column.add_child(label(headline, 84, UIStyle.ACCENT))
	if extra:
		column.add_child(extra)
	for row: Array in rows:
		var line := HBoxContainer.new()
		var name_label := label(row[0], 34, UIStyle.TEXT_DIM)
		name_label.add_theme_font_override(&"font", UIStyle.BODY_BOLD_FONT)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(name_label)
		line.add_child(label(row[1], 40, UIStyle.TEXT))
		column.add_child(line)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override(&"separation", 16)
	column.add_child(buttons)
	var next := Game.next_level()
	if not next.is_empty():
		_result_button(buttons, "NEXT LEVEL", Game.start_level.bind(next.id))
	_result_button(buttons, "PLAY AGAIN", Game.restart_level)
	_result_button(buttons, "MAIN MENU", Game.goto_main_menu)
	root.add_child(panel)
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2.ONE * 0.8
	panel.modulate.a = 0.0
	var tween := create_tween().set_parallel()
	tween.tween_property(panel, "modulate:a", 1.0, 0.25)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	(buttons.get_child(0) as Button).grab_focus()


static func format_time(seconds: float) -> String:
	var total := int(seconds)
	return "%02d:%02d" % [total / 60, total % 60]


## 12345 -> "12,345"
static func format_number(value: int) -> String:
	var digits := str(absi(value))
	var out := ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			out += ","
		out += digits[i]
	return ("-" if value < 0 else "") + out


func _result_button(parent: Control, text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)
