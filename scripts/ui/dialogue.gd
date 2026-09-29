class_name Dialogue
extends CanvasLayer
## Subtitle-style dialogue bar: speaker name, typewriter text, auto-advance.
## Used for story radio chatter (the Commander now, the Bro later).
##
##   await dialogue.say([{"speaker": "COMMANDER", "text": "Get on that gun.", "voice": &"commander"}])
##
## Voices: until real voice acting exists, lines are read by the OS text-to-speech engine as a
## placeholder when Settings.placeholder_voices is on (pitch/rate per voice profile).

signal finished

const CHARS_PER_SECOND := 40.0
const HOLD_AFTER := 1.3

## Placeholder TTS profiles. `prefer` = substrings of OS voice names to pick if installed.
const VOICES := {
	&"commander": {"pitch": 0.55, "rate": 0.9, "prefer": ["David", "Guy", "Mark", "George", "Male"], "color": Color(0.55, 0.85, 0.45)},
	&"bro": {"pitch": 1.1, "rate": 1.1, "prefer": ["Mark", "David", "Male"], "color": Color(0.4, 0.75, 1.0)},
	&"hero": {"pitch": 1.0, "rate": 1.05, "prefer": ["David", "Mark"], "color": UIStyle.ACCENT},
}

var _panel: PanelContainer
var _speaker: Label
var _text: Label
var _stripe: ColorRect
var _skip := false


func _ready() -> void:
	layer = 8
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.theme = UIStyle.get_theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 70)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.custom_minimum_size.x = 1100
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 22)
	_panel.add_child(row)
	_stripe = ColorRect.new()
	_stripe.custom_minimum_size = Vector2(10, 0)
	row.add_child(_stripe)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	_speaker = UIStyle.label("", UIStyle.heading_font(), 34, UIStyle.ACCENT)
	column.add_child(_speaker)
	_text = UIStyle.label("", UIStyle.BODY_BOLD_FONT, 36)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size.x = 1000
	column.add_child(_text)
	_panel.hide()


## Plays the lines in order; await it to continue after the last one.
func say(lines: Array) -> void:
	for line: Dictionary in lines:
		await _show_line(line)
	_panel.hide()
	finished.emit()


func is_talking() -> bool:
	return _panel.visible


func _show_line(line: Dictionary) -> void:
	var voice: StringName = line.get("voice", &"")
	var profile: Dictionary = VOICES.get(voice, {})
	_speaker.text = line.get("speaker", "")
	var color: Color = profile.get("color", UIStyle.ACCENT)
	_speaker.add_theme_color_override(&"font_color", color)
	_stripe.color = color
	_text.text = line.text
	_text.visible_ratio = 0.0
	_panel.show()
	_speak(line.text, profile)
	var text: String = line.text
	var duration := text.length() / CHARS_PER_SECOND
	var tween := create_tween()
	tween.tween_property(_text, "visible_ratio", 1.0, duration)
	await tween.finished
	await get_tree().create_timer(HOLD_AFTER + text.length() * 0.012).timeout


func _speak(text: String, profile: Dictionary) -> void:
	if profile.is_empty() or not Settings.placeholder_voices:
		return
	if not ProjectSettings.get_setting("audio/general/text_to_speech", false):
		return
	var voice_id := _pick_voice(profile.prefer)
	if voice_id == "":
		return
	DisplayServer.tts_stop()
	DisplayServer.tts_speak(text, voice_id, int(Settings.master_volume * 100), profile.pitch, profile.rate)


## First installed English voice whose name contains one of `prefer`, else any English voice.
func _pick_voice(prefer: Array) -> String:
	var english: Array[Dictionary] = []
	for voice: Dictionary in DisplayServer.tts_get_voices():
		if str(voice.get("language", "")).begins_with("en"):
			english.append(voice)
	if english.is_empty():
		return ""
	for wanted: String in prefer:
		for voice in english:
			if wanted.to_lower() in str(voice.get("name", "")).to_lower():
				return voice.id
	return english[0].id


func _exit_tree() -> void:
	if ProjectSettings.get_setting("audio/general/text_to_speech", false):
		DisplayServer.tts_stop()
