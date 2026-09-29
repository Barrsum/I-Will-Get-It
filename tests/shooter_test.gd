extends Node
## Headless gameplay test for Level 2 (rail shooter): auto-walk, target pop-up, hit scoring,
## multiplier growth, miss reset, friendly penalty and level finish.
## Run: <godot_console> --headless res://tests/shooter_test.tscn   (exit code = failed checks)

const LEVEL := "res://scenes/levels/level_02/level_02.tscn"

var level: RailShooterLevel
var failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	level = (load(LEVEL) as PackedScene).instantiate() as RailShooterLevel
	add_child(level)
	await _frames(20)
	var hero := level.hero
	_check("level has targets", level.hostile_total > 10, "hostile=%d" % level.hostile_total)

	var z0 := hero.global_position.z
	await _frames(60)
	_check("hero walks forward on rails", hero.global_position.z < z0 - 2.0 and absf(hero.global_position.x) < 0.01,
		"dz=%.2f" % (hero.global_position.z - z0))

	var first := await _wait_for_up_target(true)
	_check("targets pop up as the hero approaches", first != null)
	if first:
		await _aim_at(first.center())
		level._shoot(level._aim_ray())
		_check("shooting a target scores and raises the multiplier",
			level.hits == 1 and level.score == 100 and level.multiplier == 2,
			"hits=%d score=%d mult=%d" % [level.hits, level.score, level.multiplier])

	level._cooldown = 0.0
	hero.camera.pitch = deg_to_rad(60.0)  # Straight up at the sky.
	await _frames(3)
	level._shoot(level._aim_ray())
	_check("a stray shot breaks the combo", level.multiplier == 1 and level.shots == 2,
		"mult=%d shots=%d" % [level.multiplier, level.shots])

	var friendly: TargetPlate = null
	for child in level.get_children():
		if child is TargetPlate and not child.is_hostile() and child.phase == TargetPlate.Phase.HIDDEN:
			friendly = child
			break
	_check("level contains friendly heart plates", friendly != null)
	if friendly:
		hero.global_position.z = friendly.global_position.z + 14.0
		hero.reset_physics_interpolation()
		friendly.activate()
		await _frames(20)
		await _aim_at(friendly.center())
		var score_before := level.score
		level._shoot(level._aim_ray())
		_check("shooting a heart is penalised", level.friendly_hits == 1 and level.score <= score_before,
			"friendly_hits=%d" % level.friendly_hits)

	hero.global_position.z = -level.track_length + 1.0
	hero.reset_physics_interpolation()
	await _frames(40)
	_check("reaching the end of the street finishes the level", level._finished and level.progress() >= 1.0)

	print("\n%s — %d failure(s)" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(failures)


func _wait_for_up_target(hostile: bool) -> TargetPlate:
	for i in 900:
		await get_tree().physics_frame
		for child in level.get_children():
			if child is TargetPlate and child.phase == TargetPlate.Phase.UP and child.is_hostile() == hostile:
				await _frames(20)  # Let it finish flipping up.
				return child
	return null


## Points the camera so the crosshair ray passes through `point` (iterates: the camera
## position itself depends on the look angles).
func _aim_at(point: Vector3) -> void:
	var cam := level.hero.camera
	cam.yaw_limit = INF
	for i in 6:
		var dir := point - cam.camera.global_position
		cam.yaw = atan2(-dir.x, -dir.z)
		cam.pitch = atan2(dir.y, Vector2(dir.x, dir.z).length())
		await get_tree().process_frame
		await get_tree().process_frame


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(label: String, ok: bool, detail := "") -> void:
	if not ok:
		failures += 1
	print("%s  %s%s" % ["PASS" if ok else "FAIL", label, ("  (" + detail + ")") if detail else ""])
