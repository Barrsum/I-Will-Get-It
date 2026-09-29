class_name PowerMushroom
extends CharacterBody3D
## Super-size power-up. Rises out of its block, then slides along the ground (turning at walls)
## until the hero grabs it.

const SPEED := 3.2
const GRAVITY := 40.0
const EMERGE_TIME := 0.8

var level: PlatformerLevel
var direction := 1.0

var _emerging := true
var _emerge_t := 0.0
var _start_y := 0.0
var _shape: CollisionShape3D
var _pickup: Area3D


func _ready() -> void:
	collision_layer = Hero.LAYER_PICKUP
	collision_mask = Hero.LAYER_WORLD
	_shape = CollisionShape3D.new()
	_shape.shape = BoxShape3D.new()
	(_shape.shape as BoxShape3D).size = Vector3(0.9, 0.9, 0.9)
	_shape.position.y = 0.45
	_shape.disabled = true
	add_child(_shape)

	_pickup = Area3D.new()
	_pickup.collision_layer = 0
	_pickup.collision_mask = Hero.LAYER_HERO
	var pickup_shape := CollisionShape3D.new()
	pickup_shape.shape = BoxShape3D.new()
	(pickup_shape.shape as BoxShape3D).size = Vector3(1.1, 1.1, 2.0)
	pickup_shape.position.y = 0.5
	_pickup.add_child(pickup_shape)
	add_child(_pickup)
	_build_visual()
	_start_y = global_position.y


func _physics_process(delta: float) -> void:
	if _emerging:
		_emerge_t = minf(_emerge_t + delta / EMERGE_TIME, 1.0)
		global_position.y = _start_y + PlatformerArt.CELL * _emerge_t
		if _emerge_t >= 1.0:
			_emerging = false
			_shape.disabled = false
	else:
		velocity.x = direction * SPEED
		velocity.y = maxf(velocity.y - GRAVITY * delta, -25.0)
		velocity.z = 0.0
		move_and_slide()
		global_position.z = 0.0
		if is_on_wall():
			direction = -direction
		if global_position.y < -10.0:
			queue_free()
			return
	if _emerging:
		return  # Can't be grabbed until fully out of the block (classic rule).
	for body in _pickup.get_overlapping_bodies():
		if body is Hero:
			level.collect_mushroom(self)
			return


func _build_visual() -> void:
	var visual := Node3D.new()
	add_child(visual)
	var stem := PlatformerArt.cylinder(0.28, 0.45, PlatformerArt.flat(Color(1.0, 0.93, 0.8), 0.7))
	stem.position.y = 0.23
	visual.add_child(stem)
	var cap := PlatformerArt.sphere(0.5, PlatformerArt.flat(Color(0.92, 0.16, 0.14), 0.45), Vector3(1.0, 0.75, 0.95))
	cap.position.y = 0.55
	visual.add_child(cap)
	var white := PlatformerArt.flat(Color(1, 1, 1), 0.5)
	for spot: Vector3 in [Vector3(0, 0.78, 0.25), Vector3(-0.3, 0.6, 0.33), Vector3(0.3, 0.6, 0.33)]:
		var dot := PlatformerArt.sphere(0.13, white, Vector3(1, 1, 0.5))
		dot.position = spot
		visual.add_child(dot)
	for side in [-1.0, 1.0]:
		var eye := PlatformerArt.sphere(0.05, PlatformerArt.flat(Color(0.05, 0.05, 0.08)), Vector3(0.8, 1.6, 0.5))
		eye.position = Vector3(0.1 * side, 0.26, 0.27)
		visual.add_child(eye)
