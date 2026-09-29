class_name HeroSkin
extends Node3D
## Visual model + animation for the hero. States talk to this API only, so swapping the
## placeholder mannequin for the real hero model later touches nothing else.
## Animations: Quaternius Universal Animation Library 1 + 2 (CC0), both retargeted at import onto
## Godot's SkeletonProfileHumanoid via bone maps, so any humanoid clip plays on any humanoid model.
## Godot's glTF importer strips the "_Loop" suffix from clip names and sets those clips to loop.

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
const DEATH := &"Death01"
const SLIDE_START := &"ual2/Slide_Start"
const SLIDE_LOOP := &"ual2/Slide"
const CLIMB := &"ual2/ClimbUp_1m"
const HIT := &"ual2/Hit_Knockback"

const UAL2_LIBRARY: AnimationLibrary = preload("res://assets/models/characters/animations/ual2_animations.glb")

@export var blend_time := 0.18
@export_group("Playback speed references (m/s at which each cycle plays at 1x)")
@export var walk_reference_speed := 1.8
@export var jog_reference_speed := 5.0
@export var sprint_reference_speed := 7.5
@export var crouch_reference_speed := 2.2

var _player: AnimationPlayer
var _current: StringName
## While > 0, locomotion updates don't override a one-shot (e.g. the landing).
var _hold_time := 0.0
## One-shot clip to continue into when the current one finishes (e.g. slide start -> slide loop).
var _queued: StringName = &""


func _ready() -> void:
	_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
	assert(_player, "HeroSkin needs an AnimationPlayer inside the model")
	if not _player.has_animation_library(&"ual2"):
		_player.add_animation_library(&"ual2", UAL2_LIBRARY)
	_play(IDLE, 0.0)


func _process(delta: float) -> void:
	_hold_time = maxf(_hold_time - delta, 0.0)
	if _queued != &"" and not _player.is_playing():
		_play(_queued, 0.1)
		_queued = &""


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


func play_slide() -> void:
	_play(SLIDE_START, 0.08, 1.4, true)
	_queued = SLIDE_LOOP


func end_slide() -> void:
	_queued = &""


## Plays the climb-up clip stretched to the scripted mantle duration.
func play_mantle(duration: float) -> void:
	var length := _player.get_animation(CLIMB).length
	_play(CLIMB, 0.06, length / maxf(duration, 0.05), true)


func play_hit() -> void:
	_play(HIT, 0.05, 1.3, true)
	_hold_time = 0.35


func play_death() -> void:
	_queued = &""
	_play(DEATH, 0.1, 1.0, true)


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
