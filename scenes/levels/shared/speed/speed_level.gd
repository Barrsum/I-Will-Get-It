class_name SpeedLevel
extends Node3D
## Base for high-speed 3D platforming levels: the Fortnite-style hero tuned for momentum,
## boost pads, springs, loops, coins, a coin gate, checkpoints with instant respawn, and a
## finish arch. Subclasses override build_course() and set `spawn_point` / rank times.

const HERO_SCENE: PackedScene = preload("res://scenes/characters/hero/hero.tscn")

@export var level_title := "LEVEL"
@export var boast := ""
@export var kill_height := -12.0
## Finish times (seconds) for ranks S, A, B; slower is C.
@export var rank_times := Vector3(45.0, 60.0, 80.0)

var hero: Hero
var hud: PlatformerHUD
var coins := 0
var spawn_point := Vector3.ZERO
## Spawn facing (camera yaw), radians.
var spawn_yaw := 0.0

var _checkpoints: Array[Checkpoint] = []
var _finished := false


## Override: build geometry, pickups and gadgets; set spawn_point.
func build_course() -> void:
	pass


func _ready() -> void:
	PlatformerArt.clear_cache()
	build_course()
	_spawn_hero()
	hud = PlatformerHUD.new()
	add_child(hud)
	hud.setup(self)
	add_child(PauseMenu.new())
	hud.show_intro(level_title, boast)


func _process(delta: float) -> void:
	if not _finished:
		Game.elapsed += delta


func _physics_process(_delta: float) -> void:
	if not _finished and hero.global_position.y < kill_height:
		Game.deaths += 1
		hero.respawn()
		hud.toast("WHOOPS!")


# --- Rules --------------------------------------------------------------------------------------

func add_coin() -> void:
	coins += 1
	hud.set_coins(coins)


func reach_checkpoint(checkpoint: Checkpoint) -> void:
	if checkpoint.active:
		return
	checkpoint.activate()
	hero.set_spawn(checkpoint.global_position + Vector3(0, 0.1, 0), false)
	hud.toast("CHECKPOINT!")


func finish() -> void:
	if _finished:
		return
	_finished = true
	hero.set_frozen(true)
	hero.visual_root.rotation.y = hero.camera.yaw  # Face the camera.
	hero.skin.play_emote()
	var rank := Label.new()
	rank.text = "RANK  %s" % rank_for(Game.elapsed)
	rank.add_theme_font_override(&"font", UIStyle.heading_font())
	rank.add_theme_font_size_override(&"font_size", 60)
	hud.show_results("FINISH!", [
		["TIME", LevelHUD.format_time(Game.elapsed)],
		["COINS", "%d" % coins],
		["FALLS", "%d" % Game.deaths],
	], rank)


func rank_for(seconds: float) -> String:
	if seconds <= rank_times.x:
		return "S"
	if seconds <= rank_times.y:
		return "A"
	if seconds <= rank_times.z:
		return "B"
	return "C"


# --- Helpers for subclasses -----------------------------------------------------------------------

func add_boost_pad(where: Vector3, yaw := 0.0, speed := 28.0) -> BoostPad:
	var pad := BoostPad.new()
	pad.speed = speed
	pad.position = where
	pad.rotation.y = yaw
	add_child(pad)
	return pad


func add_spring(where: Vector3, up := 26.0, forward := 12.0, yaw := 0.0) -> SpringPad:
	var spring := SpringPad.new()
	spring.up_speed = up
	spring.forward_speed = forward
	spring.position = where
	spring.rotation.y = yaw
	add_child(spring)
	return spring


## `side_shift`: which side the exit lane comes out (+ right / - left).
func add_loop(where: Vector3, radius := 8.0, side_shift := 4.0) -> LoopTrack:
	var loop := LoopTrack.new()
	loop.radius = radius
	loop.side_shift = side_shift
	loop.position = where
	add_child(loop)
	loop.too_slow.connect(func() -> void: hud.toast("NEED MORE SPEED!", Color(1.0, 0.5, 0.4)))
	return loop


func add_coin_at(where: Vector3) -> void:
	var coin := Coin.new()
	coin.level = self
	coin.position = where
	add_child(coin)


## Line of coins from a to b (inclusive), `count` of them.
func add_coin_line(a: Vector3, b: Vector3, count: int) -> void:
	for i in count:
		add_coin_at(a.lerp(b, float(i) / maxi(count - 1, 1)))


## Arc of coins following a jump from a to b peaking `height` above the midpoint.
func add_coin_arc(a: Vector3, b: Vector3, height: float, count: int) -> void:
	for i in count:
		var t := float(i) / maxi(count - 1, 1)
		add_coin_at(a.lerp(b, t) + Vector3.UP * sin(t * PI) * height)


func add_coin_gate(where: Vector3, required: int, width := 14.0) -> CoinGate:
	var gate := CoinGate.new()
	gate.required = required
	gate.width = width
	gate.level = self
	gate.position = where
	add_child(gate)
	gate.blocked.connect(func() -> void: hud.toast("NEED %d COINS!" % required, Color(1.0, 0.5, 0.4)))
	return gate


## Checkpoint across the whole track at `where` (track centre), flag at the right edge.
func add_checkpoint(where: Vector3, track_width := 16.0) -> Checkpoint:
	var checkpoint := Checkpoint.new()
	checkpoint.trigger_width = track_width
	checkpoint.flag_offset_x = track_width * 0.5 - 0.6
	checkpoint.level = self
	checkpoint.position = where
	add_child(checkpoint)
	_checkpoints.append(checkpoint)
	return checkpoint


func add_finish(where: Vector3, width := 16.0) -> FinishArch:
	var arch := FinishArch.new()
	arch.width = width
	arch.position = where
	add_child(arch)
	arch.crossed.connect(finish)
	return arch


func _spawn_hero() -> void:
	hero = HERO_SCENE.instantiate() as Hero
	hero.can_aim = false
	hero.jog_speed = 9.0
	hero.sprint_speed = 14.0
	hero.ground_acceleration = 38.0
	hero.ground_deceleration = 30.0
	hero.overspeed_decay = 5.0
	hero.air_acceleration = 24.0
	hero.jump_height = 2.6
	hero.jump_time_to_peak = 0.4
	hero.jump_time_to_descent = 0.34
	hero.max_fall_speed = 40.0
	hero.slide_min_entry_speed = 10.0
	hero.slide_max_speed = 30.0
	hero.position = spawn_point
	hero.rotation.y = spawn_yaw
	add_child(hero)
	hero.skin.jog_reference_speed = 7.0
	hero.skin.sprint_reference_speed = 11.0
