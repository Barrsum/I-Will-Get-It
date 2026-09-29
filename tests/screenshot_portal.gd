extends Node
## Visual review of the Level 1 ending: results card, portal opening, world morph.
##   <godot> --resolution 1600x900 res://tests/screenshot_portal.tscn -- <output_dir>
## Quits before the cutscene switches scenes.

const LEVEL := "res://scenes/levels/level_01/level_01.tscn"

var _out_dir := "user://screenshots"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_run.call_deferred()


func _run() -> void:
	Game.current_level = Game.level_by_id(&"level_01")
	Game.checkpoint_index = -1
	Game.deaths = 0
	var level := (load(LEVEL) as PackedScene).instantiate() as PlatformerLevel
	add_child(level)
	await _frames(30)
	var flag: Flagpole = null
	for child in level.get_children():
		if child is Flagpole:
			flag = child
	level.hero.set_spawn(flag.global_position + Vector3(-1.0, 4.0, 0))
	await _frames(5)
	level.reach_goal(flag)
	await get_tree().create_timer(2.5).timeout
	await _shot("40_results_portal_button")
	level.call(&"_portal_cutscene")
	await get_tree().create_timer(1.3).timeout
	await _shot("41_portal_opens")
	await get_tree().create_timer(2.2).timeout
	await _shot("42_world_morphing")
	await get_tree().create_timer(1.6).timeout
	await _shot("43_morphed")
	get_tree().quit()


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := _out_dir.path_join(shot_name + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
