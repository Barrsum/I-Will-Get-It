extends Node
## Game flow: level registry, scene changes with a fade, and per-run level state
## (checkpoint, deaths, elapsed time) that survives reloading a level after a death.

const MAIN_MENU := "res://scenes/ui/main_menu.tscn"
const GYM := "res://scenes/levels/test_gym/test_gym.tscn"

## Levels shown in the level select. `scene` empty = not built yet (shown locked).
const LEVELS: Array[Dictionary] = [
	{"id": &"level_01", "number": 1, "title": "STOMP ROAD", "genre": "Classic side-scrolling platformer",
		"boast": "\"I'd stomp a hundred monsters for her!\"", "scene": "res://scenes/levels/level_01/level_01.tscn"},
	{"id": &"level_02", "number": 2, "title": "RAILGUN ALLEY", "genre": "On-rails target shooter",
		"boast": "\"I'd blast through a whole city for her!\"", "scene": "res://scenes/levels/level_02/level_02.tscn"},
	{"id": &"level_03", "number": 3, "title": "???", "genre": "Coming soon", "boast": "", "scene": ""},
]

const FADE_TIME := 0.25

## Current run of a level. Reset by start_level(), kept by reload_level().
var current_level: Dictionary = {}
var checkpoint_index := -1
var deaths := 0
var elapsed := 0.0

var _fade: ColorRect
var _busy := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.02, 0.03, 0.1, 0.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)


func level_by_id(id: StringName) -> Dictionary:
	for level in LEVELS:
		if level.id == id:
			return level
	return {}


## The playable level after the current one, or {} if there isn't one yet.
func next_level() -> Dictionary:
	var index := LEVELS.find(current_level)
	if index < 0 or index + 1 >= LEVELS.size() or LEVELS[index + 1].scene == "":
		return {}
	return LEVELS[index + 1]


func start_level(id: StringName) -> void:
	var level := level_by_id(id)
	if level.is_empty() or level.scene == "":
		return
	current_level = level
	checkpoint_index = -1
	deaths = 0
	elapsed = 0.0
	change_scene(level.scene)


## Reloads the current scene, keeping checkpoint/deaths/time (used after dying).
func reload_level() -> void:
	change_scene(get_tree().current_scene.scene_file_path)


## Full restart of the current level (pause menu RESTART).
func restart_level() -> void:
	if current_level.is_empty():
		reload_level()
	else:
		start_level(current_level.id)


func open_gym() -> void:
	current_level = {}
	change_scene(GYM)


func goto_main_menu() -> void:
	current_level = {}
	change_scene(MAIN_MENU)


func change_scene(path: String) -> void:
	if _busy:
		return
	_busy = true
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, FADE_TIME)
	await tween.finished
	get_tree().paused = false
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	tween = create_tween()
	tween.tween_property(_fade, "color:a", 0.0, FADE_TIME)
	await tween.finished
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
