extends HeroState
## Jumping and falling. Keeps take-off momentum, steers with air control, and
## auto-mantles onto ledges the hero moves into.

## Crouch pressed mid-air: land straight into a slide if fast enough.
var _crouch_queued := false


func enter(_previous_state: StringName, _data: Dictionary = {}) -> void:
	_crouch_queued = false
	if hero.velocity.y <= 0.0:
		hero.skin.play_fall()


func physics_update(delta: float) -> void:
	if hero.is_crouched:
		hero.set_crouched(false)
	if hero.crouch_requested:
		_crouch_queued = true
	if hero.jump_buffer > 0.0 and hero.coyote > 0.0:
		hero.jump()

	var input := hero.get_move_input()
	var horizontal := hero.horizontal_velocity()
	if input.length() > 0.05:
		# Steering never adds speed beyond what we took off with (or a jog).
		var jog := hero.jog_speed * (hero.aim_speed_multiplier if hero.is_aiming else 1.0)
		hero.accelerate_horizontal(input * maxf(horizontal.length(), jog), hero.air_acceleration, delta)
	else:
		hero.accelerate_horizontal(Vector3.ZERO, hero.air_drag, delta)

	var fall_speed := -hero.velocity.y
	hero.apply_gravity(delta)
	hero.move_and_slide()
	hero.update_facing(delta, input)
	hero.skin.update_air(hero.velocity.y)

	if input.length() > 0.3 and hero.velocity.y < 2.5:
		var ledge := hero.find_mantle_ledge(input)
		if not ledge.is_empty():
			finished.emit(Hero.STATE_MANTLE, ledge)
			return

	if hero.is_on_floor():
		hero.landed.emit(fall_speed)
		hero.skin.play_land(fall_speed)
		if _crouch_queued and hero.horizontal_speed() >= hero.slide_min_entry_speed:
			finished.emit(Hero.STATE_SLIDE, {})
		else:
			finished.emit(Hero.STATE_GROUND, {})
