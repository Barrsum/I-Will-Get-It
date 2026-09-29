extends HeroState
## Follows a Path3D at a fixed speed (loop-de-loops, later grind rails), body aligned to the
## track so the hero runs upside-down through loops. Exits into Air with the track's momentum.

var _path: Path3D
var _offset := 0.0
var _length := 0.0
var _speed := 0.0


func enter(_previous_state: StringName, data: Dictionary = {}) -> void:
	_path = data.path
	_speed = data.speed
	var curve := _path.curve
	_length = curve.get_baked_length()
	_offset = curve.get_closest_offset(_path.to_local(hero.global_position))
	hero.velocity = Vector3.ZERO
	hero.collision_shape.disabled = true
	hero.set_crouched(false)
	var camera_point: Variant = data.get("camera_point")
	if camera_point != null:
		hero.camera.set_view_point(camera_point)


func exit() -> void:
	hero.collision_shape.disabled = false
	# Stand upright again, keeping the heading; follow camera swings back in behind.
	var yaw := hero.visual_root.global_rotation.y
	hero.visual_root.rotation = Vector3(0.0, yaw, 0.0)
	hero.camera.set_view_point(null, yaw + PI)


func physics_update(delta: float) -> void:
	_offset = minf(_offset + _speed * delta, _length)
	var xf := _path.global_transform * _path.curve.sample_baked_with_rotation(_offset, true, true)
	hero.global_position = xf.origin
	# Path frames look down -Z; the model faces +Z.
	hero.visual_root.global_basis = xf.basis * Basis(Vector3.UP, PI)
	hero.skin.update_locomotion(_speed)
	if _offset >= _length:
		var forward := -xf.basis.z
		var heading := Vector3(forward.x, 0.0, forward.z).normalized()
		hero.velocity = heading * _speed
		hero.visual_root.rotation = Vector3(0.0, atan2(heading.x, heading.z), 0.0)
		finished.emit(Hero.STATE_AIR, {})
