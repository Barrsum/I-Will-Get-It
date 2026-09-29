class_name Hero
extends CharacterBody3D
## Fortnite-style third-person hero.
## This script owns the shared physics helpers and input buffering; each movement mode
## (Ground, Air, Crouch, Slide, Mantle, Emote) is a HeroState child of the StateMachine.
## Jump model (height + time-to-peak), coyote time and jump buffering adapted from
## Jeh3no's Godot-Third-Person-Controller (MIT).

signal jumped
signal landed(impact_speed: float)
signal respawned

const STATE_GROUND := &"Ground"
const STATE_AIR := &"Air"
const STATE_CROUCH := &"Crouch"
const STATE_SLIDE := &"Slide"
const STATE_MANTLE := &"Mantle"
const STATE_EMOTE := &"Emote"

## States in which holding aim zooms the camera and turns the hero to face the crosshair.
const AIMABLE_STATES: Array[StringName] = [STATE_GROUND, STATE_AIR, STATE_CROUCH]

@export_group("Ground")
@export var jog_speed := 5.5
@export var sprint_speed := 8.0
@export var crouch_speed := 2.8
@export var aim_speed_multiplier := 0.65
@export var ground_acceleration := 60.0
@export var ground_deceleration := 45.0

@export_group("Jump")
@export var jump_height := 1.35
@export var jump_time_to_peak := 0.36
@export var jump_time_to_descent := 0.30
## Extra gravity while rising after jump is released: short tap = short hop.
@export var jump_release_gravity_multiplier := 2.2
@export var coyote_time := 0.12
@export var jump_buffer_time := 0.14
@export var max_fall_speed := 45.0

@export_group("Air")
@export var air_acceleration := 22.0
@export var air_drag := 1.5

@export_group("Slide")
@export var slide_min_entry_speed := 6.0
@export var slide_boost := 2.5
@export var slide_friction := 6.0
@export var slide_slope_acceleration := 22.0
@export var slide_max_speed := 16.0
@export var slide_exit_speed := 3.2
@export var slide_steering := 2.5

@export_group("Mantle")
## Ledge height range, measured from the hero's feet at the moment of the check.
@export var mantle_min_height := 0.45
@export var mantle_max_height := 1.7
@export var mantle_reach := 0.7

@export_group("Body")
@export var standing_height := 1.8
@export var crouch_height := 1.15
@export var capsule_radius := 0.35
@export var turn_speed := 14.0

var jump_velocity: float
var jump_gravity: float
var fall_gravity: float

var is_crouched := false
var is_aiming := false
## Seconds left in which a jump press still counts (pressed slightly before landing).
var jump_buffer := 0.0
## Seconds left in which a jump is still allowed after walking off a ledge.
var coyote := 0.0
## True only on the physics tick the crouch button went down.
var crouch_requested := false

var _sprint_latched := false
var _capsule: CapsuleShape3D
var _spawn_transform: Transform3D

@onready var camera: HeroCamera = $CameraRig
@onready var visual_root: Node3D = $VisualRoot
@onready var skin: HeroSkin = $VisualRoot/Skin
@onready var state_machine: StateMachine = $StateMachine
@onready var collision_shape: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	add_to_group(&"hero")
	_recalculate_jump()
	_capsule = CapsuleShape3D.new()
	_capsule.radius = capsule_radius
	collision_shape.shape = _capsule
	_set_capsule_height(standing_height)

	# The body never rotates; facing lives on VisualRoot and look direction on the camera.
	_spawn_transform = global_transform
	_face_spawn_direction()


func _physics_process(delta: float) -> void:
	# Parent processes before children, so states always see this tick's buffered input.
	jump_buffer = maxf(jump_buffer - delta, 0.0)
	coyote = coyote_time if is_on_floor() else maxf(coyote - delta, 0.0)
	if Input.is_action_just_pressed(&"jump"):
		jump_buffer = jump_buffer_time
	crouch_requested = Input.is_action_just_pressed(&"crouch")
	is_aiming = Input.is_action_pressed(&"aim") and current_state() in AIMABLE_STATES


func _unhandled_input(event: InputEvent) -> void:
	# Controller convention: click the stick once to sprint until you stop.
	if event is InputEventJoypadButton and event.is_action_pressed(&"sprint"):
		_sprint_latched = true


func current_state() -> StringName:
	return state_machine.state.name if state_machine.state else &""


# --- Movement helpers used by states -------------------------------------------------------

## Camera-relative movement input on the XZ plane. Length is 0..1 (analog sticks keep magnitude).
func get_move_input() -> Vector3:
	var raw := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	if raw.is_zero_approx():
		_sprint_latched = false
	return Vector3(raw.x, 0.0, raw.y).rotated(Vector3.UP, camera.yaw)


func wants_sprint() -> bool:
	if is_aiming or is_crouched:
		return false
	return Settings.sprint_by_default or _sprint_latched or Input.is_action_pressed(&"sprint")


func ground_speed() -> float:
	var speed := sprint_speed if wants_sprint() else jog_speed
	return speed * (aim_speed_multiplier if is_aiming else 1.0)


func horizontal_velocity() -> Vector3:
	return Vector3(velocity.x, 0.0, velocity.z)


func horizontal_speed() -> float:
	return horizontal_velocity().length()


func set_horizontal_velocity(value: Vector3) -> void:
	velocity.x = value.x
	velocity.z = value.z


## Moves horizontal velocity toward `target` at `rate` m/s², frame-rate independent.
func accelerate_horizontal(target: Vector3, rate: float, delta: float) -> void:
	set_horizontal_velocity(horizontal_velocity().move_toward(target, rate * delta))


func apply_gravity(delta: float) -> void:
	var gravity := fall_gravity
	if velocity.y > 0.0:
		gravity = jump_gravity
		if not Input.is_action_pressed(&"jump"):
			gravity *= jump_release_gravity_multiplier
	velocity.y = maxf(velocity.y - gravity * delta, -max_fall_speed)


func can_jump() -> bool:
	return is_on_floor() or coyote > 0.0


func jump() -> void:
	velocity.y = jump_velocity
	jump_buffer = 0.0
	coyote = 0.0
	skin.play_jump()
	jumped.emit()


## Turns the visible body toward `direction`, or toward the crosshair while aiming.
func update_facing(delta: float, direction: Vector3) -> void:
	var target_yaw: float
	if is_aiming:
		target_yaw = camera.yaw + PI
	elif direction.length_squared() > 0.01:
		target_yaw = atan2(direction.x, direction.z)
	else:
		return
	visual_root.rotation.y = lerp_angle(visual_root.rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))


func face_direction_instantly(direction: Vector3) -> void:
	visual_root.rotation.y = atan2(direction.x, direction.z)


func facing_direction() -> Vector3:
	return Vector3(sin(visual_root.rotation.y), 0.0, cos(visual_root.rotation.y))


# --- Crouch ---------------------------------------------------------------------------------

## Returns false when standing up is blocked by a ceiling.
func set_crouched(value: bool) -> bool:
	if value == is_crouched:
		return true
	if not value and not can_stand():
		return false
	is_crouched = value
	_set_capsule_height(crouch_height if value else standing_height)
	return true


func can_stand() -> bool:
	return _capsule_fits(global_position, standing_height)


func _set_capsule_height(height: float) -> void:
	_capsule.height = height
	collision_shape.position.y = height * 0.5


func _capsule_fits(feet: Vector3, height: float) -> bool:
	var shape := CapsuleShape3D.new()
	shape.radius = capsule_radius - 0.02
	shape.height = height - 0.04
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, feet + Vector3.UP * (height * 0.5 + 0.03))
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


# --- Mantle ---------------------------------------------------------------------------------

## Looks for a ledge in `direction` that the hero can pull up onto.
## Returns {} when there is none, else {target: Vector3 (feet position on top), wall_normal, height}.
func find_mantle_ledge(direction: Vector3) -> Dictionary:
	direction.y = 0.0
	if direction.length_squared() < 0.01:
		return {}
	direction = direction.normalized()
	var space := get_world_3d().direct_space_state
	var feet := global_position
	var reach := capsule_radius + mantle_reach

	# 1. A wall in front, probed at chest then waist height.
	var wall := {}
	for probe_height: float in [1.1, 0.6]:
		var from := feet + Vector3.UP * probe_height
		wall = space.intersect_ray(_ray(from, from + direction * reach))
		if not wall.is_empty():
			break
	if wall.is_empty() or absf(wall.normal.y) > 0.4:
		return {}
	var wall_normal := Vector3(wall.normal.x, 0.0, wall.normal.z).normalized()

	# 2. A walkable top surface just behind the wall face, within the mantle height range.
	var probe: Vector3 = wall.position - wall_normal * (capsule_radius + 0.1)
	var top := space.intersect_ray(_ray(
		Vector3(probe.x, feet.y + mantle_max_height + 0.3, probe.z),
		Vector3(probe.x, feet.y + mantle_min_height, probe.z)))
	if top.is_empty() or top.normal.y < 0.7:
		return {}
	var ledge_height: float = top.position.y - feet.y
	if ledge_height > mantle_max_height:
		return {}

	# 3. Headroom straight above us, and room to stand on the ledge.
	var head := feet + Vector3.UP * standing_height
	if not space.intersect_ray(_ray(head, head + Vector3.UP * maxf(ledge_height, 0.1))).is_empty():
		return {}
	var target := Vector3(probe.x, top.position.y, probe.z)
	if not _capsule_fits(target, standing_height):
		return {}
	return {"target": target, "wall_normal": wall_normal, "height": ledge_height}


func _ray(from: Vector3, to: Vector3) -> PhysicsRayQueryParameters3D:
	return PhysicsRayQueryParameters3D.create(from, to, collision_mask, [get_rid()])


# --- Lifecycle ------------------------------------------------------------------------------

func respawn() -> void:
	global_transform = _spawn_transform
	velocity = Vector3.ZERO
	is_crouched = false
	_set_capsule_height(standing_height)
	_face_spawn_direction()
	reset_physics_interpolation()
	state_machine.transition_to(STATE_GROUND)
	respawned.emit()


func _face_spawn_direction() -> void:
	var spawn_yaw := global_rotation.y
	global_rotation = Vector3.ZERO
	camera.yaw = spawn_yaw
	camera.snap()
	visual_root.rotation.y = spawn_yaw + PI


func _recalculate_jump() -> void:
	jump_velocity = 2.0 * jump_height / jump_time_to_peak
	jump_gravity = 2.0 * jump_height / (jump_time_to_peak * jump_time_to_peak)
	fall_gravity = 2.0 * jump_height / (jump_time_to_descent * jump_time_to_descent)
