extends Node
## Visual review for Level 2 (needs a GPU, no --headless):
##   <godot> --resolution 1600x900 res://tests/screenshot_shooter.tscn -- <output_dir>

const LEVEL := "res://scenes/levels/level_02/level_02.tscn"

var _out_dir := "user://screenshots"
var level: RailShooterLevel


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(_out_dir)
	Settings.placeholder_voices = false
	_run.call_deferred()


func _run() -> void:
	Game.current_level = Game.level_by_id(&"level_02")
	level = (load(LEVEL) as PackedScene).instantiate() as RailShooterLevel
	add_child(level)
	await _frames(40)
	await _shot("30_portal_drop")
	while not level.driving:
		await _frames(1)
	await _shot("31_commander")
	await _frames(240)
	await _shot("32_alley")

	var target := await _next_up_target()
	if target:
		await _aim_at(target.center())
		await _shot("33_aiming")
		level.shoot()
		await _frames(3)
		await _shot("34_kill")

	level.vehicle.global_position.z -= 120.0
	level.hero.camera.yaw = deg_to_rad(40.0)
	level.hero.camera.pitch = deg_to_rad(18.0)
	await _frames(120)
	await _shot("35_rooftops")
	level.hero.camera.yaw = 0.0
	level.hero.camera.pitch = deg_to_rad(8.0)
	await _frames(60)
	await _shot("36_mothership")
	get_tree().quit()


func _next_up_target() -> ShooterTarget:
	for i in 1500:
		await get_tree().process_frame
		for child in level.get_children():
			if child is ShooterTarget and child.phase == ShooterTarget.Phase.UP:
				await _frames(20)
				return child
	return null


func _aim_at(point: Vector3) -> void:
	var cam := level.hero.camera
	for i in 6:
		var dir := point - cam.camera.global_position
		cam.yaw = atan2(-dir.x, -dir.z)
		cam.pitch = atan2(dir.y, Vector2(dir.x, dir.z).length())
		await _frames(2)


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := _out_dir.path_join(shot_name + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
