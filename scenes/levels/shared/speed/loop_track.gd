class_name LoopTrack
extends Node3D
## Vertical loop-de-loop. Enter from this node's origin running along -Z fast enough and the
## hero rides the loop (Rail state), coming out shifted sideways by `side_shift` so the exit lane
## doesn't overlap the entry. Too slow and you just run underneath.
## Local layout: entry straight (lead_in) -> loop of `radius` -> exit straight (lead_out).

signal too_slow

@export var radius := 8.0
@export var lead_in := 4.0
@export var lead_out := 10.0
@export var side_shift := 4.0
@export var min_speed := 13.0
@export var ride_speed := 22.0
@export var track_width := 4.0

var path: Path3D


func _ready() -> void:
	path = Path3D.new()
	path.curve = _build_curve()
	add_child(path)
	_build_ribbon()
	var trigger := Area3D.new()
	trigger.collision_layer = 0
	trigger.collision_mask = Hero.LAYER_HERO
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(track_width, 2.5, 1.5)
	shape.position = Vector3(0, 1.25, -0.5)
	trigger.add_child(shape)
	add_child(trigger)
	trigger.body_entered.connect(_on_body_entered)


## World position where the loop's exit straight ends.
func exit_position() -> Vector3:
	return to_global(Vector3(side_shift, 0, -lead_in - lead_out))


func _on_body_entered(body: Node3D) -> void:
	var hero := body as Hero
	if hero == null or hero.current_state() == Hero.STATE_RAIL:
		return
	var along := hero.horizontal_velocity().dot(-global_basis.z)
	if along >= min_speed:
		# Watch from beside the loop, on the side away from the exit lane, like a classic side view.
		var side := -1.0 if side_shift >= 0.0 else 1.0
		var watch := to_global(Vector3(side * radius * 2.4, radius * 1.1, -lead_in))
		hero.ride_path(path, maxf(ride_speed, along), watch)
	elif along > 1.0:
		too_slow.emit()


func _build_curve() -> Curve3D:
	var curve := Curve3D.new()
	curve.bake_interval = 0.2
	curve.add_point(Vector3(0, 0, 1.0))
	curve.add_point(Vector3(0, 0, -lead_in))
	var steps := 48
	for i in range(1, steps):
		var theta := TAU * i / steps
		curve.add_point(Vector3(side_shift * theta / TAU, radius - radius * cos(theta), -lead_in - radius * sin(theta)))
	curve.add_point(Vector3(side_shift, 0, -lead_in))
	curve.add_point(Vector3(side_shift, 0, -lead_in - lead_out))
	return curve


## Flat track strip swept along the path, facing the rider (inside of the loop).
func _build_ribbon() -> void:
	var curve := path.curve
	var length := curve.get_baked_length()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := 0.4
	var prev_left := Vector3.ZERO
	var prev_right := Vector3.ZERO
	var prev_normal := Vector3.UP
	var offset := 0.0
	var first := true
	while offset <= length:
		var xf := curve.sample_baked_with_rotation(offset, true, true)
		var half := xf.basis.x * track_width * 0.5
		var left := xf.origin - half + xf.basis.y * 0.02
		var right := xf.origin + half + xf.basis.y * 0.02
		if not first:
			for v: Array in [[prev_left, prev_normal], [right, xf.basis.y], [prev_right, prev_normal],
					[prev_left, prev_normal], [left, xf.basis.y], [right, xf.basis.y]]:
				st.set_normal(v[1])
				st.add_vertex(v[0])
		prev_left = left
		prev_right = right
		prev_normal = xf.basis.y
		first = false
		offset += step
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = st.commit()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.95, 0.55, 0.2)
	material.roughness = 0.5
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_instance.material_override = material
	add_child(mesh_instance)
	# Side rails so the loop reads as a solid ribbon from any angle.
	for side in [-1.0, 1.0]:
		var rail_path := Path3D.new()
		rail_path.curve = Curve3D.new()
		offset = 0.0
		while offset <= length:
			var xf := curve.sample_baked_with_rotation(offset, true, true)
			rail_path.curve.add_point(xf.origin + xf.basis.x * track_width * 0.5 * side + xf.basis.y * 0.15)
			offset += 1.0
		add_child(rail_path)
		var rail := CSGPolygon3D.new()
		rail.polygon = PackedVector2Array([Vector2(-0.1, -0.1), Vector2(0.1, -0.1), Vector2(0.1, 0.1), Vector2(-0.1, 0.1)])
		rail.mode = CSGPolygon3D.MODE_PATH
		rail.material = PlatformerArt.flat(Color(0.95, 0.95, 0.98), 0.3, 0.5)
		add_child(rail)
		rail.path_node = rail.get_path_to(rail_path)
