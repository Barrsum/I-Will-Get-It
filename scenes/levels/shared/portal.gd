class_name Portal
extends Node3D
## Glowing swirl portal (story transitions between worlds). Faces +Z by default; rotate the node
## to aim it. open()/close() animate it; await them to sequence cutscenes.

const PORTAL_SHADER: Shader = preload("res://assets/shaders/portal.gdshader")

@export var radius := 2.4

var _ring: MeshInstance3D
var _surface_material: ShaderMaterial
var _light: OmniLight3D


func _ready() -> void:
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = radius
	ring_mesh.outer_radius = radius + 0.28
	ring_mesh.rings = 64
	_ring = MeshInstance3D.new()
	_ring.mesh = ring_mesh
	_ring.rotation.x = PI * 0.5  # Torus axis onto Z.
	_ring.material_override = PlatformerArt.flat(Color(0.5, 0.9, 1.0), 0.2, 0.0, 4.0)
	add_child(_ring)

	var disc := QuadMesh.new()
	disc.size = Vector2.ONE * radius * 2.0
	_surface_material = ShaderMaterial.new()
	_surface_material.shader = PORTAL_SHADER
	var surface := MeshInstance3D.new()
	surface.mesh = disc
	surface.material_override = _surface_material
	add_child(surface)

	_light = OmniLight3D.new()
	_light.light_color = Color(0.5, 0.8, 1.0)
	_light.omni_range = radius * 5.0
	_light.position.z = 0.8
	add_child(_light)
	scale = Vector3.ONE * 0.01
	_set_open(0.0)


func open(duration := 0.8) -> void:
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "scale", Vector3.ONE, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_open, 0.0, 1.0, duration)
	await tween.finished


func close(duration := 0.5) -> void:
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "scale", Vector3.ONE * 0.01, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_method(_set_open, 1.0, 0.0, duration)
	await tween.finished


func _process(delta: float) -> void:
	_ring.rotate_object_local(Vector3.UP, delta * 1.5)


func _set_open(amount: float) -> void:
	_surface_material.set_shader_parameter(&"opening", amount)
	_light.light_energy = 4.0 * amount
