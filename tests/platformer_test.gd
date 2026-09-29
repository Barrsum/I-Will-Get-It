extends Node
## Headless gameplay test for Level 1 (platformer rules). Checks side-scroll lock, jump,
## coin block, mushroom growth, brick smashing, stomping, side damage, checkpoint, goal and
## pit death. Run: <godot_console> --headless res://tests/platformer_test.tscn
## Exit code = failed checks. The pit-death check runs last: dying reloads the scene.

const LEVEL := "res://scenes/levels/level_01/level_01.tscn"
const CELL := PlatformerArt.CELL
const GROUND_Y := 2 * CELL

var level: PlatformerLevel
var hero: Hero
var failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.checkpoint_index = -1
	Game.deaths = 0
	level = (load(LEVEL) as PackedScene).instantiate() as PlatformerLevel
	add_child(level)
	hero = level.hero
	await _frames(30)

	# Keep only the two Grumbles the enemy checks use, so nothing wanders into other checks.
	var stomp_target: Grumble
	var side_target: Grumble
	for node in get_tree().get_nodes_in_group(&"grumble"):
		var g := node as Grumble
		var cell_x := int(g.position.x / CELL)
		if cell_x == 26:
			stomp_target = g
		elif cell_x == 35:
			side_target = g
		else:
			g.queue_free()
			continue
		g.set_physics_process(false)  # Dormant until its own check.

	_check("spawns grounded", hero.is_on_floor())
	var start := hero.global_position
	Input.action_press(&"move_right")
	Input.action_press(&"move_forward")  # Must be ignored in side-scroll.
	await _frames(30)
	_release()
	_check("moves right, stays on the Z plane", hero.global_position.x > start.x + 2.0 and absf(hero.global_position.z) < 0.01,
		"pos=%s" % hero.global_position)

	await _place(Vector3(6 * CELL, GROUND_Y, 0))
	Input.action_press(&"jump")
	var peak := hero.global_position.y
	for i in 45:
		await get_tree().physics_frame
		peak = maxf(peak, hero.global_position.y)
	_release()
	_check("big platformer jump (~7 m)", absf(peak - GROUND_Y - hero.jump_height) < 0.4, "%.2f m" % (peak - GROUND_Y))
	await _frames(60)

	await _place(Vector3(12.5 * CELL, GROUND_Y, 0))
	await _jump_and_land()
	_check("coin block gives a coin", level.coins == 1, "coins=%d" % level.coins)

	await _place(Vector3(20.5 * CELL, GROUND_Y, 0))
	await _jump_and_land()
	var mushroom: PowerMushroom = null
	for child in level.get_children():
		if child is PowerMushroom:
			mushroom = child
	_check("mushroom block releases a mushroom", mushroom != null)
	if mushroom:
		await _frames(60)  # Let it finish emerging.
		await _place(mushroom.global_position + Vector3(-0.3, 0.1, 0))
		await _frames(30)
	_check("mushroom makes the hero super-sized", is_equal_approx(hero.size_scale, PlatformerLevel.SUPER_SIZE),
		"size=%.2f" % hero.size_scale)

	var brick := _block_at(21, 5)
	await _place(Vector3(21.5 * CELL, GROUND_Y, 0))
	await _jump_and_land()
	_check("super hero smashes a brick", not is_instance_valid(brick) or brick.is_queued_for_deletion())

	if stomp_target:
		stomp_target.set_physics_process(true)
		stomp_target._active = true
		await _frames(2)
		await _place(stomp_target.global_position + Vector3(-0.2, 4.0, 0))
		var bounced := false
		for i in 60:
			await get_tree().physics_frame
			if stomp_target.is_dead() and hero.velocity.y > 3.0:
				bounced = true
				break
		_check("stomping a Grumble squashes it and bounces", bounced)
	await _frames(40)

	if side_target:
		side_target.set_physics_process(true)
		side_target._active = true
		await _place(side_target.global_position + Vector3(-2.0, 0.05, 0))
		for i in 90:
			await get_tree().physics_frame
			if hero.size_scale < PlatformerLevel.SUPER_SIZE:
				break
		_check("side hit shrinks a super hero instead of killing", is_equal_approx(hero.size_scale, PlatformerLevel.NORMAL_SIZE)
			and not level._dying, "size=%.2f" % hero.size_scale)
		side_target.queue_free()
	await _frames(150)  # Let invulnerability run out.

	# W jumps in side-scroll levels.
	await _place(Vector3(10.5 * CELL, GROUND_Y, 0))
	Input.action_press(&"side_jump")
	await _frames(12)
	Input.action_release(&"side_jump")
	_check("W key jumps in side-scroll mode", hero.global_position.y > GROUND_Y + 1.0, "y=%.2f" % hero.global_position.y)
	await _frames(60)

	# Grumble AI: turns back at a pit edge (ground starts at cell 94 after the pit).
	var edge_walker := _spawn_grumble(96.0 * CELL, -1.0)
	var bumper_a := _spawn_grumble(107.0 * CELL, 1.0)
	var bumper_b := _spawn_grumble(111.0 * CELL, -1.0)
	await _frames(150)
	_check("Grumble turns around at a pit edge instead of falling", edge_walker.global_position.y > GROUND_Y - 0.1
		and edge_walker.direction > 0.0, "pos=%s dir=%.0f" % [edge_walker.global_position, edge_walker.direction])
	_check("two Grumbles bump and bounce apart (never pass through)", bumper_a.global_position.x < bumper_b.global_position.x
		and bumper_a.direction < 0.0 and bumper_b.direction > 0.0,
		"a=%.1f b=%.1f" % [bumper_a.global_position.x, bumper_b.global_position.x])
	for g in [edge_walker, bumper_a, bumper_b]:
		g.queue_free()

	await _place(Vector3(80.5 * CELL, GROUND_Y, 0))
	await _frames(5)
	_check("checkpoint is recorded", Game.checkpoint_index == 0, "index=%d" % Game.checkpoint_index)

	await _place(Vector3(157.5 * CELL, GROUND_Y, 0))
	Input.action_press(&"move_right")
	Input.action_press(&"jump")
	for i in 90:
		await get_tree().physics_frame
		if level._complete:
			break
	_release()
	_check("touching the flagpole completes the level", level._complete)
	await _frames(150)  # Let the flag-slide sequence finish before reusing the hero.
	level._complete = false
	hero.set_frozen(false)
	await _frames(10)

	await _place(Vector3(60.5 * CELL, GROUND_Y + 1.0, 0), 1)
	for i in 60:  # Poll: a death reloads the scene shortly after.
		await get_tree().physics_frame
		if level._dying:
			break
	_check("falling into a pit kills the hero", level._dying and Game.deaths == 1, "deaths=%d" % Game.deaths)

	print("\n%s — %d failure(s)" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(failures)


func _spawn_grumble(x: float, direction: float) -> Grumble:
	var g := Grumble.new()
	g.level = level
	g.direction = direction
	g.position = Vector3(x, GROUND_Y + 0.05, 0)
	level.add_child(g)
	g._active = true
	return g


func _block_at(cell_x: int, cell_y: int) -> BumpBlock:
	var where := Vector3((cell_x + 0.5) * CELL, (cell_y + 0.5) * CELL, 0)
	for child in level.get_children():
		if child is BumpBlock and child.position.distance_to(where) < 0.1:
			return child
	return null


func _place(where: Vector3, settle := 15) -> void:
	_release()
	hero.global_position = where
	hero.velocity = Vector3.ZERO
	hero.reset_physics_interpolation()
	await _frames(settle)


func _jump_and_land() -> void:
	Input.action_press(&"jump")
	await _frames(40)
	_release()
	await _frames(60)


func _release() -> void:
	for action in [&"move_left", &"move_right", &"move_forward", &"jump", &"side_jump", &"sprint", &"crouch"]:
		Input.action_release(action)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(label: String, ok: bool, detail := "") -> void:
	if not ok:
		failures += 1
	print("%s  %s%s" % ["PASS" if ok else "FAIL", label, ("  (" + detail + ")") if detail else ""])
