class_name HeroCamera
extends Node3D
## Over-the-right-shoulder follow camera (Fortnite style): hero sits left of centre,
## crosshair in the middle. Blends between normal, aim, sprint and emote framings.
## Also has a side-scroll mode for 2.5D levels (fixed side view, look-ahead, soft vertical follow).
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

@export_group("Side scroll")
@export var side_distance := 14.0
## Camera pivot height above the hero's feet.
@export var side_height := 2.6
@export var side_pitch_degrees := -5.0
@export var side_fov := 45.0
@export var side_look_ahead := 2.5
## The camera never scrolls left of this X (level start).
@export var side_limit_left := -INF

var yaw := 0.0
var pitch := deg_to_rad(-12.0)
var side_scroll := false
## Optional look limit (on-rails levels): yaw stays within yaw_center ± yaw_limit radians.
var yaw_center := 0.0
var yaw_limit := INF

var _hero: Hero
var _emote_view := false
var _pre_emote_yaw := 0.0
var _yaw_tween: Tween
var _pivot_y := 0.0
var _snap_next := true
var _look_ahead := 0.0
var _follow_y := 0.0
## Fixed viewpoint (e.g. beside a loop) that watches the hero; null = normal follow camera.
var _view_point: Variant = null

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
	if side_scroll:
		_process_side_scroll(delta)
		return
	if _view_point != null:
		_process_view_point(delta)
		return
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
	else:
		# Widen with speed: a nudge when sprinting, a big stretch at boost speeds.
		var over := _hero.horizontal_speed() - _hero.jog_speed
		if over > 0.5:
			fov += minf(sprint_fov_bonus + (over - 0.5) * 0.9, 22.0)
	_arm.spring_length = lerpf(_arm.spring_length, length, blend)
	_arm.position.x = lerpf(_arm.position.x, offset, blend)
	camera.fov = lerpf(camera.fov, fov, blend)


## Watch the hero from a fixed world point (loops, set pieces). Pass null to return to the
## normal follow camera; `return_yaw` is where the follow camera should then face.
func set_view_point(point: Variant, return_yaw := NAN) -> void:
	_view_point = point
	if point == null:
		if not is_nan(return_yaw):
			yaw = return_yaw
		pitch = deg_to_rad(-12.0)
		_arm.spring_length = arm_length


func _process_view_point(delta: float) -> void:
	var blend := 1.0 - exp(-6.0 * delta)
	var target := _hero.get_global_transform_interpolated().origin + Vector3.UP * 1.0
	global_position = global_position.lerp(_view_point, blend)
	var dir := (target - global_position).normalized()
	global_rotation = Vector3(0.0, atan2(-dir.x, -dir.z), 0.0)
	_pitch_pivot.rotation.x = asin(clampf(dir.y, -1.0, 1.0))
	_arm.spring_length = lerpf(_arm.spring_length, 0.0, blend)
	_arm.position.x = lerpf(_arm.position.x, 0.0, blend)
	camera.fov = lerpf(camera.fov, Settings.fov, blend)


func set_side_scroll(enabled: bool) -> void:
	side_scroll = enabled
	_arm.collision_mask = 0 if enabled else 1
	yaw = 0.0
	pitch = deg_to_rad(side_pitch_degrees) if enabled else deg_to_rad(-12.0)
	snap()


func _process_side_scroll(delta: float) -> void:
	var target := _hero.get_global_transform_interpolated().origin
	var snapping := _snap_next
	_snap_next = false

	# Look ahead in the direction of travel; hold the last offset while standing still.
	if absf(_hero.velocity.x) > 0.5:
		var wanted := signf(_hero.velocity.x) * side_look_ahead
		_look_ahead = wanted if snapping else lerpf(_look_ahead, wanted, 1.0 - exp(-1.8 * delta))
	# Vertical: lazy while jumping so the view doesn't bob, faster on the ground, fast when falling away.
	var wanted_y := target.y + side_height
	var rate := 3.0 if _hero.is_on_floor() else 1.0
	if wanted_y < _follow_y - 3.0 or wanted_y > _follow_y + 3.5:
		rate = 8.0
	_follow_y = wanted_y if snapping else lerpf(_follow_y, wanted_y, 1.0 - exp(-rate * delta))

	global_position = Vector3(maxf(target.x + _look_ahead, side_limit_left), _follow_y, target.z)
	global_rotation = Vector3.ZERO
	_pitch_pivot.rotation.x = deg_to_rad(side_pitch_degrees)
	_arm.spring_length = side_distance
	_arm.position.x = 0.0
	camera.fov = side_fov


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


## Weapon kick: nudges the view upward.
func add_recoil(radians: float) -> void:
	pitch = clampf(pitch + radians, deg_to_rad(pitch_min_degrees), deg_to_rad(pitch_max_degrees))


## Direction the crosshair points, for aiming and interaction.
func aim_direction() -> Vector3:
	return -camera.global_basis.z


func _rotate_view(yaw_delta: float, pitch_delta: float) -> void:
	if side_scroll:
		return
	yaw = wrapf(yaw - yaw_delta, -PI, PI)
	if yaw_limit < PI:
		yaw = yaw_center + clampf(angle_difference(yaw_center, yaw), -yaw_limit, yaw_limit)
	var invert := -1.0 if Settings.invert_look_y else 1.0
	pitch = clampf(pitch - pitch_delta * invert, deg_to_rad(pitch_min_degrees), deg_to_rad(pitch_max_degrees))
