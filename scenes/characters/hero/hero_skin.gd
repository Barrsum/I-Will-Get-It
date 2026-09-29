class_name HeroSkin
extends Node3D
## Visual model + animation for the hero. States talk to this API only, so swapping the
## placeholder mannequin for the real hero model later touches nothing else.
## Animations: Quaternius Universal Animation Library (CC0). Godot's glTF importer strips the
## "_Loop" suffix from clip names and sets those clips to loop.

const IDLE := &"Idle"
const WALK := &"Walk"
const JOG := &"Jog_Fwd"
const SPRINT := &"Sprint"
const CROUCH_IDLE := &"Crouch_Idle"
const CROUCH_MOVE := &"Crouch_Fwd"
const JUMP_START := &"Jump_Start"
const JUMP_LOOP := &"Jump"
const JUMP_LAND := &"Jump_Land"
const DANCE := &"Dance"

@export var blend_time := 0.18
@export_group("Playback speed references (m/s at which each cycle plays at 1x)")
@export var walk_reference_speed := 1.8
@export var jog_reference_speed := 5.0
@export var sprint_reference_speed := 7.5
@export var crouch_reference_speed := 2.2
@export_group("Slide pose")
@export var slide_lean_degrees := -28.0

var _player: AnimationPlayer
var _current: StringName
## While > 0, locomotion updates don't override a one-shot (e.g. the landing).
var _hold_time := 0.0
var _lean_target := 0.0


func _ready() -> void:
	_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
	assert(_player, "HeroSkin needs an AnimationPlayer inside the model")
	_play(IDLE, 0.0)


func _process(delta: float) -> void:
	_hold_time = maxf(_hold_time - delta, 0.0)
	rotation.x = lerp_angle(rotation.x, _lean_target, 1.0 - exp(-14.0 * delta))


func update_locomotion(speed: float) -> void:
	if _hold_time > 0.0 and speed < 0.5:
		return
	if speed < 0.3:
		_play(IDLE)
	elif speed < 3.6:
		_play(WALK, blend_time, speed / walk_reference_speed)
	elif speed < 6.6:
		_play(JOG, blend_time, speed / jog_reference_speed)
	else:
		_play(SPRINT, blend_time, speed / sprint_reference_speed)


func update_crouch(speed: float) -> void:
	if speed < 0.3:
		_play(CROUCH_IDLE)
	else:
		_play(CROUCH_MOVE, blend_time, speed / crouch_reference_speed)


func update_air(vertical_speed: float) -> void:
	if _current == JUMP_START and _player.is_playing() and vertical_speed > 0.0:
		return
	_play(JUMP_LOOP, 0.2)


func play_jump() -> void:
	_hold_time = 0.0
	_play(JUMP_START, 0.06, 1.3, true)


func play_fall() -> void:
	_play(JUMP_LOOP, 0.25)


func play_land(impact_speed: float) -> void:
	if impact_speed > 7.0:
		_play(JUMP_LAND, 0.05, 1.4, true)
		_hold_time = 0.18


# TODO: swap for SLIDE / SLIDE_LOOP from Universal Animation Library 2 once imported.
func play_slide() -> void:
	_play(CROUCH_IDLE, 0.1)
	_lean_target = deg_to_rad(slide_lean_degrees)


func end_slide() -> void:
	_lean_target = 0.0


# TODO: swap for CLIMB_UP_1M from Universal Animation Library 2 once imported.
func play_mantle(duration: float) -> void:
	var length := _player.get_animation(JUMP_START).length
	_play(JUMP_START, 0.05, length / maxf(duration, 0.05), true)


func play_emote() -> void:
	_play(DANCE, 0.25)


func _play(anim: StringName, blend := blend_time, speed := 1.0, restart := false) -> void:
	_player.speed_scale = speed
	if anim == _current and not restart:
		return
	_current = anim
	_player.play(anim, blend)
	if restart:
		_player.seek(0.0, true)
