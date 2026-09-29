extends HeroState
## Sprint + crouch: a momentum slide that speeds up downhill and bleeds speed on flat ground.


func enter(_previous_state: StringName, _data: Dictionary = {}) -> void:
	hero.set_crouched(true)
	var horizontal := hero.horizontal_velocity()
	var direction := horizontal.normalized() if horizontal.length() > 0.1 else hero.facing_direction()
	var speed := minf(horizontal.length() + hero.slide_boost, hero.slide_max_speed)
	hero.set_horizontal_velocity(direction * speed)
	hero.skin.play_slide()


func exit() -> void:
	hero.skin.end_slide()


func physics_update(delta: float) -> void:
	if hero.jump_buffer > 0.0 and hero.can_jump() and hero.set_crouched(false):
		hero.jump()  # Slide-jump keeps all horizontal momentum.
		finished.emit(Hero.STATE_AIR, {})
		return
	var cancel := hero.crouch_requested if Settings.toggle_crouch else not Input.is_action_pressed(&"crouch")
	if cancel and hero.set_crouched(false):
		finished.emit(Hero.STATE_GROUND, {})
		return

	var horizontal := hero.horizontal_velocity()
	var input := hero.get_move_input()
	if input.length() > 0.1 and horizontal.length() > 0.1:
		var steered := horizontal.normalized().slerp(input.normalized(), clampf(hero.slide_steering * delta, 0.0, 1.0))
		horizontal = steered * horizontal.length()
	if hero.is_on_floor():
		# Gravity pulls along the slope; friction always opposes motion.
		var downhill := Vector3.DOWN.slide(hero.get_floor_normal())
		horizontal += Vector3(downhill.x, 0.0, downhill.z) * hero.slide_slope_acceleration * delta
		horizontal = horizontal.move_toward(Vector3.ZERO, hero.slide_friction * delta)
	hero.set_horizontal_velocity(horizontal.limit_length(hero.slide_max_speed))

	hero.apply_gravity(delta)
	hero.move_and_slide()
	hero.update_facing(delta, hero.horizontal_velocity())

	if not hero.is_on_floor():
		finished.emit(Hero.STATE_AIR, {})
	elif hero.horizontal_speed() < hero.slide_exit_speed:
		var keep_crouch := Settings.toggle_crouch or Input.is_action_pressed(&"crouch")
		if keep_crouch or not hero.set_crouched(false):
			finished.emit(Hero.STATE_CROUCH, {})
		else:
			finished.emit(Hero.STATE_GROUND, {})
