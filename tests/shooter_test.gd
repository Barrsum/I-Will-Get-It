extends Node
## Headless gameplay test for Level 2 (tank turret shooter): portal intro lands the hero on the
## tank, the tank drives, aliens drop in and become shootable, kills score and raise the
## multiplier, stray shots reset it, brutes take 3 hits, reaching the end finishes the level.
## Run: <godot_console> --headless res://tests/shooter_test.tscn   (exit code = failed checks)

const LEVEL := "res://scenes/levels/level_02/level_02.tscn"

var level: RailShooterLevel
var failures := 0


func _ready() -> void:
	Settings.placeholder_voices = false
	_run.call_deferred()


func _run() -> void:
	level = (load(LEVEL) as PackedScene).instantiate() as RailShooterLevel
	add_child(level)
	await _frames(20)
	_check("level has aliens", level.hostile_total > 10, "hostile=%d" % level.hostile_total)

	for i in 1500:  # Intro: portal drop + Commander lines.
		if level.driving:
			break
		await get_tree().physics_frame
	_check("intro lands the hero on the tank and starts driving", level.driving and level.hero_on_mount)

	var z0 := level.vehicle.global_position.z
	await _frames(90)
	_check("tank drives forward", level.vehicle.global_position.z < z0 - 2.0, "dz=%.2f" % (level.vehicle.global_position.z - z0))
	_check("hero rides the turret", level.hero.global_position.distance_to(level.mount_position()) < 0.05)

	var grunt := await _wait_for_landed(AlienTarget.Kind.GRUNT)
	_check("aliens drop in and land", grunt != null)
	if grunt:
		await _aim_at(grunt.center())
		level.shoot()
		_check("killing an alien scores and raises the multiplier",
			level.kills == 1 and level.score == 100 and level.multiplier == 2,
			"kills=%d score=%d mult=%d" % [level.kills, level.score, level.multiplier])

	level._cooldown = 0.0
	level.hero.camera.pitch = deg_to_rad(60.0)  # Straight up at the sky.
	await _frames(3)
	level.shoot()
	_check("a stray shot breaks the combo", level.multiplier == 1)

	var brute: AlienTarget = null
	for child in level.get_children():
		if child is AlienTarget and child.kind == AlienTarget.Kind.BRUTE and child.phase == ShooterTarget.Phase.HIDDEN:
			brute = child
			break
	_check("level contains brutes", brute != null)
	if brute:
		level.vehicle.global_position.z = brute.global_position.z + 20.0
		brute.activate()
		for i in 120:
			await get_tree().physics_frame
			if brute._time > 0.1:
				break
		await _aim_at(brute.center())
		var kills_before := level.kills
		var results: Array = []
		for shot in 3:
			level._cooldown = 0.0
			var aim := level._aim_ray()
			results.append(aim.collider == brute)
			level.shoot()
			await _frames(2)
		_check("brutes survive two hits and die on the third",
			results == [true, true, true] and level.kills == kills_before + 1 and brute.phase == ShooterTarget.Phase.DOWN,
			"aimed=%s kills+%d" % [results, level.kills - kills_before])

	level.vehicle.global_position.z = level._start_z - level.track_length - 1.0
	for i in 900:
		await get_tree().physics_frame
		if level._finished:
			break
	_check("reaching the end of the avenue finishes the level", level._finished)

	print("\n%s — %d failure(s)" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(failures)


func _wait_for_landed(kind: AlienTarget.Kind) -> AlienTarget:
	for i in 1500:
		await get_tree().physics_frame
		for child in level.get_children():
			if child is AlienTarget and child.kind == kind and child.phase == ShooterTarget.Phase.UP and child._time > 0.1:
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
