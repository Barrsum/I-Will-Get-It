extends Node3D
## Title screen, Fortnite-lobby style: the hero stands on a platform in a small 3D scene,
## menu on the left. PLAY opens the level select (cards from Game.LEVELS).

const HERO_SKIN: PackedScene = preload("res://scenes/characters/hero/hero_skin.tscn")
const MENU_X := 110

var _skin: HeroSkin
var _ui: Control
var _main_column: VBoxContainer
var _level_select: Control
var _settings_holder: PanelContainer
var _settings: SettingsPanel
var _play_button: Button
var _emote_timer := 6.0
var _dancing := false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_stage()
	_build_ui()
	_show_main()


func _process(delta: float) -> void:
	# Idle, and every so often bust out the dance.
	_emote_timer -= delta
	if _emote_timer <= 0.0:
		_dancing = not _dancing
		_emote_timer = 5.0 if _dancing else 9.0
		if _dancing:
			_skin.play_emote()
	if not _dancing:
		_skin.update_locomotion(0.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and not _main_column.visible:
		get_viewport().set_input_as_handled()
		_show_main()


# --- 3D stage ---------------------------------------------------------------------------------

func _build_stage() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.1, 0.12, 0.42)
	sky_material.sky_horizon_color = Color(0.45, 0.35, 0.85)
	sky_material.ground_horizon_color = Color(0.45, 0.35, 0.85)
	sky_material.ground_bottom_color = Color(0.08, 0.06, 0.25)
	var sky := Sky.new()
	sky.sky_material = sky_material
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.1
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var key := DirectionalLight3D.new()
	key.light_energy = 1.6
	key.light_color = Color(1.0, 0.93, 0.85)
	key.shadow_enabled = true
	key.basis = Basis.looking_at(Vector3(-0.5, -0.6, -0.6).normalized())
	add_child(key)
	var rim := OmniLight3D.new()
	rim.light_color = Color(0.45, 0.6, 1.0)
	rim.light_energy = 6.0
	rim.omni_range = 7.0
	rim.position = Vector3(3.2, 2.6, -1.8)
	add_child(rim)

	var platform := PlatformerArt.cylinder(1.6, 0.3, PlatformerArt.flat(Color(0.16, 0.2, 0.5), 0.35, 0.2), 48)
	platform.position = Vector3(1.9, -0.15, 0)
	add_child(platform)
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 1.58
	ring_mesh.outer_radius = 1.7
	ring_mesh.rings = 64
	var ring := MeshInstance3D.new()
	ring.mesh = ring_mesh
	ring.material_override = PlatformerArt.flat(UIStyle.ACCENT, 0.3, 0.0, 1.5)
	ring.position = Vector3(1.9, 0.0, 0)
	add_child(ring)

	_skin = HERO_SKIN.instantiate() as HeroSkin
	_skin.position = Vector3(1.9, 0.0, 0)
	_skin.rotation.y = deg_to_rad(-18.0)
	add_child(_skin)

	var camera := Camera3D.new()
	camera.fov = 38.0
	camera.position = Vector3(0.0, 1.25, 5.6)
	add_child(camera)
	camera.look_at(Vector3(0.35, 1.0, 0.0))
	camera.make_current()


# --- UI -----------------------------------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_ui = Control.new()
	_ui.theme = UIStyle.get_theme()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_ui)
	UIStyle.add_left_wash(_ui, 0.6)

	_main_column = VBoxContainer.new()
	_main_column.custom_minimum_size.x = 620
	_main_column.add_theme_constant_override(&"separation", 12)
	_main_column.add_child(UIStyle.label("A LOVE STORY. SORT OF.", UIStyle.heading_font(), 30, UIStyle.ACCENT))
	var title := UIStyle.label("I WILL\nGET IT", UIStyle.heading_font(), 150)
	title.add_theme_constant_override(&"line_spacing", -40)
	_main_column.add_child(title)
	var tagline := UIStyle.label("He promised her the impossible.\nA thousand-year comet said yes.",
		UIStyle.BODY_FONT, 32, UIStyle.TEXT_DIM)
	_main_column.add_child(tagline)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 28
	_main_column.add_child(spacer)
	_play_button = UIStyle.menu_button(_main_column, "PLAY", _show_level_select)
	UIStyle.menu_button(_main_column, "MOVEMENT GYM", Game.open_gym)
	UIStyle.menu_button(_main_column, "SETTINGS", _show_settings)
	UIStyle.menu_button(_main_column, "QUIT", get_tree().quit)
	_main_column.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT, Control.PRESET_MODE_MINSIZE, MENU_X)
	_main_column.grow_vertical = Control.GROW_DIRECTION_BOTH
	_ui.add_child(_main_column)

	_level_select = _build_level_select()
	_ui.add_child(_level_select)

	_settings_holder = PanelContainer.new()
	_settings_holder.anchor_left = 0.42
	_settings_holder.anchor_right = 1.0
	_settings_holder.anchor_top = 0.5
	_settings_holder.anchor_bottom = 0.5
	_settings_holder.offset_right = -MENU_X
	_settings_holder.grow_vertical = Control.GROW_DIRECTION_BOTH
	_settings = SettingsPanel.new()
	_settings.back_requested.connect(_show_main)
	_settings_holder.add_child(_settings)
	_ui.add_child(_settings_holder)

	var version := UIStyle.label("v%s  ·  PROTOTYPE" % ProjectSettings.get_setting("application/config/version"),
		UIStyle.BODY_BOLD_FONT, 22, Color(UIStyle.TEXT, 0.5))
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 28)
	version.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	version.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_ui.add_child(version)


func _build_level_select() -> Control:
	var page := VBoxContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT, Control.PRESET_MODE_MINSIZE, MENU_X)
	page.grow_vertical = Control.GROW_DIRECTION_BOTH
	page.add_theme_constant_override(&"separation", 22)
	page.add_child(UIStyle.label("SELECT LEVEL", UIStyle.heading_font(), 96))
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override(&"separation", 22)
	page.add_child(cards)
	for level in Game.LEVELS:
		cards.add_child(_level_card(level))
	var back_row := HBoxContainer.new()
	UIStyle.menu_button(back_row, "BACK", _show_main, 30)
	page.add_child(back_row)
	return page


func _level_card(level: Dictionary) -> Control:
	var available: bool = level.scene != ""
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(360, 400)
	if not available:
		card.modulate = Color(1, 1, 1, 0.55)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 6)
	card.add_child(column)
	column.add_child(UIStyle.label("LEVEL %d" % level.number, UIStyle.heading_font(), 30, UIStyle.ACCENT))
	var title := UIStyle.label(level.title, UIStyle.heading_font(), 58)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD
	column.add_child(title)
	column.add_child(UIStyle.label(level.genre, UIStyle.BODY_BOLD_FONT, 26, UIStyle.TEXT_DIM))
	if level.boast != "":
		var boast := UIStyle.label(level.boast, UIStyle.BODY_FONT, 26, UIStyle.TEXT)
		boast.autowrap_mode = TextServer.AUTOWRAP_WORD
		boast.custom_minimum_size.x = 280
		column.add_child(boast)
	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(filler)
	var button := UIStyle.menu_button(column, "PLAY" if available else "LOCKED",
		Game.start_level.bind(level.id), 34)
	button.disabled = not available
	return card


func _show_main() -> void:
	_main_column.show()
	_level_select.hide()
	_settings_holder.hide()
	_play_button.grab_focus()


func _show_level_select() -> void:
	_main_column.hide()
	_level_select.show()
	_settings_holder.hide()
	var first := _level_select.find_children("*", "Button", true, false)
	for button: Button in first:
		if not button.disabled:
			button.grab_focus()
			break


func _show_settings() -> void:
	_settings_holder.show()
	_settings.focus_first()
