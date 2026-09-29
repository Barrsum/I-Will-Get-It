extends Node
## Visual review for Level 3 (needs a GPU, no --headless):
##   <godot> --resolution 1600x900 res://tests/screenshot_speed.tscn -- <output_dir>

const LEVEL := "res://scenes/levels/level_03/level_03.tscn"

var _out_dir := "user://screenshots"
var level: SpeedLevel


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_run.call_deferred()


func _run() -> void:
	Game.current_level = Game.level_by_id(&"level_03")
	level = (load(LEVEL) as PackedScene).instantiate() as SpeedLevel
	add_child(level)
	var hero := level.hero
	await _frames(40)
	await _shot("50_intro")
	await get_tree().create_timer(3.0).timeout
	await _shot("51_start")

	Input.action_press(&"move_forward")
	var loop_shot := false
	var jump_shot := false
	for i in 900:
		await get_tree().process_frame
		if i == 70:
			await _shot("52_boosting")
		if not loop_shot and hero.current_state() == Hero.STATE_RAIL and hero.global_position.y > 12.0:
			loop_shot = true
			await _shot("53_loop_top")
		if not jump_shot and hero.global_position.z < -76.0 and not hero.is_on_floor():
			jump_shot = true
			await _shot("54_ramp_jump")
		if hero.global_position.z < -128.0:
			break
	await _shot("55_coin_gate")
	for c in 25:
		level.add_coin()
	for i in 400:
		await get_tree().process_frame
		if hero.global_position.y > 9.0 and hero.is_on_floor():
			break
	await _frames(30)
	await _shot("56_ridge")
	Input.action_release(&"move_forward")
	get_tree().quit()


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := _out_dir.path_join(shot_name + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
