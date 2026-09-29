extends Node
## Renders the test gym from set viewpoints and saves PNGs, for visual review of camera,
## character, lighting and UI. Needs a GPU (don't pass --headless):
##   <godot> res://tests/screenshot_tour.tscn -- <output_dir>

const GYM := "res://scenes/levels/test_gym/test_gym.tscn"

var _out_dir := "user://screenshots"
var _hero: Hero
var _pause: PauseMenu


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_run.call_deferred()


func _run() -> void:
	var level: Node = (load(GYM) as PackedScene).instantiate()
	add_child(level)
	_hero = level.get_node("Hero") as Hero
	_pause = level.get_node("PauseMenu") as PauseMenu
	await _frames(60)
	await _shot("01_spawn")

	Input.action_press(&"aim")
	await _frames(30)
	await _shot("02_aim")
	Input.action_release(&"aim")

	await _place(Vector3(0, 0.05, -4), 0.0, -0.18)
	await _shot("03_mantle_walls")

	await _place(Vector3(-16, 0.05, 16), deg_to_rad(-30), -0.25)
	await _shot("04_slide_hill_and_ramps")

	_hero.state_machine.transition_to(Hero.STATE_EMOTE)
	await _frames(70)
	await _shot("05_emote")
	_hero.state_machine.transition_to(Hero.STATE_GROUND)

	await _place(Vector3(13.5, 0.05, 7.5), 0.0, -0.1)
	_hero.state_machine.transition_to(Hero.STATE_CROUCH)
	await _frames(30)
	await _shot("06_crouch_tunnel")

	_pause.open()
	await _frames(30)
	await _shot("07_pause_menu")
	_pause.call(&"_open_settings")
	await _frames(10)
	await _shot("08_settings")
	get_tree().quit()


func _place(pos: Vector3, yaw: float, pitch: float) -> void:
	_hero.global_position = pos
	_hero.velocity = Vector3.ZERO
	_hero.reset_physics_interpolation()
	_hero.visual_root.rotation.y = yaw + PI
	_hero.camera.yaw = yaw
	_hero.camera.pitch = pitch
	_hero.camera.snap()
	await _frames(40)


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := _out_dir.path_join(shot_name + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
