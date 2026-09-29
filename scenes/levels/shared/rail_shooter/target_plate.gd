class_name TargetPlate
extends StaticBody3D
## Pop-up shooting target. Lies flat until activated, flips up to face the player's path,
## stays up for `lifetime` seconds, then drops (escaped). Kinds:
##   NORMAL   — red/white bullseye, 100 points
##   BONUS    — small gold plate that sways side to side, 300 points
##   FRIENDLY — blue plate with a heart: don't shoot it (penalty, breaks the combo)

enum Kind { NORMAL, BONUS, FRIENDLY }
enum Phase { HIDDEN, UP, DOWN }

const LAYER_TARGET := 16

var kind := Kind.NORMAL
var level: RailShooterLevel
var lifetime := 3.5
## Side-to-side travel (metres, each way) while up.
var sway := 0.0
## World point the plate should face when up (a spot on the player's path).
var face_point := Vector3.ZERO
## Wall-mounted plates have no post.
var has_post := true
## The hero's Z at which this target pops up.
var trigger_z := 0.0

var phase := Phase.HIDDEN

var _hinge: Node3D
var _shape: CollisionShape3D
var _time := 0.0
var _home := Vector3.ZERO
var _radius := 0.7


func _ready() -> void:
	collision_layer = LAYER_TARGET
	collision_mask = 0
	var to_face := face_point - global_position
	to_face.y = 0.0
	if to_face.length_squared() > 0.01:
		global_basis = Basis.looking_at(to_face.normalized())
	_home = position
	_radius = 0.45 if kind == Kind.BONUS else 0.7
	var plate_height := (1.25 if has_post else 0.0) + _radius

	_shape = CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = _radius
	cylinder.height = 0.15
	_shape.shape = cylinder
	_shape.rotation.x = PI * 0.5
	_shape.position.y = plate_height
	_shape.disabled = true
	add_child(_shape)

	_hinge = Node3D.new()
	add_child(_hinge)
	if has_post:
		var post := PlatformerArt.cylinder(0.05, 1.25, PlatformerArt.flat(Color(0.3, 0.3, 0.34), 0.5, 0.6))
		post.position.y = 0.62
		_hinge.add_child(post)
	var face := Node3D.new()
	face.position.y = plate_height
	_hinge.add_child(face)
	_build_face(face)
	_hinge.rotation.x = -PI * 0.5  # Lying flat, face down, until activated.


func activate() -> void:
	if phase != Phase.HIDDEN:
		return
	phase = Phase.UP
	_time = 0.0
	var tween := create_tween()
	tween.tween_property(_hinge, "rotation:x", 0.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void: _shape.disabled = false)


## Returns true if this shot counts (the plate was up).
func hit() -> bool:
	if phase != Phase.UP:
		return false
	phase = Phase.DOWN
	_shape.set_deferred(&"disabled", true)
	var tween := create_tween().set_parallel()
	tween.tween_property(_hinge, "rotation:x", -PI * 0.5, 0.18).set_ease(Tween.EASE_IN)
	tween.tween_property(_hinge, "rotation:z", randf_range(-0.6, 0.6), 0.18)
	return true


func points() -> int:
	match kind:
		Kind.BONUS:
			return 300
		Kind.FRIENDLY:
			return 0
	return 100


func is_hostile() -> bool:
	return kind != Kind.FRIENDLY


func center() -> Vector3:
	return _shape.global_position


func _process(delta: float) -> void:
	if phase != Phase.UP:
		return
	_time += delta
	if sway > 0.0:
		position = _home + global_basis.x * sin(_time * 2.4) * sway
	if _time > lifetime:
		phase = Phase.DOWN
		_shape.set_deferred(&"disabled", true)
		create_tween().tween_property(_hinge, "rotation:x", -PI * 0.5, 0.3)
		level.on_target_escaped(self)


func _build_face(face: Node3D) -> void:
	var rings: Array
	match kind:
		Kind.NORMAL:
			rings = [Color(0.95, 0.95, 0.95), Color(0.9, 0.12, 0.14), Color(0.95, 0.95, 0.95), Color(0.9, 0.12, 0.14)]
		Kind.BONUS:
			rings = [Color(1.0, 0.8, 0.15), Color(1.0, 0.95, 0.6), Color(1.0, 0.8, 0.15)]
		Kind.FRIENDLY:
			rings = [Color(0.95, 0.95, 0.95), Color(0.35, 0.6, 1.0)]
	var emission := 0.6 if kind == Kind.BONUS else 0.0
	for i in rings.size():
		var r := _radius * (1.0 - float(i) / rings.size())
		var disc := PlatformerArt.cylinder(r, 0.08, PlatformerArt.flat(rings[i], 0.5, 0.0, emission), 32)
		disc.rotation.x = PI * 0.5
		disc.position.z = -0.012 * i  # Stack toward the viewer (the body's -Z faces face_point).
		face.add_child(disc)
	if kind == Kind.FRIENDLY:
		_build_heart(face)


## Flat white heart (two circles + a diamond) on the friendly plate.
func _build_heart(face: Node3D) -> void:
	var white := PlatformerArt.flat(Color(1, 1, 1), 0.4, 0.0, 0.3)
	var heart := Node3D.new()
	heart.position.z = -0.07
	face.add_child(heart)
	for side in [-1.0, 1.0]:
		var lobe := PlatformerArt.cylinder(0.17, 0.04, white, 24)
		lobe.rotation.x = PI * 0.5
		lobe.position = Vector3(0.12 * side, 0.08, 0)
		heart.add_child(lobe)
	var point := PlatformerArt.box(Vector3(0.3, 0.3, 0.04), white)
	point.rotation.z = PI * 0.25
	point.position.y = -0.06
	heart.add_child(point)
