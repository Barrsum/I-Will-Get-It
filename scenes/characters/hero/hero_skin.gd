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
const GUN_AIM_DOWN := &"Pistol_Aim_Down"
const GUN_AIM := &"Pistol_Aim_Neutral"
const GUN_AIM_UP := &"Pistol_Aim_Up"
const GUN_SHOOT := &"Pistol_Shoot"

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
## Gun mode: an AnimationTree layering an aim pose on the upper body over walking legs.
var _gun_tree: AnimationTree
var _right_hand: BoneAttachment3D


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


# --- Gun mode (on-rails shooter) ------------------------------------------------------------

## Upper-body aim over lower-body locomotion. While on, the AnimationTree drives the skeleton
## and the regular play_* / update_* calls have no visible effect.
func set_gun_mode(enabled: bool) -> void:
	if enabled and _gun_tree == null:
		_gun_tree = _build_gun_tree()
	if _gun_tree:
		_gun_tree.active = enabled
	if not enabled:
		_current = &""
		_play(IDLE, 0.2)


## speed: m/s of the legs; aim_pitch: -1 (down) .. 1 (up).
func set_gun_motion(speed: float, aim_pitch: float) -> void:
	_gun_tree.set(&"parameters/legs/blend_position", speed)
	_gun_tree.set(&"parameters/aim/blend_position", clampf(aim_pitch, -1.0, 1.0))


func play_gun_shot() -> void:
	_gun_tree.set(&"parameters/shot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


## Node that follows the right hand bone (weapon mount point).
func right_hand() -> Node3D:
	if _right_hand == null:
		var skeleton := find_child("GeneralSkeleton", true, false) as Skeleton3D
		_right_hand = BoneAttachment3D.new()
		skeleton.add_child(_right_hand)
		_right_hand.bone_name = "RightHand"
	return _right_hand


func _build_gun_tree() -> AnimationTree:
	var legs := AnimationNodeBlendSpace1D.new()
	legs.min_space = 0.0
	legs.max_space = 6.0
	for point: Array in [[IDLE, 0.0], [WALK, walk_reference_speed], [JOG, jog_reference_speed]]:
		legs.add_blend_point(_clip(point[0]), point[1])
	var aim := AnimationNodeBlendSpace1D.new()
	aim.min_space = -1.0
	aim.max_space = 1.0
	for point: Array in [[GUN_AIM_DOWN, -1.0], [GUN_AIM, 0.0], [GUN_AIM_UP, 1.0]]:
		aim.add_blend_point(_clip(point[0]), point[1])

	var upper_body := _upper_body_tracks()
	var mix := AnimationNodeBlend2.new()
	var shot := AnimationNodeOneShot.new()
	shot.fadein_time = 0.03
	shot.fadeout_time = 0.12
	for filtered: AnimationNode in [mix, shot]:
		filtered.filter_enabled = true
		for track in upper_body:
			filtered.set_filter_path(track, true)

	var graph := AnimationNodeBlendTree.new()
	graph.add_node(&"legs", legs)
	graph.add_node(&"aim", aim)
	graph.add_node(&"mix", mix)
	graph.add_node(&"shoot_clip", _clip(GUN_SHOOT))
	graph.add_node(&"shot", shot)
	graph.connect_node(&"mix", 0, &"legs")
	graph.connect_node(&"mix", 1, &"aim")
	graph.connect_node(&"shot", 0, &"mix")
	graph.connect_node(&"shot", 1, &"shoot_clip")
	graph.connect_node(&"output", 0, &"shot")

	var tree := AnimationTree.new()
	tree.tree_root = graph
	# Same root as the AnimationPlayer so "%GeneralSkeleton:..." tracks resolve.
	var model_root := _player.get_node(_player.root_node)
	model_root.add_child(tree)
	tree.anim_player = tree.get_path_to(_player)
	tree.set(&"parameters/mix/blend_amount", 1.0)
	return tree


func _clip(anim: StringName) -> AnimationNodeAnimation:
	var node := AnimationNodeAnimation.new()
	node.animation = anim
	return node


func _upper_body_tracks() -> Array[NodePath]:
	var bones: Array[String] = ["Spine", "Chest", "UpperChest", "Neck", "Head"]
	for side in ["Left", "Right"]:
		for part in ["Shoulder", "UpperArm", "LowerArm", "Hand"]:
			bones.append(side + part)
		for finger in ["Thumb", "Index", "Middle", "Ring", "Little"]:
			for joint in (["Metacarpal", "Proximal", "Distal"] if finger == "Thumb" else ["Proximal", "Intermediate", "Distal"]):
				bones.append(side + finger + joint)
	var tracks: Array[NodePath] = []
	for bone in bones:
		tracks.append(NodePath("%GeneralSkeleton:" + bone))
	return tracks


func _play(anim: StringName, blend := blend_time, speed := 1.0, restart := false) -> void:
	_player.speed_scale = speed
	if anim == _current and not restart:
		return
	_current = anim
	_player.play(anim, blend)
	if restart:
		_player.seek(0.0, true)
