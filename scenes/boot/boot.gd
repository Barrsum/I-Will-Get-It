extends Control
## Placeholder boot screen. Replaced later by the studio splash + title menu.


func _ready() -> void:
	print("I Will Get It v%s — boot OK (Godot %s)" % [
		ProjectSettings.get_setting("application/config/version"),
		Engine.get_version_info().string,
	])
