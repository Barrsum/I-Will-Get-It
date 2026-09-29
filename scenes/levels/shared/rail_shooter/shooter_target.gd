class_name ShooterTarget
extends StaticBody3D
## Base for pop-up targets in rail-shooter levels. Hidden until activate(), then "up" for
## `lifetime` seconds (optionally swaying side to side), then escapes. Takes `health` hits.
## Subclasses build the look (_build_visual) and can override the appear / hurt / die effects.

enum Phase { HIDDEN, UP, DOWN }
enum HitResult { NONE, DAMAGED, KILLED }

const LAYER_TARGET := 16

var level: RailShooterLevel
var lifetime := 3.5
## Side-to-side travel (metres, each way) while up.
var sway := 0.0
## World point the target faces when up (a spot on the player's path).
var face_point := Vector3.ZERO
## The rail position (Z) at which this target appears.
var trigger_z := 0.0
var health := 1

var phase := Phase.HIDDEN

var visual: Node3D
var _shape: CollisionShape3D
var _time := 0.0
var _home := Vector3.ZERO


func _ready() -> void:
	collision_layer = LAYER_TARGET
	collision_mask = 0
	var to_face := face_point - global_position
	to_face.y = 0.0
	if to_face.length_squared() > 0.01:
		global_basis = Basis.looking_at(to_face.normalized())
	_home = position
	var box := _hit_box()
	_shape = CollisionShape3D.new()
	_shape.shape = BoxShape3D.new()
	(_shape.shape as BoxShape3D).size = box.size
	_shape.position = box.get_center()
	_shape.disabled = true
	add_child(_shape)
	visual = Node3D.new()
	add_child(visual)
	_build_visual(visual)
	visual.visible = false


func activate() -> void:
	if phase != Phase.HIDDEN:
		return
	phase = Phase.UP
	# Negative time = still arriving: not shootable, lifetime hasn't started.
	_time = -_arrival_time()
	visual.visible = true
	_appear()
	get_tree().create_timer(maxf(_arrival_time() * 0.85, 0.05)).timeout.connect(func() -> void:
		if phase == Phase.UP:
			_shape.disabled = false)


func hit() -> HitResult:
	if phase != Phase.UP:
		return HitResult.NONE
	health -= 1
	if health > 0:
		_hurt()
		return HitResult.DAMAGED
	phase = Phase.DOWN
	_shape.set_deferred(&"disabled", true)
	_die()
	return HitResult.KILLED


func center() -> Vector3:
	return _shape.global_position


## Silently removes a target that's still up (level finished).
func retire() -> void:
	if phase == Phase.UP:
		phase = Phase.DOWN
		_shape.set_deferred(&"disabled", true)
		_escape()


func _process(delta: float) -> void:
	if phase != Phase.UP:
		return
	_time += delta
	if _time < 0.0:
		return  # Still arriving.
	if sway > 0.0:
		position = _home + global_basis.x * sin(_time * 2.2) * sway
	_idle(delta, _time)
	if _time > lifetime:
		phase = Phase.DOWN
		_shape.set_deferred(&"disabled", true)
		_escape()
		level.on_target_escaped(self)


# --- Overridables -------------------------------------------------------------------------------

func points() -> int:
	return 100


## Seconds the entrance animation takes; the target can't be hit or escape before then.
func _arrival_time() -> float:
	return 0.15


## Local-space hit box.
func _hit_box() -> AABB:
	return AABB(Vector3(-0.5, 0, -0.3), Vector3(1.0, 1.8, 0.6))


func _build_visual(_root: Node3D) -> void:
	pass


func _appear() -> void:
	visual.scale = Vector3.ONE * 0.01
	create_tween().tween_property(visual, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _idle(_delta: float, _t: float) -> void:
	pass


func _hurt() -> void:
	var tween := create_tween()
	tween.tween_property(visual, "scale", Vector3.ONE * 1.15, 0.05)
	tween.tween_property(visual, "scale", Vector3.ONE, 0.1)


func _die() -> void:
	var tween := create_tween()
	tween.tween_property(visual, "scale", Vector3.ZERO, 0.15)
	tween.tween_callback(func() -> void: visual.visible = false)


func _escape() -> void:
	var tween := create_tween()
	tween.tween_property(visual, "scale", Vector3(1, 0.01, 1), 0.25)
	tween.tween_callback(func() -> void: visual.visible = false)
