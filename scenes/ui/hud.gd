class_name HUD
extends CanvasLayer
## In-game overlay: centre crosshair, key hints, and an F3 debug readout (state, speed, FPS).

var _hero: Hero
var _crosshair: Crosshair
var _debug_label: Label
var _debug_visible := false


func _ready() -> void:
	layer = 5
	var root := Control.new()
	root.theme = UIStyle.get_theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_crosshair = Crosshair.new()
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	root.add_child(_crosshair)

	var hint := Label.new()
	hint.text = "ESC  MENU      B  EMOTE      F3  DEBUG"
	hint.add_theme_font_override(&"font", UIStyle.BODY_BOLD_FONT)
	hint.add_theme_font_size_override(&"font_size", 22)
	hint.add_theme_color_override(&"font_color", Color(UIStyle.TEXT, 0.7))
	hint.add_theme_constant_override(&"outline_size", 6)
	hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint.position = Vector2(40, -60)
	root.add_child(hint)

	_debug_label = Label.new()
	_debug_label.add_theme_font_override(&"font", UIStyle.BODY_BOLD_FONT)
	_debug_label.add_theme_font_size_override(&"font_size", 24)
	_debug_label.add_theme_constant_override(&"outline_size", 6)
	_debug_label.position = Vector2(40, 32)
	root.add_child(_debug_label)

	_hero = get_tree().get_first_node_in_group(&"hero") as Hero


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_debug"):
		_debug_visible = not _debug_visible


func _process(_delta: float) -> void:
	if _hero:
		_crosshair.aiming = _hero.is_aiming
		_crosshair.visible = _hero.current_state() != Hero.STATE_EMOTE
	var lines: PackedStringArray = []
	if Settings.show_fps or _debug_visible:
		lines.append("%d FPS" % Engine.get_frames_per_second())
	if _debug_visible and _hero:
		lines.append("STATE  %s" % _hero.current_state())
		lines.append("SPEED  %.1f m/s" % _hero.horizontal_speed())
		lines.append("VERT   %.1f m/s" % _hero.velocity.y)
		lines.append("POS    %.1f  %.1f  %.1f" % [_hero.global_position.x, _hero.global_position.y, _hero.global_position.z])
	_debug_label.text = "\n".join(lines)


class Crosshair extends Control:
	## Small ring + dot; tightens while aiming.
	var aiming := false:
		set(value):
			if value != aiming:
				aiming = value
				queue_redraw()

	func _draw() -> void:
		var radius := 7.0 if aiming else 12.0
		draw_arc(Vector2.ZERO, radius, 0, TAU, 40, Color(0, 0, 0, 0.45), 4.0, true)
		draw_arc(Vector2.ZERO, radius, 0, TAU, 40, Color(1, 1, 1, 0.9), 2.0, true)
		draw_circle(Vector2.ZERO, 2.5, Color(0, 0, 0, 0.45))
		draw_circle(Vector2.ZERO, 1.6, Color.WHITE)
