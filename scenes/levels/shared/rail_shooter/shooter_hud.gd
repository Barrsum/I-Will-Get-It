class_name ShooterHUD
extends LevelHUD
## Rail shooter overlay: crosshair, score, combo multiplier badge and street progress bar.

var _level: RailShooterLevel
var _crosshair: HUD.Crosshair
var _score_label: Label
var _multiplier_label: Label
var _progress_fill: ColorRect
var _shown_score := 0.0


func setup(level: RailShooterLevel) -> void:
	_level = level
	setup_root()

	_crosshair = HUD.Crosshair.new()
	_crosshair.aiming = true
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	root.add_child(_crosshair)

	var title := label(level.level_title, 34, Color(UIStyle.TEXT, 0.85))
	title.position = Vector2(48, 36)
	root.add_child(title)

	_score_label = label("0", 64)
	_score_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 36)
	_score_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(_score_label)

	# Multiplier badge under the crosshair's line of sight, top centre.
	var badge := VBoxContainer.new()
	badge.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 28)
	badge.grow_horizontal = Control.GROW_DIRECTION_BOTH
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(badge)
	_multiplier_label = label("x1", 76, UIStyle.ACCENT)
	_multiplier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_child(_multiplier_label)
	var track := ColorRect.new()
	track.custom_minimum_size = Vector2(520, 10)
	track.color = Color(UIStyle.NAVY, 0.6)
	badge.add_child(track)
	_progress_fill = ColorRect.new()
	_progress_fill.color = UIStyle.ACCENT
	_progress_fill.size = Vector2(0, 10)
	track.add_child(_progress_fill)
	var hint := UIStyle.label("SHOOT THE TARGETS  ·  DON'T SHOOT THE HEARTS", UIStyle.BODY_BOLD_FONT, 22, Color(UIStyle.TEXT, 0.7))
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 36)
	hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(hint)


func _process(delta: float) -> void:
	# Score counts up smoothly.
	_shown_score = move_toward(_shown_score, _level.score, maxf(400.0, absf(_level.score - _shown_score) * 8.0) * delta)
	_score_label.text = format_number(int(_shown_score))
	_progress_fill.size.x = 520.0 * _level.progress()


func set_multiplier(value: int, pulse: bool) -> void:
	_multiplier_label.text = "x%d" % value
	_multiplier_label.add_theme_color_override(&"font_color", UIStyle.ACCENT if value > 1 else UIStyle.TEXT)
	if pulse:
		_multiplier_label.pivot_offset = _multiplier_label.size * 0.5
		var tween := create_tween()
		tween.tween_property(_multiplier_label, "scale", Vector2.ONE * 1.35, 0.06)
		tween.tween_property(_multiplier_label, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK)


func show_shooter_results() -> void:
	_crosshair.hide()
	var rank := Label.new()
	rank.text = "RANK  %s" % _level.rank()
	rank.add_theme_font_override(&"font", UIStyle.heading_font())
	rank.add_theme_font_size_override(&"font_size", 60)
	rank.add_theme_color_override(&"font_color", UIStyle.TEXT)
	show_results("STREET CLEARED!", [
		["SCORE", format_number(_level.score)],
		["TARGETS HIT", "%d / %d" % [_level.hits, _level.hostile_total]],
		["ACCURACY", "%d%%" % roundi(_level.accuracy() * 100.0)],
		["BEST MULTIPLIER", "x%d" % _level.best_multiplier],
		["HEARTS SHOT", "%d" % _level.friendly_hits],
	], rank)
