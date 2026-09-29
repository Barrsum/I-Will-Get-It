class_name SpringPad
extends Area3D
## Bouncer: launches the hero up (and forward along this node's -Z).

@export var up_speed := 26.0
@export var forward_speed := 12.0

var _top: MeshInstance3D


func _ready() -> void:
	collision_layer = 0
	collision_mask = Hero.LAYER_HERO
	var shape := CollisionShape3D.new()
	shape.shape = CylinderShape3D.new()
	(shape.shape as CylinderShape3D).radius = 1.3
	(shape.shape as CylinderShape3D).height = 1.2
	shape.position.y = 0.6
	add_child(shape)
	var base := PlatformerArt.cylinder(1.3, 0.3, PlatformerArt.flat(Color(0.85, 0.2, 0.2), 0.4), 24)
	base.position.y = 0.15
	add_child(base)
	var coil := PlatformerArt.cylinder(0.7, 0.35, PlatformerArt.flat(Color(0.75, 0.75, 0.8), 0.3, 0.7), 16)
	coil.position.y = 0.45
	add_child(coil)
	_top = PlatformerArt.cylinder(1.15, 0.15, PlatformerArt.flat(Color(1.0, 0.8, 0.15), 0.3, 0.0, 0.6), 24)
	_top.position.y = 0.7
	add_child(_top)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	var hero := body as Hero
	if hero == null or hero.velocity.y > up_speed * 0.5:
		return
	hero.launch(Vector3.UP * up_speed + (-global_basis.z) * forward_speed)
	var tween := create_tween()
	tween.tween_property(_top, "position:y", 1.1, 0.06)
	tween.tween_property(_top, "position:y", 0.7, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
