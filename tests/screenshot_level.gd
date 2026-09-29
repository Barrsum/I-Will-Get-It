extends Node
## Visual review for the menu flow and Level 1 (needs a GPU, no --headless):
##   <godot> --resolution 1600x900 res://tests/screenshot_level.tscn -- <output_dir>

const MENU := "res://scenes/ui/main_menu.tscn"
const LEVEL := "res://scenes/levels/level_01/level_01.tscn"
const GYM := "res://scenes/levels/test_gym/test_gym.tscn"
const CELL := PlatformerArt.CELL

var _out_dir := "user://screenshots"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_run.call_deferred()


func _run() -> void:
	var menu: Node = (load(MENU) as PackedScene).instantiate()
	add_child(menu)
	await _frames(40)
	await _shot("10_main_menu")
	menu.call(&"_show_level_select")
	await _frames(10)
	await _shot("11_level_select")
	menu.queue_free()
	await _frames(2)

	Game.current_level = Game.level_by_id(&"level_01")
	Game.checkpoint_index = -1
	Game.deaths = 0
	Game.elapsed = 0.0
	var level := (load(LEVEL) as PackedScene).instantiate() as PlatformerLevel
	add_child(level)
	await _frames(50)
	await _shot("12_level_intro")
	await _frames(200)
	await _shot("13_level_start")
	# [cell x, cell y to stand on, name]. Standing spots must be solid or the hero falls and the level reloads.
	for spot: Array in [[20.5, 2, "14_blocks"], [40.0, 5, "15_pipes"], [66.5, 6, "16_brick_climb"],
			[91.5, 5, "17_pit_platform"], [126.5, 6, "18_stairs"], [156.0, 2, "19_flag"]]:
		level.hero.set_spawn(Vector3(spot[0] * CELL, spot[1] * CELL + 0.05, 0))
		await _frames(45)
		await _shot(spot[2])

	# Mid-jump next to a Grumble, super-sized.
	level.hero.set_size_scale(PlatformerLevel.SUPER_SIZE)
	level.hero.set_spawn(Vector3(103.5 * CELL, 2 * CELL + 0.05, 0))
	await _frames(20)
	level.hero.jump()
	await _frames(14)
	await _shot("20_super_jump")

	level.hud.show_results(23, 187.0, 2)
	await _frames(30)
	await _shot("21_results")
	level.queue_free()
	await _frames(2)

	# Retargeted UAL2 clips on the mannequin: slide and mantle, from the side.
	var gym := (load(GYM) as PackedScene).instantiate()
	add_child(gym)
	var hero := gym.get_node("Hero") as Hero
	await _frames(20)
	hero.set_frozen(true)  # Otherwise the Ground state immediately returns the skin to idle.
	hero.camera.yaw = -PI * 0.5
	hero.camera.snap()
	hero.skin.play_slide()
	await _frames(40)
	await _shot("22_slide_anim")
	hero.skin.play_mantle(0.6)
	await _frames(12)
	await _shot("23_mantle_anim")
	get_tree().quit()


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := _out_dir.path_join(shot_name + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
