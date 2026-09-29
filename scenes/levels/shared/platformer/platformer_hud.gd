class_name PlatformerHUD
extends CanvasLayer
## Platformer overlay: coins + timer bar, pop-up toasts, level intro banner and the
## level-complete results card.

var _level: PlatformerLevel
var _root: Control
var _coins_label: Label
var _time_label: Label
var _toast: Label
var _toast_tween: Tween


func setup(level: PlatformerLevel) -> void:
	_level = level
	layer = 5
	_root = Control.new()
	_root.theme = UIStyle.get_theme()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var bar := HBoxContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE, Control.PRESET_MODE_MINSIZE, 36)
	bar.offset_left = 48
	bar.offset_right = -48
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bar)

	var coin_icon := CoinIcon.new()
	coin_icon.custom_minimum_size = Vector2(44, 44)
	bar.add_child(coin_icon)
	_coins_label = _label("× 00", 44)
	bar.add_child(_coins_label)
	var title := _label(level.level_title, 34, Color(UIStyle.TEXT, 0.85))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	_time_label = _label("00:00", 44)
	bar.add_child(_time_label)

	_toast = _label("", 72, UIStyle.ACCENT)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 170)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.modulate.a = 0.0
	_root.add_child(_toast)

	set_coins(level.coins)


func _process(_delta: float) -> void:
	var seconds := int(Game.elapsed)
	_time_label.text = "%02d:%02d" % [seconds / 60, seconds % 60]


func set_coins(count: int) -> void:
	_coins_label.text = "× %02d" % count
	_coins_label.pivot_offset = _coins_label.size * 0.5
	var tween := create_tween()
	tween.tween_property(_coins_label, "scale", Vector2.ONE * 1.25, 0.06)
	tween.tween_property(_coins_label, "scale", Vector2.ONE, 0.12)


func toast(text: String) -> void:
	_toast.text = text
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


## Big "LEVEL N / TITLE / boast" card at the start of a fresh run.
func show_intro(title: String, boast: String) -> void:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var number := "LEVEL %d" % Game.current_level.get("number", 0) if not Game.current_level.is_empty() else "LEVEL"
	for part: Array in [[number, 40, UIStyle.ACCENT], [title, 130, UIStyle.TEXT], [boast, 34, Color(UIStyle.TEXT, 0.9)]]:
		if part[0] == "":
			continue
		var label := _label(part[0], part[1], part[2])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if part[1] == 34:
			label.add_theme_font_override(&"font", UIStyle.BODY_BOLD_FONT)
		box.add_child(label)
	_root.add_child(box)
	box.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(box, "modulate:a", 1.0, 0.3)
	tween.tween_interval(2.4)
	tween.tween_property(box, "modulate:a", 0.0, 0.5)
	tween.tween_callback(box.queue_free)


func show_results(coins: int, seconds: float, deaths: int) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 14)
	column.custom_minimum_size.x = 640
	panel.add_child(column)
	column.add_child(_label("LEVEL COMPLETE!", 84, UIStyle.ACCENT))
	var total := int(seconds)
	for row: Array in [["COINS", "%d" % coins], ["TIME", "%02d:%02d" % [total / 60, total % 60]], ["FALLS", "%d" % deaths]]:
		var line := HBoxContainer.new()
		var name_label := _label(row[0], 34, UIStyle.TEXT_DIM)
		name_label.add_theme_font_override(&"font", UIStyle.BODY_BOLD_FONT)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(name_label)
		line.add_child(_label(row[1], 40, UIStyle.TEXT))
		column.add_child(line)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override(&"separation", 16)
	column.add_child(buttons)
	var again := Button.new()
	again.text = "PLAY AGAIN"
	again.pressed.connect(Game.restart_level)
	buttons.add_child(again)
	var menu := Button.new()
	menu.text = "MAIN MENU"
	menu.pressed.connect(Game.goto_main_menu)
	buttons.add_child(menu)
	_root.add_child(panel)
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2.ONE * 0.8
	panel.modulate.a = 0.0
	var tween := create_tween().set_parallel()
	tween.tween_property(panel, "modulate:a", 1.0, 0.25)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	again.grab_focus()


func _label(text: String, font_size: int, color := UIStyle.TEXT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override(&"font", UIStyle.heading_font())
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_constant_override(&"outline_size", 12)
	label.add_theme_color_override(&"font_outline_color", Color(UIStyle.NAVY, 0.8))
	return label


class CoinIcon extends Control:
	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.45
		draw_circle(c, r + 3, Color(UIStyle.NAVY, 0.8))
		draw_circle(c, r, Color(1.0, 0.78, 0.15))
		draw_circle(c, r * 0.6, Color(1.0, 0.9, 0.45))
