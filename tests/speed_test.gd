extends Node
## Headless gameplay test for Level 3 (speed platformer), driven by real input where possible.
## Run: <godot_console> --headless res://tests/speed_test.tscn   (exit code = failed checks)

const LEVEL := "res://scenes/levels/level_03/level_03.tscn"

var level: SpeedLevel
var hero: Hero
var failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.deaths = 0
	level = (load(LEVEL) as PackedScene).instantiate() as SpeedLevel
	add_child(level)
	hero = level.hero
	await _frames(30)
	_check("spawns grounded", hero.is_on_floor())

	# One continuous run: boost pads -> loop 1 -> boosted ramp jump over the gap.
	await _place(Vector3(0, 0.1, -10))
	Input.action_press(&"move_forward")
	var top_speed := 0.0
	var rode_loop := false
	var loop_peak := -INF
	var exit_x := 0.0
	for i in 400:
		await get_tree().physics_frame
		top_speed = maxf(top_speed, hero.horizontal_speed())
		if hero.current_state() == Hero.STATE_RAIL:
			rode_loop = true
			loop_peak = maxf(loop_peak, hero.global_position.y)
		elif rode_loop and exit_x == 0.0:
			exit_x = hero.global_position.x
		if hero.global_position.z < -95.0 and hero.is_on_floor():
			break
	Input.action_release(&"move_forward")
	_check("boost pads launch the hero past 20 m/s", top_speed > 20.0, "top %.1f m/s" % top_speed)
	_check("fast entry rides the loop over the top", rode_loop and loop_peak > 13.0, "peak %.1f m" % loop_peak)
	_check("loop exits into the shifted lane", absf(exit_x - 4.0) < 0.8, "exit x %.2f" % exit_x)
	_check("boosted ramp jump clears the gap onto the runway",
		hero.global_position.z < -88.0 and hero.global_position.y > -1.0 and Game.deaths == 0,
		"pos=%s deaths=%d" % [hero.global_position, Game.deaths])

	# Too slow for the loop: jog in and just pass underneath.
	await _place(Vector3(0, 0.1, -36))
	Input.action_press(&"move_forward")
	var entered := false
	for i in 90:
		await get_tree().physics_frame
		entered = entered or hero.current_state() == Hero.STATE_RAIL
	Input.action_release(&"move_forward")
	_check("a slow approach doesn't ride the loop", not entered)

	# Coin gate: blocked without coins, opens with them.
	level.coins = 0
	await _place(Vector3(0, 0.1, -132))
	Input.action_press(&"move_forward")
	await _frames(90)
	_check("coin gate blocks the way without enough coins", hero.global_position.z > -140.5,
		"z=%.2f" % hero.global_position.z)
	for i in 25:
		level.add_coin()
	await _frames(60)
	_check("coin gate opens with enough coins", hero.global_position.z < -141.0, "z=%.2f" % hero.global_position.z)

	# Spring up to the high ridge (keep running forward).
	var ridge := false
	for i in 240:
		await get_tree().physics_frame
		if hero.is_on_floor() and hero.global_position.y > 9.0:
			ridge = true
			break
	Input.action_release(&"move_forward")
	_check("spring launches the hero up onto the high ridge", ridge, "pos=%s" % hero.global_position)

	# Falling off respawns at the last checkpoint.
	var deaths := Game.deaths
	hero.global_position = Vector3(30, -18, -200)
	hero.velocity = Vector3.ZERO
	await _frames(10)
	# Last checkpoint crossed in this run is the runway one (z = -95); the ridge one wasn't reached.
	_check("falling respawns at the last checkpoint crossed and counts a fall",
		Game.deaths == deaths + 1 and absf(hero.global_position.z + 95.0) < 0.5 and absf(hero.global_position.y) < 0.5,
		"pos=%s" % hero.global_position)

	await _place(Vector3(0, 0.1, -275))
	Input.action_press(&"move_forward")
	for i in 120:
		await get_tree().physics_frame
		if level._finished:
			break
	Input.action_release(&"move_forward")
	_check("running through the arch finishes the level", level._finished)

	print("\n%s — %d failure(s)" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(failures)


func _place(where: Vector3) -> void:
	for action in [&"move_forward", &"jump", &"sprint", &"crouch"]:
		Input.action_release(action)
	hero.state_machine.transition_to(Hero.STATE_GROUND)
	hero.global_position = where
	hero.velocity = Vector3.ZERO
	hero.camera.yaw = 0.0
	hero.reset_physics_interpolation()
	await _frames(15)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(label: String, ok: bool, detail := "") -> void:
	if not ok:
		failures += 1
	print("%s  %s%s" % ["PASS" if ok else "FAIL", label, ("  (" + detail + ")") if detail else ""])
