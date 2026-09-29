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
	var rate := hero.ground_acceleration if input.length() > 0.05 else hero.ground_deceleration
	hero.accelerate_horizontal(input * hero.ground_speed(), rate, delta)
	hero.apply_gravity(delta)
	hero.move_and_slide()
	hero.update_facing(delta, input)
	hero.skin.update_locomotion(hero.horizontal_speed())

	if not hero.is_on_floor():
		finished.emit(Hero.STATE_AIR, {})
