class_name PlatformerHUD
extends LevelHUD
## Platformer overlay: coin counter, level title and timer. Intro, toasts and results come from LevelHUD.

var _level: Node
var _coins_label: Label
var _time_label: Label


## `level` must expose `level_title` and `coins` (platformer and speed levels both do).
func setup(level: Node) -> void:
	_level = level
	setup_root()

	var bar := HBoxContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE, Control.PRESET_MODE_MINSIZE, 36)
	bar.offset_left = 48
	bar.offset_right = -48
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bar)

	var coin_icon := CoinIcon.new()
	coin_icon.custom_minimum_size = Vector2(44, 44)
	bar.add_child(coin_icon)
	_coins_label = label("× 00", 44)
	bar.add_child(_coins_label)
	var title := label(level.level_title, 34, Color(UIStyle.TEXT, 0.85))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	_time_label = label("00:00", 44)
	bar.add_child(_time_label)
	set_coins(level.coins)


func _process(_delta: float) -> void:
	_time_label.text = format_time(Game.elapsed)


func set_coins(count: int) -> void:
	_coins_label.text = "× %02d" % count
	_coins_label.pivot_offset = _coins_label.size * 0.5
	var tween := create_tween()
	tween.tween_property(_coins_label, "scale", Vector2.ONE * 1.25, 0.06)
	tween.tween_property(_coins_label, "scale", Vector2.ONE, 0.12)


func show_level_results(coins: int, seconds: float, deaths: int, next_label := "NEXT LEVEL",
		next_action := Callable()) -> Control:
	return show_results("LEVEL COMPLETE!", [["COINS", "%d" % coins], ["TIME", format_time(seconds)], ["FALLS", "%d" % deaths]],
		null, next_label, next_action)


class CoinIcon extends Control:
	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.45
		draw_circle(c, r + 3, Color(UIStyle.NAVY, 0.8))
		draw_circle(c, r, Color(1.0, 0.78, 0.15))
		draw_circle(c, r * 0.6, Color(1.0, 0.9, 0.45))
