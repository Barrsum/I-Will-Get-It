extends Node
## Player preferences. Persisted to user://settings.cfg and applied on change.
## Read values directly (Settings.fov); write through set_value() so they save and emit `changed`.

signal changed(key: StringName)

const SAVE_PATH := "user://settings.cfg"
const SECTION := "settings"

var mouse_sensitivity: float = 1.0
var controller_sensitivity: float = 1.0
var invert_look_y: bool = false
var fov: float = 80.0
var sprint_by_default: bool = false
var toggle_crouch: bool = true
var fullscreen: bool = false
var vsync: bool = true
var show_fps: bool = false
var master_volume: float = 0.8
## Read story dialogue with the OS text-to-speech voice until real voice acting exists.
var placeholder_voices: bool = true

## Defaults captured before load(), used by reset_to_defaults().
var _defaults: Dictionary = {}


func _ready() -> void:
	for key in keys():
		_defaults[key] = get(key)
	load_settings()
	_apply_all()


func keys() -> Array[StringName]:
	return [
		&"mouse_sensitivity", &"controller_sensitivity", &"invert_look_y", &"fov",
		&"sprint_by_default", &"toggle_crouch", &"fullscreen", &"vsync", &"show_fps",
		&"master_volume", &"placeholder_voices",
	]


func set_value(key: StringName, value: Variant) -> void:
	if get(key) == value:
		return
	set(key, value)
	_apply(key)
	save_settings()
	changed.emit(key)


func reset_to_defaults() -> void:
	for key in _defaults:
		set_value(key, _defaults[key])


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	for key in keys():
		var stored: Variant = config.get_value(SECTION, key, get(key))
		if typeof(stored) == typeof(get(key)):
			set(key, stored)


func save_settings() -> void:
	var config := ConfigFile.new()
	for key in keys():
		config.set_value(SECTION, key, get(key))
	config.save(SAVE_PATH)


func _apply_all() -> void:
	for key in keys():
		_apply(key)


func _apply(key: StringName) -> void:
	match key:
		&"fullscreen":
			var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
			if DisplayServer.window_get_mode() != mode:
				DisplayServer.window_set_mode(mode)
		&"vsync":
			DisplayServer.window_set_vsync_mode(
				DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
		&"master_volume":
			var bus := AudioServer.get_bus_index(&"Master")
			AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(master_volume, 0.0001)))
			AudioServer.set_bus_mute(bus, master_volume <= 0.0)
