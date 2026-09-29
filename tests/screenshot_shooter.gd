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
	_run.call_deferred()


func _run() -> void:
	Game.current_level = Game.level_by_id(&"level_02")
	level = (load(LEVEL) as PackedScene).instantiate() as RailShooterLevel
	add_child(level)
	await _frames(60)
	await _shot("30_intro")
	await _frames(150)
	await _shot("31_street")

	# Aim at the next hostile target that pops up and fire (beam mid-flight).
	var target := await _next_up_target()
	if target:
		await _aim_at(target.center())
		await _shot("32_aiming")
		level._shoot(level._aim_ray())
		await _frames(2)
		await _shot("33_hit")

	level.hero.global_position.z = -110.0
	level.hero.reset_physics_interpolation()
	level.hero.camera.yaw = deg_to_rad(35.0)
	level.hero.camera.pitch = deg_to_rad(12.0)
	await _frames(90)
	await _shot("34_windows")

	level.hero.global_position.z = -level.track_length + 0.5
	level.hero.reset_physics_interpolation()
	while not level._finished:
		await _frames(1)
	await get_tree().create_timer(1.8).timeout  # Results appear after a short delay + fade.
	await _shot("35_results")
	get_tree().quit()


func _next_up_target() -> TargetPlate:
	for i in 900:
		await get_tree().process_frame
		for child in level.get_children():
			if child is TargetPlate and child.phase == TargetPlate.Phase.UP and child.is_hostile():
				await _frames(15)
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
