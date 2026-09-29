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

## Physics layer bits (named in project.godot).
const LAYER_WORLD := 1
const LAYER_HERO := 2
const LAYER_ENEMY := 4
const LAYER_PICKUP := 8

const STATE_GROUND := &"Ground"
const STATE_AIR := &"Air"
const STATE_CROUCH := &"Crouch"
const STATE_SLIDE := &"Slide"
const STATE_MANTLE := &"Mantle"
const STATE_EMOTE := &"Emote"

## States in which holding aim zooms the camera and turns the hero to face the crosshair.
const AIMABLE_STATES: Array[StringName] = [STATE_GROUND, STATE_AIR, STATE_CROUCH]

@export_group("Level rules")
## 2.5D mode: movement locked to the XY plane at the spawn Z, fixed side camera.
@export var side_scroll := false
@export var can_mantle := true
@export var can_aim := true
## Always aiming (on-rails shooter): camera stays zoomed and the hero faces the crosshair.
@export var force_aim := false

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
## Uniform body size (1 = normal). Scales collision and visuals; used by power-ups.
var size_scale := 1.0
## When false, all player input reads as neutral (cutscenes, death, level end).
var controls_enabled := true
## Seconds left in which a jump press still counts (pressed slightly before landing).
var jump_buffer := 0.0
## Seconds left in which a jump is still allowed after walking off a ledge.
var coyote := 0.0
## True only on the physics tick the crouch button went down.
var crouch_requested := false

var _sprint_latched := false
var _capsule: CapsuleShape3D
var _spawn_transform: Transform3D
var _plane_z := 0.0

@onready var camera: HeroCamera = $CameraRig
@onready var visual_root: Node3D = $VisualRoot
@onready var skin: HeroSkin = $VisualRoot/Skin
@onready var state_machine: StateMachine = $StateMachine
@onready var collision_shape: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	add_to_group(&"hero")
	recalculate_jump()
	_capsule = CapsuleShape3D.new()
	_capsule.radius = capsule_radius
	collision_shape.shape = _capsule
	_set_capsule_height(standing_height)

	# The body never rotates; facing lives on VisualRoot and look direction on the camera.
	_spawn_transform = global_transform
	_plane_z = global_position.z
	_face_spawn_direction()
	if side_scroll:
		camera.set_side_scroll(true)
		visual_root.rotation.y = PI * 0.5  # Face right, into the level.


func _physics_process(delta: float) -> void:
	# Parent processes before children, so states always see this tick's buffered input.
	jump_buffer = maxf(jump_buffer - delta, 0.0)
	coyote = coyote_time if is_on_floor() else maxf(coyote - delta, 0.0)
	if controls_enabled and (Input.is_action_just_pressed(&"jump") \
			or (side_scroll and Input.is_action_just_pressed(&"side_jump"))):
		jump_buffer = jump_buffer_time
	crouch_requested = controls_enabled and (Input.is_action_just_pressed(&"crouch") \
		or (side_scroll and Input.is_action_just_pressed(&"side_crouch")))
	is_aiming = force_aim or (can_aim and not side_scroll and controls_enabled \
		and Input.is_action_pressed(&"aim") and current_state() in AIMABLE_STATES)


func _unhandled_input(event: InputEvent) -> void:
	# Controller convention: click the stick once to sprint until you stop.
	if event is InputEventJoypadButton and event.is_action_pressed(&"sprint"):
		_sprint_latched = true


func current_state() -> StringName:
	return state_machine.state.name if state_machine.state else &""


# --- Movement helpers used by states -------------------------------------------------------

## Camera-relative movement input on the XZ plane. Length is 0..1 (analog sticks keep magnitude).
func get_move_input() -> Vector3:
	if not controls_enabled:
		return Vector3.ZERO
	var raw := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	if side_scroll:
		raw.y = 0.0
	if raw.is_zero_approx():
		_sprint_latched = false
	if side_scroll:
		return Vector3(raw.x, 0.0, 0.0)
	return Vector3(raw.x, 0.0, raw.y).rotated(Vector3.UP, camera.yaw)


## Is the jump button held? In side-scroll levels W / Up also count. (False while controls are disabled.)
func is_jump_held() -> bool:
	return controls_enabled and (Input.is_action_pressed(&"jump") \
		or (side_scroll and Input.is_action_pressed(&"side_jump")))


## Is the crouch button held? In side-scroll levels S / Down also count. (False while controls are disabled.)
func is_crouch_held() -> bool:
	return controls_enabled and (Input.is_action_pressed(&"crouch") \
		or (side_scroll and Input.is_action_pressed(&"side_crouch")))


## move_and_slide() plus contact callbacks: anything we bump into that has
## `on_hero_contact(hero, normal, impact_velocity)` is told about it (blocks hit from below, etc.).
## States must call this instead of move_and_slide().
func move() -> void:
	var impact_velocity := velocity
	move_and_slide()
	if side_scroll:
		global_position.z = _plane_z
		velocity.z = 0.0
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()
		if collider and collider.has_method(&"on_hero_contact"):
			collider.on_hero_contact(self, collision.get_normal(), impact_velocity)


func wants_sprint() -> bool:
	if is_aiming or is_crouched or not controls_enabled:
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
		if not is_jump_held():
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


## Grows or shrinks the hero (collision + visuals). Returns false if there's no room to grow.
func set_size_scale(value: float) -> bool:
	var previous := size_scale
	size_scale = value
	if value > previous and not _capsule_fits(global_position, crouch_height if is_crouched else standing_height):
		size_scale = previous
		return false
	_set_capsule_height(crouch_height if is_crouched else standing_height)
	visual_root.scale = Vector3.ONE * size_scale
	return true


func _set_capsule_height(height: float) -> void:
	_capsule.radius = capsule_radius * size_scale
	_capsule.height = height * size_scale
	collision_shape.position.y = height * size_scale * 0.5


## Would a capsule of unscaled `height` (scaled by size_scale) fit standing at `feet`?
func _capsule_fits(feet: Vector3, height: float) -> bool:
	height *= size_scale
	var shape := CapsuleShape3D.new()
	shape.radius = capsule_radius * size_scale - 0.02
	shape.height = maxf(height - 0.04, shape.radius * 2.0)
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
	if not can_mantle:
		return {}
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
	if side_scroll:
		visual_root.rotation.y = PI * 0.5
	reset_physics_interpolation()
	state_machine.transition_to(STATE_GROUND)
	respawned.emit()


## Moves the spawn point (checkpoints) and optionally teleports there now.
func set_spawn(where: Vector3, teleport := true) -> void:
	_spawn_transform.origin = where
	if side_scroll:
		_plane_z = where.z
	if teleport:
		global_position = where
		velocity = Vector3.ZERO
		reset_physics_interpolation()
		camera.snap()


## Stops all movement logic (death, level complete). Animations keep playing.
func set_frozen(frozen: bool) -> void:
	state_machine.process_mode = Node.PROCESS_MODE_DISABLED if frozen else Node.PROCESS_MODE_INHERIT
	controls_enabled = not frozen
	velocity = Vector3.ZERO


func _face_spawn_direction() -> void:
	var spawn_yaw := global_rotation.y
	global_rotation = Vector3.ZERO
	camera.yaw = spawn_yaw
	camera.snap()
	visual_root.rotation.y = spawn_yaw + PI


## Call after changing jump_height / jump_time_to_peak / jump_time_to_descent at runtime.
func recalculate_jump() -> void:
	jump_velocity = 2.0 * jump_height / jump_time_to_peak
	jump_gravity = 2.0 * jump_height / (jump_time_to_peak * jump_time_to_peak)
	fall_gravity = 2.0 * jump_height / (jump_time_to_descent * jump_time_to_descent)
