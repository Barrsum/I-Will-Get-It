class_name RailShooterLevel
extends Node3D
## Base for on-rails turret-shooter levels. A vehicle drives down -Z; the hero rides its turret
## mount and aims freely (within a yaw limit) with a mounted Railgun. Every consecutive kill
## raises the score multiplier (max x10); a stray shot or an escaped target resets it.
##
## Subclasses override:
##   build_set()        sky, lights, scenery
##   build_vehicle()    returns the vehicle root; must contain (at any depth) nodes named
##                      "Mount" (where the hero stands) and "GunPivot" (turret gun anchor)
##   build_targets()    target data (see _spawn_targets)
##   intro()            coroutine played before driving starts (cutscene / dialogue)
##   speak(lines)       dialogue hook (animate the speaker)
##   dialogue_cues()    [{at: progress 0..1, lines: [...]}] radio chatter during the run
##   outro()            coroutine played when the run ends, before results

const HERO_SCENE: PackedScene = preload("res://scenes/characters/hero/hero.tscn")
const FIRE_INTERVAL := 0.22
const MAX_MULTIPLIER := 10
const AIM_RANGE := 250.0
## Turret gun position relative to the hero's feet, in the hero's aim frame.
const GUN_OFFSET := Vector3(0.0, 1.3, -0.75)

@export var level_title := "LEVEL"
@export var boast := ""
@export var drive_speed := 7.0
## Distance driven (along -Z from the start) before the level ends.
@export var track_length := 240.0
@export var look_limit_degrees := 85.0

var hero: Hero
var hud: ShooterHUD
var gun: Railgun
var vehicle: Node3D
var dialogue: Dialogue

var score := 0
var multiplier := 1
var best_multiplier := 1
var shots := 0
var hits := 0
var kills := 0
var hostile_total := 0

var driving := false
var can_shoot := false
## While true the hero is pinned to the vehicle's Mount; intros can clear it to animate the hero.
var hero_on_mount := true

var _mount: Node3D
var _targets: Array[ShooterTarget] = []
var _next_target := 0
var _cooldown := 0.0
var _finished := false
var _start_z := 0.0
var _speed := 0.0
var _cues: Array[Dictionary] = []


func build_set() -> void:
	pass


func build_vehicle() -> Node3D:
	return Node3D.new()


## Each: {position, face, kind (AlienTarget.Kind), lifetime, sway, trigger_z}
func build_targets() -> Array[Dictionary]:
	return []


func intro() -> void:
	pass


func dialogue_cues() -> Array[Dictionary]:
	return []


func outro() -> void:
	pass


## Plays dialogue lines; override to animate whoever is talking. Await to wait for the end.
func speak(lines: Array) -> void:
	await dialogue.say(lines)


func _ready() -> void:
	build_set()
	vehicle = build_vehicle()
	add_child(vehicle)
	_start_z = vehicle.global_position.z
	_mount = vehicle.find_child("Mount", true, false)
	_spawn_hero()
	_spawn_targets(build_targets())
	dialogue = Dialogue.new()
	add_child(dialogue)
	hud = ShooterHUD.new()
	add_child(hud)
	hud.setup(self)
	hud.set_multiplier(multiplier, false)
	add_child(PauseMenu.new())
	_cues = dialogue_cues()
	_run.call_deferred()


func _run() -> void:
	await intro()
	driving = true
	can_shoot = true


func _physics_process(delta: float) -> void:
	if driving and not _finished:
		_speed = move_toward(_speed, drive_speed, 3.0 * delta)
		vehicle.global_position.z -= _speed * delta
	if hero_on_mount:
		hero.global_position = _mount.global_position
		hero.update_facing(delta, Vector3.ZERO)
	while _next_target < _targets.size() and vehicle.global_position.z <= _targets[_next_target].trigger_z:
		_targets[_next_target].activate()
		_next_target += 1
	while not _cues.is_empty() and progress() >= _cues[0].at and not dialogue.is_talking():
		speak(_cues.pop_front().lines)
	if driving and not _finished and progress() >= 1.0:
		_finish()


func _process(delta: float) -> void:
	var aim := _aim_ray()
	# The turret swings around the hero with the aim so the barrel stays in front of him.
	gun.mount.global_position = _mount.global_position + Basis(Vector3.UP, hero.camera.yaw) * GUN_OFFSET
	gun.aim_at(aim.position)
	hero.skin.set_gun_motion(0.0, hero.camera.pitch / deg_to_rad(40.0))
	_cooldown -= delta
	if can_shoot and not _finished and Input.is_action_pressed(&"fire") and _cooldown <= 0.0 \
			and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		shoot()


func progress() -> float:
	return clampf((_start_z - vehicle.global_position.z) / track_length, 0.0, 1.0)


func accuracy() -> float:
	return float(hits) / shots if shots > 0 else 0.0


func rank() -> String:
	var ratio := float(kills) / maxi(hostile_total, 1)
	if ratio >= 0.95:
		return "S"
	if ratio >= 0.8:
		return "A"
	if ratio >= 0.6:
		return "B"
	return "C"


func on_target_escaped(_target: ShooterTarget) -> void:
	_break_combo("ONE GOT AWAY")


func shoot() -> void:
	var aim := _aim_ray()
	_cooldown = FIRE_INTERVAL
	shots += 1
	hero.skin.play_gun_shot()
	hero.camera.add_recoil(0.01)
	var target := aim.collider as ShooterTarget
	var result := target.hit() if target else ShooterTarget.HitResult.NONE
	gun.fire_effects(aim.position, aim.collider != null)
	match result:
		ShooterTarget.HitResult.NONE:
			_break_combo("MISS")
		ShooterTarget.HitResult.DAMAGED:
			hits += 1
			hud.popup_at(hero.camera.camera, aim.position, "HIT", Color(1, 1, 1))
		ShooterTarget.HitResult.KILLED:
			hits += 1
			kills += 1
			var points := target.points() * multiplier
			score += points
			hud.popup_at(hero.camera.camera, aim.position, "+%d" % points)
			multiplier = mini(multiplier + 1, MAX_MULTIPLIER)
			best_multiplier = maxi(best_multiplier, multiplier)
			hud.set_multiplier(multiplier, true)


func _aim_ray() -> Dictionary:
	var camera := hero.camera.camera
	var from := camera.global_position
	var to := from + hero.camera.aim_direction() * AIM_RANGE
	var query := PhysicsRayQueryParameters3D.create(from, to, Hero.LAYER_WORLD | ShooterTarget.LAYER_TARGET, [hero.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {"position": to, "collider": null}
	return hit


func _break_combo(reason: String) -> void:
	if multiplier > 1:
		hud.toast(reason, Color(1.0, 0.45, 0.4))
	multiplier = 1
	hud.set_multiplier(multiplier, false)


func mount_position() -> Vector3:
	return _mount.global_position


func _spawn_hero() -> void:
	hero = HERO_SCENE.instantiate() as Hero
	hero.force_aim = true
	hero.can_mantle = false
	hero.position = _mount.global_position
	add_child(hero)
	hero.set_frozen(true)  # The level positions the hero; no player movement.
	hero.collision_shape.disabled = true
	hero.skin.set_gun_mode(true)
	hero.camera.aim_arm_length = 3.4
	hero.camera.aim_shoulder_offset = 1.0
	hero.camera.aim_fov_multiplier = 1.0
	hero.camera.pivot_height = 1.9
	hero.camera.yaw_center = 0.0
	hero.camera.yaw_limit = deg_to_rad(look_limit_degrees)
	hero.camera.pitch = deg_to_rad(2.0)
	hero.camera.snap()
	gun = Railgun.new()
	gun.scale_factor = 2.4
	add_child(gun)
	gun.mount = vehicle.find_child("GunPivot", true, false)


func _spawn_targets(data: Array[Dictionary]) -> void:
	# The vehicle drives toward -Z, so targets trigger in order of decreasing trigger_z.
	data.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.trigger_z > b.trigger_z)
	for entry in data:
		var target := AlienTarget.new()
		target.configure(entry.kind)
		target.level = self
		target.lifetime = entry.lifetime
		target.sway = entry.get("sway", 0.0)
		target.face_point = entry.face
		target.trigger_z = entry.trigger_z
		target.position = entry.position
		add_child(target)
		_targets.append(target)
		hostile_total += 1


func _finish() -> void:
	_finished = true
	can_shoot = false
	for target in _targets:
		target.retire()
	await outro()
	hud.show_shooter_results()
