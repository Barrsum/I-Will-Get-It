class_name AlienTarget
extends ShooterTarget
## Glowing invader that drops out of the sky onto its spot (rooftop, window ledge, street),
## then waits to be shot. Bright emissive bodies so they read instantly against the city.
##   GRUNT — green, 100 points
##   FLYER — magenta, hovers and swoops side to side, 250 points
##   BRUTE — big orange, takes 3 hits, 400 points

enum Kind { GRUNT, FLYER, BRUTE }

const DROP_HEIGHT := 26.0
const DROP_TIME := 0.85

const COLORS := {
	Kind.GRUNT: Color(0.35, 1.0, 0.45),
	Kind.FLYER: Color(1.0, 0.3, 0.9),
	Kind.BRUTE: Color(1.0, 0.55, 0.15),
}

var kind := Kind.GRUNT

var _arms: Array[Node3D] = []
var _body_material: StandardMaterial3D
var _glow: OmniLight3D


func _init() -> void:
	health = 1


func configure(new_kind: Kind) -> void:
	kind = new_kind
	health = 3 if kind == Kind.BRUTE else 1


func points() -> int:
	match kind:
		Kind.FLYER:
			return 250
		Kind.BRUTE:
			return 400
	return 100


## Overall size: big enough to read at 30-40 m in daylight.
func size_factor() -> float:
	return 1.95 if kind == Kind.BRUTE else 1.3


func _hit_box() -> AABB:
	var base := AABB(Vector3(-0.5, 0, -0.35), Vector3(1.0, 1.9, 0.7))
	if kind == Kind.FLYER:
		base = AABB(Vector3(-0.8, 0.4, -0.4), Vector3(1.6, 1.0, 0.8))
	var f := size_factor()
	return AABB(base.position * f, base.size * f)


func _build_visual(root: Node3D) -> void:
	var color: Color = COLORS[kind]
	_body_material = StandardMaterial3D.new()
	_body_material.albedo_color = color
	_body_material.emission_enabled = true
	_body_material.emission = color
	_body_material.emission_energy_multiplier = 1.6
	_body_material.roughness = 0.3
	var dark := PlatformerArt.flat(Color(0.05, 0.03, 0.08), 0.4)
	var eye_mat := PlatformerArt.flat(Color(1, 1, 0.85), 0.2, 0.0, 6.0)
	var scale_factor := size_factor()

	var body_root := Node3D.new()
	body_root.scale = Vector3.ONE * scale_factor
	root.add_child(body_root)

	if kind == Kind.FLYER:
		var core := PlatformerArt.sphere(0.42, _body_material, Vector3(1.0, 0.8, 1.0))
		core.position.y = 0.9
		body_root.add_child(core)
		for side in [-1.0, 1.0]:
			var wing := PlatformerArt.box(Vector3(0.9, 0.06, 0.45), _body_material)
			wing.position = Vector3(0.62 * side, 0.95, 0)
			body_root.add_child(wing)
			_arms.append(wing)
		_add_eyes(body_root, eye_mat, 0.95, 0.36)
	else:
		# Squat body, big head, long menacing arms.
		var torso := PlatformerArt.sphere(0.38, _body_material, Vector3(1.0, 1.25, 0.8))
		torso.position.y = 0.85
		body_root.add_child(torso)
		var head := PlatformerArt.sphere(0.34, _body_material, Vector3(1.15, 0.95, 1.0))
		head.position.y = 1.5
		body_root.add_child(head)
		var mouth := PlatformerArt.box(Vector3(0.3, 0.05, 0.05), dark)
		mouth.position = Vector3(0, 1.38, -0.33)
		body_root.add_child(mouth)
		_add_eyes(body_root, eye_mat, 1.56, 0.3)
		for side in [-1.0, 1.0]:
			var shoulder := Node3D.new()
			shoulder.position = Vector3(0.36 * side, 1.1, 0)
			body_root.add_child(shoulder)
			var arm := PlatformerArt.cylinder(0.08, 0.8, _body_material, 10)
			arm.position = Vector3(0.18 * side, -0.3, 0)
			arm.rotation.z = 0.5 * side
			shoulder.add_child(arm)
			_arms.append(shoulder)
			var leg := PlatformerArt.cylinder(0.1, 0.5, dark, 10)
			leg.position = Vector3(0.16 * side, 0.25, 0)
			body_root.add_child(leg)

	_glow = OmniLight3D.new()
	_glow.light_color = color
	_glow.light_energy = 0.8 if kind != Kind.BRUTE else 1.4
	_glow.omni_range = 4.0 * scale_factor
	_glow.position.y = 1.1 * scale_factor
	root.add_child(_glow)


## Three glowing eyes on the side facing the player (-Z).
func _add_eyes(parent: Node3D, material: Material, y: float, z: float) -> void:
	for x in [-0.13, 0.0, 0.13]:
		var eye := PlatformerArt.sphere(0.065 if x != 0.0 else 0.08, material)
		eye.position = Vector3(x, y + (0.06 if x == 0.0 else 0.0), -z)
		parent.add_child(eye)


func _arrival_time() -> float:
	return DROP_TIME + 0.2


## Streaks down from the sky in a glowing capsule, slams onto its spot, shockwave ring.
func _appear() -> void:
	var color: Color = COLORS[kind]
	var start := Vector3(0, DROP_HEIGHT, 0)
	if kind == Kind.FLYER:
		start = Vector3(randf_range(-8.0, 8.0), DROP_HEIGHT * 0.6, -6.0)  # Swoops in at an angle.
	visual.position = start
	visual.scale = Vector3(0.6, 1.4, 0.6)
	var trail := PlatformerArt.cylinder(0.35, 5.0, PlatformerArt.flat(color, 0.2, 0.0, 3.0), 10)
	trail.position = start + Vector3(0, 2.8, 0)
	add_child(trail)
	var tween := create_tween().set_parallel()
	tween.tween_property(visual, "position", Vector3.ZERO, DROP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(trail, "position", Vector3(0, 2.8, 0), DROP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(func() -> void:
		trail.queue_free()
		if kind != Kind.FLYER:
			_shockwave(color))
	tween.chain().tween_property(visual, "scale", Vector3(1.35, 0.65, 1.35), 0.06)
	tween.chain().tween_property(visual, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _shockwave(color: Color) -> void:
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.5
	ring_mesh.outer_radius = 0.65
	var ring := MeshInstance3D.new()
	ring.mesh = ring_mesh
	ring.material_override = PlatformerArt.flat(color, 0.3, 0.0, 2.5)
	ring.position.y = 0.05
	add_child(ring)
	var tween := ring.create_tween().set_parallel()
	tween.tween_property(ring, "scale", Vector3(4.0, 1.0, 4.0), 0.35).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "scale:y", 0.1, 0.35)
	tween.chain().tween_callback(ring.queue_free)


func _idle(_delta: float, t: float) -> void:
	visual.position.y = sin(t * (5.0 if kind == Kind.FLYER else 3.0)) * (0.2 if kind == Kind.FLYER else 0.05)
	for i in _arms.size():
		if kind == Kind.FLYER:
			_arms[i].rotation.z = sin(t * 14.0) * 0.5 * (1.0 if i == 0 else -1.0)
		else:
			_arms[i].rotation.x = sin(t * 4.0 + i * PI) * 0.4 - 0.5


## Flash white on a non-lethal hit (brutes).
func _hurt() -> void:
	_body_material.emission = Color.WHITE
	var tween := create_tween()
	tween.tween_property(visual, "scale", Vector3.ONE * 1.12, 0.05)
	tween.tween_property(visual, "scale", Vector3.ONE, 0.1)
	tween.tween_callback(func() -> void: _body_material.emission = COLORS[kind])


## Bursts into glowing shards.
func _die() -> void:
	var color: Color = COLORS[kind]
	var shard_mat := PlatformerArt.flat(color, 0.3, 0.0, 4.0)
	var origin := center()
	for i in 12:
		var shard := PlatformerArt.box(Vector3.ONE * randf_range(0.08, 0.18), shard_mat)
		level.add_child(shard)
		shard.global_position = origin
		var dir := Vector3(randf_range(-1, 1), randf_range(-0.2, 1.2), randf_range(-1, 1)).normalized()
		var tween := shard.create_tween().set_parallel()
		tween.tween_property(shard, "global_position", origin + dir * randf_range(1.5, 3.0), 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(shard, "scale", Vector3.ZERO, 0.45).set_delay(0.1)
		tween.chain().tween_callback(shard.queue_free)
	_glow.light_energy = 6.0
	var fade := create_tween().set_parallel()
	fade.tween_property(_glow, "light_energy", 0.0, 0.4)
	fade.tween_property(visual, "scale", Vector3.ZERO, 0.12)
	fade.chain().tween_callback(func() -> void: visual.visible = false)
