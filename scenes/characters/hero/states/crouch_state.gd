extends HeroState
## Crouch walking. Toggle or hold depending on Settings.toggle_crouch.


func enter(_previous_state: StringName, _data: Dictionary = {}) -> void:
	hero.set_crouched(true)


func physics_update(delta: float) -> void:
	var wants_stand := hero.crouch_requested if Settings.toggle_crouch else not hero.is_crouch_held()
	wants_stand = wants_stand or (hero.controls_enabled and Input.is_action_just_pressed(&"sprint"))

	if hero.jump_buffer > 0.0 and hero.can_jump() and hero.set_crouched(false):
		hero.jump()
		finished.emit(Hero.STATE_AIR, {})
		return
	if wants_stand and hero.set_crouched(false):
		finished.emit(Hero.STATE_GROUND, {})
		return

	var input := hero.get_move_input()
	var rate := hero.ground_acceleration if input.length() > 0.05 else hero.ground_deceleration
	var speed := hero.crouch_speed * (hero.aim_speed_multiplier if hero.is_aiming else 1.0)
	hero.accelerate_horizontal(input * speed, rate, delta)
	hero.apply_gravity(delta)
	hero.move()
	hero.update_facing(delta, input)
	hero.skin.update_crouch(hero.horizontal_speed())

	if not hero.is_on_floor():
		finished.emit(Hero.STATE_AIR, {})
