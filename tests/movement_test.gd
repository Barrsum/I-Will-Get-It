extends Node
## Headless movement regression test. Drives the hero in the test gym with simulated input
## and checks speeds, jump height, crouch, slide, mantle, stairs and respawn.
## Run from the repo root:  <godot_console> --headless res://tests/movement_test.tscn
## (a scene rather than `-s`, so autoloads like Settings exist). Exit code = failed checks.

const GYM := "res://scenes/levels/test_gym/test_gym.tscn"
const ACTIONS: Array[StringName] = [&"move_forward", &"move_back", &"move_left", &"move_right",
	&"jump", &"sprint", &"crouch", &"aim"]

var hero: Hero
var failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var level: Node = (load(GYM) as PackedScene).instantiate()
	add_child(level)
	hero = level.get_node("Hero") as Hero
	Settings.sprint_by_default = false
	Settings.toggle_crouch = true
	await _frames(30)
	_check("spawns grounded in Ground state", hero.is_on_floor() and hero.current_state() == Hero.STATE_GROUND)

	await _test_jog_sprint_slide()
	await _test_jump()
	await _test_crouch_tunnel()
	await _test_mantle(0.0, 2.0, true)
	await _test_mantle(-7.0, 1.0, true)
	await _test_mantle(10.5, 3.6, false)
	await _test_slope_slide()
	await _test_stairs()
	await _test_respawn()

	print("\n%s — %d failure(s)" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(failures)


func _test_jog_sprint_slide() -> void:
	await _teleport(Vector3(40, 0.05, 40), 0.0)
	Input.action_press(&"move_forward")
	await _frames(45)
	_check_near("jog speed", hero.horizontal_speed(), hero.jog_speed, 0.25)
	Input.action_press(&"sprint")
	await _frames(40)
	_check_near("sprint speed", hero.horizontal_speed(), hero.sprint_speed, 0.25)
	await _tap(&"crouch")
	await _frames(2)
	_check("sprint + crouch starts a slide", hero.current_state() == Hero.STATE_SLIDE)
	_check("slide boosts speed", hero.horizontal_speed() > hero.sprint_speed + 1.0)
	_release_all()
	await _frames(120)
	_check("slide on flat ground decays into crouch", hero.current_state() == Hero.STATE_CROUCH and hero.is_crouched)
	await _tap(&"crouch")
	await _frames(3)
	_check("crouch toggle stands back up", hero.current_state() == Hero.STATE_GROUND and not hero.is_crouched)


func _test_jump() -> void:
	await _teleport(Vector3(40, 0.05, 40), 0.0)
	var start_y := hero.global_position.y
	Input.action_press(&"jump")
	var peak := await _track_peak(40)
	Input.action_release(&"jump")
	_check_near("full jump height", peak - start_y, hero.jump_height, 0.12)
	await _frames(60)
	_check("lands back in Ground", hero.current_state() == Hero.STATE_GROUND)

	start_y = hero.global_position.y
	await _tap(&"jump")
	peak = await _track_peak(40)
	_check("tap jump is a short hop (< 70% height)", peak - start_y < hero.jump_height * 0.7,
		"%.2f m" % (peak - start_y))
	await _frames(60)


func _test_crouch_tunnel() -> void:
	await _teleport(Vector3(13.5, 0.05, 7.5), 0.0)
	await _tap(&"crouch")
	Input.action_press(&"move_forward")
	await _frames(80)
	Input.action_release(&"move_forward")
	_check("crouch-walks into the 1.3 m tunnel", hero.global_position.z < 4.0 and hero.is_crouched,
		"z=%.2f" % hero.global_position.z)
	await _tap(&"crouch")
	await _frames(5)
	_check("cannot stand up under the tunnel roof", hero.is_crouched and hero.current_state() == Hero.STATE_CROUCH)
	await _teleport(Vector3(40, 0.05, 40), 0.0)


func _test_mantle(x: float, height: float, should_mantle: bool) -> void:
	await _teleport(Vector3(x, 0.05, -10.5), 0.0)
	Input.action_press(&"move_forward")
	await _frames(8)
	Input.action_press(&"jump")
	var mantled := false
	for i in 90:
		await get_tree().physics_frame
		mantled = mantled or hero.current_state() == Hero.STATE_MANTLE
		# Let go as soon as we're standing on top, or we'd run off the far side.
		if hero.is_on_floor() and hero.global_position.y > height - 0.1:
			break
	_release_all()
	await _frames(10)
	var on_top := absf(hero.global_position.y - height) < 0.15 and hero.global_position.z < -12.6
	if should_mantle:
		# Low walls may be cleared by the jump alone; either way we must end up on top.
		_check("gets on top of %.1f m wall" % height, on_top,
			"pos=%s, mantled=%s" % [hero.global_position, mantled])
	else:
		_check("cannot mantle %.1f m wall" % height, not mantled and hero.global_position.y < 0.5,
			"pos=%s" % hero.global_position)


func _test_slope_slide() -> void:
	await _teleport(Vector3(-20, 9.4, -20.0), PI)
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	await _frames(30)
	await _tap(&"crouch")
	var top_speed := 0.0
	for i in 150:
		await get_tree().physics_frame
		if hero.current_state() == Hero.STATE_SLIDE:
			top_speed = maxf(top_speed, hero.horizontal_speed())
	_release_all()
	_check("sliding downhill builds speed past sprint", top_speed > hero.sprint_speed + 3.0,
		"top %.1f m/s" % top_speed)
	await _frames(30)


func _test_stairs() -> void:
	await _teleport(Vector3(20, 0.05, 16), 0.0)
	Input.action_press(&"move_forward")
	await _frames(110)
	_release_all()
	await _frames(10)
	_check_near("walks up the stairs to the 3 m platform", hero.global_position.y, 3.0, 0.1)


func _test_respawn() -> void:
	await _teleport(Vector3(0, -40, 0), 0.0)
	await _frames(3)
	_check("falling out of the world respawns", hero.global_position.distance_to(Vector3(0, 0.05, 6)) < 0.5,
		"pos=%s" % hero.global_position)


# --- Helpers -----------------------------------------------------------------------------------

func _teleport(pos: Vector3, yaw: float) -> void:
	_release_all()
	hero.state_machine.transition_to(Hero.STATE_GROUND)
	hero.is_crouched = true
	hero.set_crouched(false)
	hero.global_position = pos
	hero.velocity = Vector3.ZERO
	hero.camera.yaw = yaw
	hero.reset_physics_interpolation()
	await _frames(20)


func _track_peak(frames: int) -> float:
	var peak := hero.global_position.y
	for i in frames:
		await get_tree().physics_frame
		peak = maxf(peak, hero.global_position.y)
	return peak


func _tap(action: StringName) -> void:
	Input.action_press(action)
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(action)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _release_all() -> void:
	for action in ACTIONS:
		Input.action_release(action)


func _check(label: String, ok: bool, detail := "") -> void:
	if not ok:
		failures += 1
	print("%s  %s%s" % ["PASS" if ok else "FAIL", label, ("  (" + detail + ")") if detail else ""])


func _check_near(label: String, value: float, expected: float, tolerance: float) -> void:
	_check(label, absf(value - expected) <= tolerance, "%.2f, expected %.2f ± %.2f" % [value, expected, tolerance])
