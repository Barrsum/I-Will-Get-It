class_name Checkpoint
extends Area3D
## Mid-level flag. Touch it and dying brings you back here instead of the start.

var level: PlatformerLevel
var active := false

var _flag: MeshInstance3D


func _ready() -> void:
	collision_layer = 0
	collision_mask = Hero.LAYER_HERO
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(1.2, 4.0, 3.0)
	shape.position.y = 2.0
	add_child(shape)
	var pole := PlatformerArt.cylinder(0.06, 3.2, PlatformerArt.flat(Color(0.95, 0.95, 0.95), 0.4))
	pole.position.y = 1.6
	add_child(pole)
	var base := PlatformerArt.cylinder(0.3, 0.2, PlatformerArt.flat(Color(0.4, 0.4, 0.46), 0.6))
	base.position.y = 0.1
	add_child(base)
	_flag = PlatformerArt.box(Vector3(1.0, 0.65, 0.05), PlatformerArt.flat(Color(0.55, 0.55, 0.6), 0.6))
	_flag.position = Vector3(0.5, 1.2, 0)
	add_child(_flag)
	body_entered.connect(func(body: Node3D) -> void:
		if body is Hero:
			level.reach_checkpoint(self))


## Raises a bright flag. `instant` for checkpoints restored after respawning.
func activate(instant := false) -> void:
	if active:
		return
	active = true
	_flag.material_override = PlatformerArt.flat(Color(1.0, 0.8, 0.1), 0.45, 0.0, 0.3)
	if instant:
		_flag.position.y = 2.85
	else:
		create_tween().tween_property(_flag, "position:y", 2.85, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
