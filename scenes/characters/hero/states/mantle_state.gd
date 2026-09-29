extends HeroState
## Scripted pull-up onto a ledge found by Hero.find_mantle_ledge().
## Collision is off for the move; the path was validated before entering.

const MIN_DURATION := 0.24
const MAX_DURATION := 0.42

var _start: Vector3
var _target: Vector3
var _duration := MIN_DURATION
var _elapsed := 0.0


func enter(_previous_state: StringName, data: Dictionary = {}) -> void:
	_start = hero.global_position
	_target = data.target
	_duration = lerpf(MIN_DURATION, MAX_DURATION, clampf(data.height / hero.mantle_max_height, 0.0, 1.0))
	_elapsed = 0.0
	hero.velocity = Vector3.ZERO
	hero.collision_shape.disabled = true
	hero.face_direction_instantly(-data.wall_normal)
	hero.skin.play_mantle(_duration)


func exit() -> void:
	hero.collision_shape.disabled = false


func physics_update(delta: float) -> void:
	_elapsed += delta
	var t := minf(_elapsed / _duration, 1.0)
	# Rise first, then roll over the lip.
	var rise := ease(clampf(t / 0.7, 0.0, 1.0), 0.4)
	var over := smoothstep(0.35, 1.0, t)
	hero.global_position = Vector3(
		lerpf(_start.x, _target.x, over),
		lerpf(_start.y, _target.y + 0.02, rise),
		lerpf(_start.z, _target.z, over))
	if t >= 1.0:
		hero.set_horizontal_velocity(hero.facing_direction() * hero.jog_speed * 0.5)
		finished.emit(Hero.STATE_GROUND, {})
