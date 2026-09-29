extends HeroState
## Dance emote. Any movement, jump or crouch cancels it; the camera pulls out to face the hero.


func enter(_previous_state: StringName, _data: Dictionary = {}) -> void:
	hero.set_horizontal_velocity(Vector3.ZERO)
	hero.skin.play_emote()
	hero.camera.set_emote_view(true)


func exit() -> void:
	hero.camera.set_emote_view(false)


func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"emote"):
		finished.emit(Hero.STATE_GROUND, {})


func physics_update(delta: float) -> void:
	hero.apply_gravity(delta)
	hero.move_and_slide()
	var interrupted := hero.get_move_input().length() > 0.2 or hero.jump_buffer > 0.0 or hero.crouch_requested
	if interrupted or not hero.is_on_floor():
		finished.emit(Hero.STATE_GROUND, {})
