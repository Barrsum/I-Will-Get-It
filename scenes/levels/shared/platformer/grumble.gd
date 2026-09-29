class_name Grumble
extends CharacterBody3D
## Grumpy walking mushroom creature. Walks toward the hero once near, turns at walls,
## walks off ledges. Stomp it from above; touching it from the side hurts.

const SPEED := 2.2
const GRAVITY := 40.0
const ACTIVATION_DISTANCE := 30.0
const SIZE := 1.35  ## Visual + collision scale relative to the 1 m base design.
const HEIGHT := 1.0 * SIZE

var level: PlatformerLevel
var direction := -1.0

var _active := false
var _dead := false
var _time := 0.0
var _visual: Node3D
var _feet: Array[Node3D] = []
var _hurtbox: Area3D


func _ready() -> void:
	add_to_group(&"grumble")
	collision_layer = Hero.LAYER_ENEMY
	collision_mask = Hero.LAYER_WORLD | Hero.LAYER_ENEMY  # Grumbles collide with each other.
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(1.1, 1.0, 1.0) * SIZE
	shape.position.y = HEIGHT * 0.5
	add_child(shape)

	_hurtbox = Area3D.new()
	_hurtbox.collision_layer = 0
	_hurtbox.collision_mask = Hero.LAYER_HERO
	var hurt_shape := CollisionShape3D.new()
	hurt_shape.shape = BoxShape3D.new()
	(hurt_shape.shape as BoxShape3D).size = Vector3(1.2 * SIZE, 1.1 * SIZE, 2.0)
	hurt_shape.position.y = HEIGHT * 0.55
	_hurtbox.add_child(hurt_shape)
	add_child(_hurtbox)
	_build_visual()


func _physics_process(delta: float) -> void:
	if _dead:
		return
	if not _active:
		_active = absf(global_position.x - level.hero.global_position.x) < ACTIVATION_DISTANCE
		return
	if is_on_floor() and not _ground_ahead():
		direction = -direction  # Never walk off a ledge; patrol back instead.
	velocity.x = direction * SPEED
	velocity.y = maxf(velocity.y - GRAVITY * delta, -25.0)
	velocity.z = 0.0
	move_and_slide()
	global_position.z = 0.0
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		if absf(collision.get_normal().x) < 0.7:
			continue  # Floor or ceiling, not a wall.
		var other := collision.get_collider() as Grumble
		if other:
			# Bump into each other and both bounce apart.
			direction = signf(global_position.x - other.global_position.x)
			other.direction = -direction
			other._active = true
		else:
			direction = signf(collision.get_normal().x)
	if global_position.y < -10.0:
		queue_free()
		return

	_time += delta
	for i in _feet.size():
		_feet[i].position.x = (-0.22 if i == 0 else 0.22) + sin(_time * 10.0 + PI * i) * 0.12
		_feet[i].position.y = 0.08 + maxf(0.0, cos(_time * 10.0 + PI * i)) * 0.08
	_visual.rotation.z = sin(_time * 10.0) * 0.06

	for body in _hurtbox.get_overlapping_bodies():
		if body is Hero:
			level.hero_touched_enemy(self)


## Squashed flat by a stomp.
func stomp() -> void:
	_die()
	var tween := create_tween()
	tween.tween_property(_visual, "scale", Vector3(1.3, 0.2, 1.3) * SIZE, 0.08)
	tween.tween_interval(0.45)
	tween.tween_property(_visual, "scale", Vector3.ZERO, 0.12)
	tween.finished.connect(queue_free)


## Flipped and knocked off screen (bumped from below).
func knock_out() -> void:
	_die()
	_visual.rotation.z = PI
	_visual.position.y = 1.0
	var tween := create_tween()
	tween.tween_property(self, "global_position:y", global_position.y + 2.5, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "global_position:y", global_position.y - 14.0, 0.8).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.finished.connect(queue_free)


## Is there floor just past our leading edge?
func _ground_ahead() -> bool:
	var half_width := 0.55 * SIZE
	var from := global_position + Vector3(direction * (half_width + 0.15), 0.3, 0)
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 1.0, Hero.LAYER_WORLD, [get_rid()])
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func is_dead() -> bool:
	return _dead


func _die() -> void:
	_dead = true
	remove_from_group(&"grumble")
	collision_layer = 0
	collision_mask = 0
	_hurtbox.set_deferred(&"monitoring", false)


func _build_visual() -> void:
	_visual = Node3D.new()
	_visual.scale = Vector3.ONE * SIZE
	add_child(_visual)
	var brown := PlatformerArt.flat(Color(0.55, 0.3, 0.16), 0.6)
	var tan := PlatformerArt.flat(Color(0.95, 0.82, 0.62), 0.7)
	var dark := PlatformerArt.flat(Color(0.25, 0.13, 0.07), 0.6)

	var stem := PlatformerArt.cylinder(0.33, 0.45, tan)
	stem.position.y = 0.32
	_visual.add_child(stem)
	var cap := PlatformerArt.sphere(0.58, brown, Vector3(1.0, 0.72, 0.78))
	cap.position.y = 0.66
	_visual.add_child(cap)

	for side in [-1.0, 1.0]:
		var eye := PlatformerArt.eye(0.13)
		eye.position = Vector3(0.15 * side, 0.36, 0.4)
		_visual.add_child(eye)
		var brow := PlatformerArt.box(Vector3(0.24, 0.06, 0.06), dark)
		brow.position = Vector3(0.16 * side, 0.52, 0.47)
		brow.rotation.z = -0.45 * side  # Angry slant.
		_visual.add_child(brow)
		var foot := PlatformerArt.sphere(0.2, dark, Vector3(1.2, 0.6, 1.3))
		foot.position = Vector3(0.22 * side, 0.08, 0.05)
		_visual.add_child(foot)
		_feet.append(foot)
