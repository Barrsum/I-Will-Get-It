@tool
extends Node3D
## Generates the movement test gym from data, in the editor and in game.
## Every feature is sized to probe one mechanic: mantle heights, crouch clearance,
## slide slopes, stairs, walkable vs. too-steep ramps, and camera collision.

const GRID_SHADER: Shader = preload("res://assets/shaders/prototype_grid.gdshader")

const FLOOR := Color(0.55, 0.6, 0.68)
const ORANGE := Color(1.0, 0.55, 0.2)
const PURPLE := Color(0.55, 0.4, 0.95)
const GREEN := Color(0.35, 0.8, 0.45)
const CYAN := Color(0.25, 0.75, 0.95)
const PINK := Color(0.95, 0.4, 0.6)
const WHITE := Color(0.9, 0.9, 0.92)

var _material: ShaderMaterial


func _ready() -> void:
	for child in get_children():
		child.free()
	_material = ShaderMaterial.new()
	_material.shader = GRID_SHADER
	_build()


func _build() -> void:
	# Ground: top surface at y = 0.
	_box(Vector3(0, -0.5, 0), Vector3(240, 1, 240), FLOOR)

	# Mantle wall row: heights from "just hop it" to "too tall".
	var heights := [0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.6]
	for i in heights.size():
		var h: float = heights[i]
		var x := -10.5 + i * 3.5
		_box(Vector3(x, h * 0.5, -14), Vector3(2.5, h, 3), ORANGE)
		_sign(Vector3(x, h + 0.6, -12.4), "%.1f m" % h)
	_sign(Vector3(0, 4.8, -14), "MANTLE WALLS", 1.6)

	# Crouch tunnel: 1.3 m clearance (standing 1.8 m won't fit, crouching 1.15 m will).
	_box(Vector3(12.0, 0.65, 0), Vector3(0.6, 1.3, 10), PURPLE)
	_box(Vector3(15.0, 0.65, 0), Vector3(0.6, 1.3, 10), PURPLE)
	_box(Vector3(13.5, 1.6, 0), Vector3(3.6, 0.6, 10), PURPLE)
	_sign(Vector3(13.5, 2.9, 5.5), "CROUCH TUNNEL")

	# Slide hill: 18 degree slope, with a flat top reached by stairs.
	_ramp(Vector3(-20, 0, 10), 8.0, 30.0, 18.0, GREEN)
	_sign(Vector3(-20, 1.5, 12), "SLIDE HILL  (sprint + crouch)")

	# Stairs to a lookout platform (collision is a hidden ramp, the steps are visual).
	_stairs(Vector3(20, 0, 14), 12, 0.25, 0.45, 3.0, CYAN)
	_box(Vector3(20, 1.5, 6.1), Vector3(6, 3, 5), CYAN)  # Front face flush with the top step (z = 8.6).
	_sign(Vector3(20, 4.2, 6.1), "STAIRS")

	# Ramps: 30 degrees is walkable, 50 degrees is too steep (you slide off).
	_ramp(Vector3(-4, 0, 34), 4.0, 8.0, 30.0, PINK)
	_ramp(Vector3(2, 0, 34), 4.0, 5.0, 50.0, PINK)
	_sign(Vector3(-4, 1.2, 35.5), "30°  walkable")
	_sign(Vector3(2, 1.2, 35.5), "50°  too steep")

	# Jump course: stepping stones with rising gaps.
	var stones := [Vector3(-10, 0.6, -26), Vector3(-6.5, 1.2, -28), Vector3(-3, 1.8, -30.5),
		Vector3(0.8, 2.4, -32), Vector3(4.8, 3.0, -31), Vector3(8.2, 3.6, -28.5)]
	for p: Vector3 in stones:
		_box(Vector3(p.x, p.y * 0.5, p.z), Vector3(2.2, p.y, 2.2), CYAN)
	_sign(Vector3(-10, 3.2, -26), "JUMP COURSE")

	# Clutter for camera collision checks.
	for p: Vector3 in [Vector3(-12, 1, 2), Vector3(-9, 1.5, -4), Vector3(8, 1, -4), Vector3(6, 2, 4)]:
		_box(p, Vector3(2, p.y * 2, 2), WHITE)
	_box(Vector3(-2, 4, -40), Vector3(24, 8, 1), WHITE)


func _box(center: Vector3, size: Vector3, color: Color, rotation_deg := Vector3.ZERO,
		visible_mesh := true, solid := true) -> Node3D:
	var body: Node3D = StaticBody3D.new() if solid else Node3D.new()
	body.position = center
	body.rotation_degrees = rotation_deg
	if solid:
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		shape.shape = box_shape
		body.add_child(shape)
	if visible_mesh:
		var mesh := MeshInstance3D.new()
		var box_mesh := BoxMesh.new()
		box_mesh.size = size
		mesh.mesh = box_mesh
		mesh.material_override = _material
		mesh.set_instance_shader_parameter(&"tint", color)
		body.add_child(mesh)
	add_child(body)
	return body


## Solid wedge-like ramp rising toward -Z from `base` (front-bottom edge centre).
func _ramp(base: Vector3, width: float, length: float, angle_deg: float, color: Color) -> void:
	var angle := deg_to_rad(angle_deg)
	var thickness := 1.0
	var rise := length * sin(angle)
	var run := length * cos(angle)
	# Slab centre: halfway along the slope, pushed down by half its thickness along the normal.
	var along := Vector3(0, sin(angle), -cos(angle))
	var normal := Vector3(0, cos(angle), sin(angle))
	var centre := base + along * length * 0.5 - normal * thickness * 0.5
	_box(centre, Vector3(width, thickness, length), color, Vector3(angle_deg, 0, 0))
	# Fill block under the top so the ramp reads as solid and has a flat landing.
	_box(base + Vector3(0, rise * 0.5, -run - 2.0), Vector3(width, rise, 4.0), color)


func _stairs(base: Vector3, steps: int, rise: float, run: float, width: float, color: Color) -> void:
	for i in steps:
		var h := (i + 1) * rise
		_box(base + Vector3(0, h * 0.5, -i * run - run * 0.5), Vector3(width, h, run), color, Vector3.ZERO, true, false)
	# Smooth collision so the capsule glides up instead of catching on each step.
	var length := Vector2(steps * run, steps * rise).length()
	var angle := rad_to_deg(atan2(steps * rise, steps * run))
	var along := Vector3(0, steps * rise, -steps * run).normalized()
	_box(base + along * length * 0.5 + Vector3(0, 0.02, 0), Vector3(width, 0.02, length), color, Vector3(angle, 0, 0), false)


func _sign(where: Vector3, text: String, scale := 1.0) -> void:
	var label := Label3D.new()
	label.text = text
	label.font = UIStyle.heading_font()
	label.font_size = int(96 * scale)
	label.pixel_size = 0.005
	label.outline_size = 18
	label.modulate = UIStyle.TEXT
	label.outline_modulate = Color(UIStyle.NAVY, 0.85)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = where
	add_child(label)
