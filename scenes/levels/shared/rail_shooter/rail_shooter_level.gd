class_name RailShooterLevel
extends Node3D
## Base for on-rails shooting levels. The hero walks forward (-Z) at a fixed pace while the
## player aims freely (within a yaw limit) and shoots pop-up TargetPlates with the Railgun.
## Every consecutive hit raises the score multiplier; a stray shot, an escaped target or
## shooting a friendly (heart) plate resets it.
## Subclasses override build_set() (environment + scenery) and build_targets() (target data).

const HERO_SCENE: PackedScene = preload("res://scenes/characters/hero/hero.tscn")
const FIRE_INTERVAL := 0.26
const MAX_MULTIPLIER := 10
const FRIENDLY_PENALTY := 250
const AIM_RANGE := 250.0
const GRAVITY := 30.0

@export var level_title := "LEVEL"
@export var boast := ""
@export var walk_speed := 3.0
## Distance walked (along -Z from the start) before the level ends.
@export var track_length := 220.0
@export var look_limit_degrees := 80.0

var hero: Hero
var hud: ShooterHUD
var gun: Railgun

var score := 0
var multiplier := 1
var best_multiplier := 1
var shots := 0
var hits := 0
var friendly_hits := 0
var hostile_total := 0

var _targets: Array[TargetPlate] = []
var _next_target := 0
var _cooldown := 0.0
var _finished := false
var _start_z := 0.0


## Override: sky, lights and scenery.
func build_set() -> void:
	pass


## Override: one Dictionary per target —
## {position: Vector3, face: Vector3, kind: TargetPlate.Kind, lifetime: float,
##  sway: float, post: bool, trigger_z: float}
func build_targets() -> Array[Dictionary]:
	return []


func _ready() -> void:
	build_set()
	_spawn_hero()
	_spawn_targets(build_targets())
	hud = ShooterHUD.new()
	add_child(hud)
	hud.setup(self)
	hud.set_multiplier(multiplier, false)
	add_child(PauseMenu.new())
	hud.show_intro(level_title, boast)


func _physics_process(delta: float) -> void:
	if _finished:
		return
	hero.velocity = Vector3(0.0, hero.velocity.y - GRAVITY * delta, -walk_speed)
	hero.move()
	hero.update_facing(delta, Vector3.ZERO)
	while _next_target < _targets.size() and hero.global_position.z <= _targets[_next_target].trigger_z:
		_targets[_next_target].activate()
		_next_target += 1
	if progress() >= 1.0:
		_finish()


func _process(delta: float) -> void:
	var aim := _aim_ray()
	gun.aim_at(aim.position)
	var pitch := hero.camera.pitch / deg_to_rad(40.0)
	hero.skin.set_gun_motion(0.0 if _finished else walk_speed, pitch)
	_cooldown -= delta
	if not _finished and Input.is_action_pressed(&"fire") and _cooldown <= 0.0 \
			and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_shoot(aim)


func progress() -> float:
	return clampf((_start_z - hero.global_position.z) / track_length, 0.0, 1.0)


func accuracy() -> float:
	return float(hits) / shots if shots > 0 else 0.0


func rank() -> String:
	var ratio := float(hits) / maxi(hostile_total, 1)
	if ratio >= 0.95 and friendly_hits == 0:
		return "S"
	if ratio >= 0.8:
		return "A"
	if ratio >= 0.6:
		return "B"
	return "C"


func on_target_escaped(target: TargetPlate) -> void:
	if target.is_hostile():
		_break_combo("MISSED ONE")


# --- Shooting ---------------------------------------------------------------------------------

func _aim_ray() -> Dictionary:
	var camera := hero.camera.camera
	var from := camera.global_position
	var to := from + hero.camera.aim_direction() * AIM_RANGE
	var query := PhysicsRayQueryParameters3D.create(from, to, Hero.LAYER_WORLD | TargetPlate.LAYER_TARGET, [hero.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {"position": to, "collider": null}
	return hit


func _shoot(aim: Dictionary) -> void:
	_cooldown = FIRE_INTERVAL
	shots += 1
	hero.skin.play_gun_shot()
	hero.camera.add_recoil(0.012)
	var target := aim.collider as TargetPlate
	var scored := target != null and target.hit()
	gun.fire_effects(aim.position, aim.collider != null)
	if not scored:
		_break_combo("MISS")
		return
	if not target.is_hostile():
		friendly_hits += 1
		score = maxi(score - FRIENDLY_PENALTY, 0)
		hud.popup_at(hero.camera.camera, aim.position, "-%d" % FRIENDLY_PENALTY, Color(1.0, 0.35, 0.35))
		_break_combo("DON'T SHOOT HEARTS!")
		return
	hits += 1
	var points := target.points() * multiplier
	score += points
	hud.popup_at(hero.camera.camera, aim.position, "+%d" % points)
	multiplier = mini(multiplier + 1, MAX_MULTIPLIER)
	best_multiplier = maxi(best_multiplier, multiplier)
	hud.set_multiplier(multiplier, true)


func _break_combo(reason: String) -> void:
	if multiplier > 1:
		hud.toast(reason, Color(1.0, 0.45, 0.4))
	multiplier = 1
	hud.set_multiplier(multiplier, false)


# --- Setup ------------------------------------------------------------------------------------

func _spawn_hero() -> void:
	hero = HERO_SCENE.instantiate() as Hero
	hero.force_aim = true
	hero.can_mantle = false
	hero.position = Vector3(0, 0.05, 0)
	add_child(hero)
	_start_z = hero.global_position.z
	hero.state_machine.process_mode = Node.PROCESS_MODE_DISABLED  # The level drives movement.
	hero.skin.set_gun_mode(true)
	hero.camera.aim_arm_length = 3.0
	hero.camera.aim_shoulder_offset = 1.05
	hero.camera.aim_fov_multiplier = 0.95
	hero.camera.yaw_center = 0.0
	hero.camera.yaw_limit = deg_to_rad(look_limit_degrees)
	hero.camera.pitch = deg_to_rad(4.0)
	hero.camera.snap()
	gun = Railgun.new()
	add_child(gun)
	gun.hand = hero.skin.right_hand()


func _spawn_targets(data: Array[Dictionary]) -> void:
	# Hero walks toward -Z, so targets trigger in order of decreasing trigger_z.
	data.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.trigger_z > b.trigger_z)
	for entry in data:
		var target := TargetPlate.new()
		target.level = self
		target.kind = entry.kind
		target.lifetime = entry.lifetime
		target.sway = entry.get("sway", 0.0)
		target.has_post = entry.get("post", true)
		target.face_point = entry.face
		target.trigger_z = entry.trigger_z
		target.position = entry.position
		add_child(target)
		_targets.append(target)
		if target.is_hostile():
			hostile_total += 1


func _finish() -> void:
	_finished = true
	hero.velocity = Vector3.ZERO
	# Let any still-standing targets drop quietly.
	for target in _targets:
		if target.phase == TargetPlate.Phase.UP:
			target.phase = TargetPlate.Phase.DOWN
	await get_tree().create_timer(0.8).timeout
	hud.show_shooter_results()
