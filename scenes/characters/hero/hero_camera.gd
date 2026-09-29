class_name HeroCamera
extends Node3D
## Over-the-right-shoulder follow camera (Fortnite style): hero sits left of centre,
## crosshair in the middle. Blends between normal, aim, sprint and emote framings.
## top_level + interpolated follow keeps it smooth at any refresh rate.

@export_group("Framing")
@export var pivot_height := 1.55
@export var crouch_pivot_height := 1.05
@export var arm_length := 3.2
@export var shoulder_offset := 0.55
@export var aim_arm_length := 1.6
@export var aim_shoulder_offset := 0.75
@export var aim_fov_multiplier := 0.72
@export var sprint_fov_bonus := 6.0
@export var emote_arm_length := 4.2
## How fast framing changes blend in (higher = snappier).
@export var blend_speed := 12.0

@export_group("Look")
@export var pitch_min_degrees := -75.0
@export var pitch_max_degrees := 65.0
## Radians per screen pixel at mouse sensitivity 1.0.
@export var mouse_radians_per_pixel := 0.0022
## Radians per second at full stick deflection and controller sensitivity 1.0.
@export var stick_radians_per_second := 3.4

var yaw := 0.0
var pitch := deg_to_rad(-12.0)

var _hero: Hero
var _emote_view := false
var _pre_emote_yaw := 0.0
var _yaw_tween: Tween
var _pivot_y := 0.0
var _snap_next := true

@onready var _pitch_pivot: Node3D = $Pitch
@onready var _arm: SpringArm3D = $Pitch/SpringArm3D
@onready var camera: Camera3D = $Pitch/SpringArm3D/Camera3D


func _ready() -> void:
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_hero = owner as Hero
	_arm.add_excluded_object(_hero.get_rid())
	_pivot_y = pivot_height
	capture_mouse()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := (event as InputEventMouseMotion).screen_relative
		var radians := mouse_radians_per_pixel * Settings.mouse_sensitivity
		_rotate_view(motion.x * radians, motion.y * radians)
	elif event is InputEventMouseButton and event.pressed and not get_tree().paused:
		capture_mouse()


func _process(delta: float) -> void:
	var stick := Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down")
	if not stick.is_zero_approx():
		stick *= stick.length()  # Quadratic response: precise near centre, fast at the edge.
		var radians := stick_radians_per_second * Settings.controller_sensitivity * delta
		_rotate_view(stick.x * radians, stick.y * radians)

	var blend := 1.0 if _snap_next else 1.0 - exp(-blend_speed * delta)
	_snap_next = false

	var wanted_pivot := crouch_pivot_height if _hero.is_crouched else pivot_height
	_pivot_y = lerpf(_pivot_y, wanted_pivot, blend)
	global_position = _hero.get_global_transform_interpolated().origin + Vector3.UP * _pivot_y
	global_rotation = Vector3(0.0, yaw, 0.0)
	_pitch_pivot.rotation.x = pitch

	var length := arm_length
	var offset := shoulder_offset
	var fov := Settings.fov
	if _emote_view:
		length = emote_arm_length
		offset = 0.0
	elif _hero.is_aiming:
		length = aim_arm_length
		offset = aim_shoulder_offset
		fov *= aim_fov_multiplier
	elif _hero.current_state() == Hero.STATE_GROUND and _hero.wants_sprint() and _hero.horizontal_speed() > _hero.jog_speed:
		fov += sprint_fov_bonus
	_arm.spring_length = lerpf(_arm.spring_length, length, blend)
	_arm.position.x = lerpf(_arm.position.x, offset, blend)
	camera.fov = lerpf(camera.fov, fov, blend)


func capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Skip blending on the next frame (spawn, respawn, cutscene cuts).
func snap() -> void:
	_snap_next = true


## Emotes swing the camera round to face the hero, then swing back afterwards.
func set_emote_view(enabled: bool) -> void:
	_emote_view = enabled
	if _yaw_tween:
		_yaw_tween.kill()
	var target := _hero.visual_root.global_rotation.y if enabled else _pre_emote_yaw
	if enabled:
		_pre_emote_yaw = yaw
	var from := yaw
	var to := from + angle_difference(from, target)
	_yaw_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_yaw_tween.tween_method(func(value: float) -> void: yaw = wrapf(value, -PI, PI), from, to, 0.6 if enabled else 0.35)


## Direction the crosshair points, for aiming and interaction.
func aim_direction() -> Vector3:
	return -camera.global_basis.z


func _rotate_view(yaw_delta: float, pitch_delta: float) -> void:
	yaw = wrapf(yaw - yaw_delta, -PI, PI)
	var invert := -1.0 if Settings.invert_look_y else 1.0
	pitch = clampf(pitch - pitch_delta * invert, deg_to_rad(pitch_min_degrees), deg_to_rad(pitch_max_degrees))
