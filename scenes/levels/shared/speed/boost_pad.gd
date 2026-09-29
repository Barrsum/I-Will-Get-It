class_name BoostPad
extends Area3D
## Dash panel: running over it fires the hero forward (along this node's -Z) at high speed.

@export var speed := 28.0
@export var duration := 1.3

var _arrows: Array[MeshInstance3D] = []
var _time := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = Hero.LAYER_HERO
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(3.2, 1.2, 3.0)
	shape.position.y = 0.6
	add_child(shape)
	var base := PlatformerArt.box(Vector3(3.2, 0.12, 3.0), PlatformerArt.flat(Color(0.2, 0.22, 0.28), 0.4, 0.5))
	base.position.y = 0.06
	add_child(base)
	# Three chevrons pointing forward.
	var glow := PlatformerArt.flat(Color(1.0, 0.75, 0.15), 0.3, 0.0, 2.0)
	for i in 3:
		for side in [-1.0, 1.0]:
			var bar := PlatformerArt.box(Vector3(1.1, 0.05, 0.28), glow)
			bar.position = Vector3(0.42 * side, 0.14, 0.8 - i * 0.8)
			bar.rotation.y = 0.6 * side
			add_child(bar)
			_arrows.append(bar)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_time += delta
	for i in _arrows.size():
		# Chevrons pulse front-to-back to read as "go".
		var row := i / 2
		_arrows[i].scale = Vector3.ONE * (0.85 + 0.25 * maxf(0.0, sin(_time * 8.0 - row * 1.2)))


func _on_body_entered(body: Node3D) -> void:
	var hero := body as Hero
	if hero and hero.current_state() != Hero.STATE_RAIL:
		hero.apply_boost(-global_basis.z, speed, duration)
