extends HeroState
## Standing, jogging and sprinting on the floor.


func enter(_previous_state: StringName, _data: Dictionary = {}) -> void:
	hero.set_crouched(false)


func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"emote") and hero.is_on_floor():
		finished.emit(Hero.STATE_EMOTE, {})


func physics_update(delta: float) -> void:
	if hero.jump_buffer > 0.0 and hero.can_jump():
		hero.jump()
		finished.emit(Hero.STATE_AIR, {})
		return
	if hero.crouch_requested:
		var fast_enough := hero.horizontal_speed() >= hero.slide_min_entry_speed
		finished.emit(Hero.STATE_SLIDE if fast_enough else Hero.STATE_CROUCH, {})
		return

	var input := hero.get_move_input()
	var target := input * hero.ground_speed()
	hero.accelerate_horizontal(target, hero.ground_rate(target), delta)
	hero.apply_gravity(delta)
	hero.move()
	hero.update_facing(delta, input)
	hero.skin.update_locomotion(hero.horizontal_speed())

	if not hero.is_on_floor():
		if hero.velocity.y > 1.0:
			hero.launched_rise = true  # Ran off a ramp lip: keep the whole arc.
		finished.emit(Hero.STATE_AIR, {})
