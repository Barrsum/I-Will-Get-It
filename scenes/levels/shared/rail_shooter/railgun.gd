class_name Railgun
extends Node3D
## Rail blaster: sits on a mount node (a hand, or a vehicle turret pivot) and points at the
## crosshair target; also owns the beam / muzzle / impact effects. Placeholder primitives until
## a Blender model replaces _build_model().

const BEAM_COLOR := Color(0.35, 0.95, 1.0)
const MUZZLE_OFFSET := Vector3(0, 0.03, -0.42)

## Node the gun sits on (HeroSkin.right_hand() or a turret pivot).
var mount: Node3D
## Model size multiplier (2+ for a vehicle-mounted turret).
var scale_factor := 1.0


func _ready() -> void:
	top_level = true
	_build_model()
	for child in get_children():
		(child as Node3D).position *= scale_factor
		(child as Node3D).scale *= scale_factor


## Snap to the hand and point at `target` (call every frame).
func aim_at(target: Vector3) -> void:
	if mount == null:
		return
	global_position = mount.global_position
	if global_position.distance_squared_to(target) > 0.01:
		look_at(target, Vector3.UP)


func muzzle_position() -> Vector3:
	return global_transform * (MUZZLE_OFFSET * scale_factor)


func fire_effects(target: Vector3, hit_something: bool) -> void:
	var from := muzzle_position()
	var parent := get_parent()
	var beam_material := PlatformerArt.flat(BEAM_COLOR, 0.2, 0.0, 4.0)
	var length := from.distance_to(target)
	if length > 0.05:
		var beam := PlatformerArt.cylinder(0.035 * sqrt(scale_factor), length, beam_material, 8)
		parent.add_child(beam)
		beam.look_at_from_position((from + target) * 0.5, target, Vector3.UP)
		beam.rotate_object_local(Vector3.RIGHT, -PI * 0.5)  # Cylinder axis (Y) onto the beam.
		var tween := beam.create_tween()
		tween.tween_property(beam, "scale", Vector3(0.0, 1.0, 0.0), 0.16).set_ease(Tween.EASE_IN)
		tween.tween_callback(beam.queue_free)
	_flash(from, 0.16 * sqrt(scale_factor), 0.08)
	if hit_something:
		_flash(target, 0.35, 0.18)


func _flash(where: Vector3, size: float, duration: float) -> void:
	var flash := PlatformerArt.sphere(size, PlatformerArt.flat(BEAM_COLOR, 0.2, 0.0, 6.0))
	get_parent().add_child(flash)
	flash.global_position = where
	var tween := flash.create_tween()
	tween.tween_property(flash, "scale", Vector3.ONE * 1.8, duration * 0.5)
	tween.tween_property(flash, "scale", Vector3.ZERO, duration * 0.5)
	tween.tween_callback(flash.queue_free)


func _build_model() -> void:
	var body_mat := PlatformerArt.flat(Color(0.18, 0.2, 0.26), 0.35, 0.6)
	var trim_mat := PlatformerArt.flat(Color(0.9, 0.92, 0.95), 0.4, 0.3)
	var glow_mat := PlatformerArt.flat(BEAM_COLOR, 0.2, 0.0, 3.0)
	var body := PlatformerArt.box(Vector3(0.09, 0.12, 0.34), body_mat)
	body.position = Vector3(0, 0.03, -0.12)
	add_child(body)
	var grip := PlatformerArt.box(Vector3(0.07, 0.14, 0.08), body_mat)
	grip.position = Vector3(0, -0.06, -0.01)
	grip.rotation.x = 0.25
	add_child(grip)
	for side in [-1.0, 1.0]:
		var rail := PlatformerArt.box(Vector3(0.025, 0.035, 0.3), trim_mat)
		rail.position = Vector3(0.035 * side, 0.03, -0.3)
		add_child(rail)
	var core := PlatformerArt.box(Vector3(0.02, 0.02, 0.26), glow_mat)
	core.position = Vector3(0, 0.03, -0.3)
	add_child(core)
