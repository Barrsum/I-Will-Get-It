class_name PlatformerArt
extends RefCounted
## Shared palette, materials and simple procedural meshes for platformer levels.
## Blockout-quality "toy" art: everything here is meant to be swapped for Blender assets later
## without touching gameplay code (gameplay nodes only ask this class for visuals).

const CELL := 1.5  ## World size of one map cell, in metres.

const TILE_SHADER: Shader = preload("res://assets/shaders/platformer_tile.gdshader")

static var _cache: Dictionary = {}


static func tile_material(kind: StringName) -> ShaderMaterial:
	var key := StringName("tile_" + kind)
	if _cache.has(key):
		return _cache[key]
	var m := ShaderMaterial.new()
	m.shader = TILE_SHADER
	m.set_shader_parameter(&"cell_size", CELL)
	match kind:
		&"dirt":
			_tile(m, Color(0.72, 0.46, 0.26), Color(0.55, 0.33, 0.18), 0.03)
		&"grass":
			_tile(m, Color(0.36, 0.78, 0.28), Color(0.27, 0.62, 0.2), 0.02)
		&"brick":
			_tile(m, Color(0.78, 0.38, 0.2), Color(0.42, 0.18, 0.1), 0.05)
			m.set_shader_parameter(&"brick_pattern", true)
		&"question":
			_tile(m, Color(1.0, 0.76, 0.15), Color(0.72, 0.42, 0.05), 0.09)
			m.set_shader_parameter(&"roughness_value", 0.45)
		&"used":
			_tile(m, Color(0.55, 0.38, 0.25), Color(0.36, 0.23, 0.14), 0.09)
		&"hard":
			_tile(m, Color(0.66, 0.66, 0.72), Color(0.42, 0.42, 0.5), 0.1)
	_cache[key] = m
	return m


static func _tile(m: ShaderMaterial, base: Color, edge: Color, width: float) -> void:
	m.set_shader_parameter(&"base_color", base)
	m.set_shader_parameter(&"edge_color", edge)
	m.set_shader_parameter(&"edge_width", width)


static func flat(color: Color, roughness := 0.7, metallic := 0.0, emission := 0.0) -> StandardMaterial3D:
	var key := StringName("flat_%s_%.2f_%.2f_%.2f" % [color.to_html(), roughness, metallic, emission])
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	_cache[key] = m
	return m


static func box(size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	return node


static func sphere(radius: float, material: Material, squash := Vector3.ONE) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.scale = squash
	return node


static func cylinder(radius: float, height: float, material: Material, segments := 24) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	return node


## Cartoon eye (white + pupil) facing the camera (+Z).
static func eye(radius: float) -> Node3D:
	var root := Node3D.new()
	var white := sphere(radius, flat(Color(0.98, 0.98, 0.95), 0.4), Vector3(0.8, 1.2, 0.5))
	root.add_child(white)
	var pupil := sphere(radius * 0.5, flat(Color(0.05, 0.05, 0.08), 0.3), Vector3(0.8, 1.2, 0.5))
	pupil.position = Vector3(0, -radius * 0.15, radius * 0.3)
	root.add_child(pupil)
	return root
