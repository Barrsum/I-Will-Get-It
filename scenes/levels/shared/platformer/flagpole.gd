class_name Flagpole
extends Area3D
## End-of-level goal. Grab the pole anywhere along its height to finish.

const HEIGHT := 13.5

var level: PlatformerLevel

var _flag: MeshInstance3D


func _ready() -> void:
	collision_layer = 0
	collision_mask = Hero.LAYER_HERO
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(0.8, HEIGHT, 3.0)
	shape.position.y = HEIGHT * 0.5
	add_child(shape)
	var pole := PlatformerArt.cylinder(0.12, HEIGHT, PlatformerArt.flat(Color(0.35, 0.8, 0.4), 0.3))
	pole.position.y = HEIGHT * 0.5
	add_child(pole)
	var ball := PlatformerArt.sphere(0.3, PlatformerArt.flat(Color(1.0, 0.8, 0.15), 0.3, 0.5, 0.3))
	ball.position.y = HEIGHT + 0.2
	add_child(ball)
	_flag = PlatformerArt.box(Vector3(1.8, 1.2, 0.05), PlatformerArt.flat(Color(0.95, 0.25, 0.3), 0.5))
	_flag.position = Vector3(-0.95, HEIGHT - 1.0, 0)
	add_child(_flag)
	body_entered.connect(func(body: Node3D) -> void:
		if body is Hero:
			level.reach_goal(self))


func lower_flag(duration: float) -> void:
	create_tween().tween_property(_flag, "position:y", 1.0, duration).set_trans(Tween.TRANS_QUAD)
