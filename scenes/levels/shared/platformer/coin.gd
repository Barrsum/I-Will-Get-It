class_name Coin
extends Area3D
## Spinning collectible coin. `popup` coins (from "?" blocks) are collected instantly and just
## play a hop animation.

var level: PlatformerLevel
var popup := false

var _visual: Node3D
var _collected := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = Hero.LAYER_HERO
	_visual = Node3D.new()
	add_child(_visual)
	var disc := PlatformerArt.cylinder(0.42, 0.12, PlatformerArt.flat(Color(1.0, 0.78, 0.15), 0.25, 0.7, 0.25))
	disc.rotation.x = PI * 0.5  # Face the camera (+Z).
	_visual.add_child(disc)
	var inner := PlatformerArt.cylinder(0.26, 0.14, PlatformerArt.flat(Color(1.0, 0.9, 0.45), 0.3, 0.6, 0.35))
	inner.rotation.x = PI * 0.5
	_visual.add_child(inner)
	if popup:
		monitoring = false
		_play_collect(2.2, 0.45)
		return
	var shape := CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	(shape.shape as SphereShape3D).radius = 0.55
	add_child(shape)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_visual.rotation.y += (14.0 if popup or _collected else 3.0) * delta


func _on_body_entered(body: Node3D) -> void:
	if _collected or not body is Hero:
		return
	_collected = true
	set_deferred(&"monitoring", false)
	level.add_coin()
	_play_collect(1.0, 0.25)


func _play_collect(rise: float, duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(_visual, "position:y", rise, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_visual, "scale", Vector3.ZERO, 0.12)
	tween.finished.connect(queue_free)
