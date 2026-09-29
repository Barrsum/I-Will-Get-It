class_name UIStyle
extends RefCounted
## The game's shared UI look: heavy slanted condensed headings, skewed panels and buttons,
## bright yellow focus highlight on deep navy. Use UIStyle.get_theme() on any root Control.

const NAVY := Color("0a1030")
const PANEL := Color(0.04, 0.07, 0.2, 0.86)
const PANEL_EDGE := Color(0.35, 0.6, 1.0, 0.35)
const ACCENT := Color("ffd21f")
const ACCENT_BRIGHT := Color("ffe766")
const BLUE := Color("3d8bff")
const TEXT := Color("f4f7ff")
const TEXT_DIM := Color("a9b8e0")
const SKEW := 0.18

const HEADING_FONT: FontFile = preload("res://assets/fonts/anton/Anton-Regular.ttf")
const BODY_FONT: FontFile = preload("res://assets/fonts/barlow_condensed/BarlowCondensed-SemiBold.ttf")
const BODY_BOLD_FONT: FontFile = preload("res://assets/fonts/barlow_condensed/BarlowCondensed-Bold.ttf")

static var _theme: Theme
static var _heading: FontVariation


## Anton with a forward slant — the chunky italic headline look.
static func heading_font() -> FontVariation:
	if _heading == null:
		_heading = FontVariation.new()
		_heading.base_font = HEADING_FONT
		_heading.variation_transform = Transform2D(Vector2(1, 0), Vector2(SKEW, 1), Vector2.ZERO)
		_heading.spacing_glyph = 1
	return _heading


static func label(text: String, font: Font, font_size: int, color := TEXT) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_override(&"font", font)
	node.add_theme_font_size_override(&"font_size", font_size)
	node.add_theme_color_override(&"font_color", color)
	return node


## Big slanted menu button (or a smaller one when font_size is given), added to `parent`.
static func menu_button(parent: Control, text: String, action: Callable, font_size := 0) -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size.y = 64 if font_size == 0 else 52
	if font_size > 0:
		button.add_theme_font_size_override(&"font_size", font_size)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


## Navy wash fading out from the left edge, so a menu column always reads over busy 3D.
static func add_left_wash(parent: Control, reach := 0.7) -> void:
	var wash := TextureRect.new()
	var gradient := GradientTexture2D.new()
	gradient.gradient = Gradient.new()
	gradient.gradient.set_color(0, Color(NAVY, 0.92))
	gradient.gradient.set_color(1, Color(NAVY, 0.0))
	gradient.fill_to = Vector2(1, 0)
	wash.texture = gradient
	wash.stretch_mode = TextureRect.STRETCH_SCALE
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	wash.anchor_right = reach
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(wash)


static func get_theme() -> Theme:
	if _theme:
		return _theme
	var theme := Theme.new()
	theme.default_font = BODY_FONT
	theme.default_font_size = 28

	theme.set_color(&"font_color", &"Label", TEXT)
	theme.set_color(&"font_outline_color", &"Label", Color(0, 0, 0, 0.6))

	# Big menu buttons.
	theme.set_font(&"font", &"Button", heading_font())
	theme.set_font_size(&"font_size", &"Button", 40)
	for state in [&"font_color", &"font_disabled_color"]:
		theme.set_color(state, &"Button", TEXT)
	for state in [&"font_hover_color", &"font_pressed_color", &"font_focus_color", &"font_hover_pressed_color"]:
		theme.set_color(state, &"Button", NAVY)
	theme.set_stylebox(&"normal", &"Button", _box(Color(1, 1, 1, 0.07), 0, Color.TRANSPARENT))
	theme.set_stylebox(&"hover", &"Button", _box(ACCENT, 0, Color.TRANSPARENT))
	theme.set_stylebox(&"focus", &"Button", _box(ACCENT, 0, Color.TRANSPARENT))
	theme.set_stylebox(&"pressed", &"Button", _box(ACCENT_BRIGHT, 0, Color.TRANSPARENT))
	theme.set_stylebox(&"hover_pressed", &"Button", _box(ACCENT_BRIGHT, 0, Color.TRANSPARENT))
	theme.set_stylebox(&"disabled", &"Button", _box(Color(1, 1, 1, 0.03), 0, Color.TRANSPARENT))

	# Toggles in settings.
	theme.set_font(&"font", &"CheckButton", BODY_BOLD_FONT)
	theme.set_font_size(&"font_size", &"CheckButton", 28)
	var clear := StyleBoxEmpty.new()
	for state in [&"normal", &"hover", &"pressed", &"hover_pressed", &"focus"]:
		theme.set_stylebox(state, &"CheckButton", clear)

	# Sliders: thick track, accent fill.
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.14)
	track.content_margin_top = 5
	track.content_margin_bottom = 5
	track.skew = Vector2(SKEW, 0)
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = ACCENT
	theme.set_stylebox(&"slider", &"HSlider", track)
	theme.set_stylebox(&"grabber_area", &"HSlider", fill)
	theme.set_stylebox(&"grabber_area_highlight", &"HSlider", fill)
	var panel := _box(PANEL, 2, PANEL_EDGE, 36)
	panel.skew = Vector2(SKEW * 0.2, 0)  # Large panels read better with only a hint of slant.
	theme.set_stylebox(&"panel", &"PanelContainer", panel)

	_theme = theme
	return theme


static func _box(color: Color, border: int, border_color: Color, margin: int = 0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.skew = Vector2(SKEW * 0.5, 0)
	box.border_color = border_color
	box.set_border_width_all(border)
	if border > 0:
		box.border_width_left = 6  # Thick leading edge, a signature of the style.
	if margin > 0:
		box.set_content_margin_all(margin)
	else:
		box.content_margin_left = 34
		box.content_margin_right = 34
		box.content_margin_top = 6
		box.content_margin_bottom = 6
	return box
