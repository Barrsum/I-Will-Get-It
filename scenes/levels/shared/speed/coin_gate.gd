class_name CoinGate
extends StaticBody3D
## Energy barrier across the track that opens once the level's coin count reaches `required`.

signal blocked

@export var required := 30
@export var width := 14.0
@export var height := 6.0

var level: Node  ## Needs `coins`.
var is_open := false

var _field: MeshInstance3D
var _label: Label3D
var _shape: CollisionShape3D
var _warn_cooldown := 0.0


func _ready() -> void:
	collision_layer = Hero.LAYER_WORLD
	collision_mask = 0
	_shape = CollisionShape3D.new()
	_shape.shape = BoxShape3D.new()
	(_shape.shape as BoxShape3D).size = Vector3(width, height, 0.6)
	_shape.position.y = height * 0.5
	add_child(_shape)
	var frame_mat := PlatformerArt.flat(Color(0.25, 0.27, 0.32), 0.4, 0.6)
	for side in [-1.0, 1.0]:
		var post := PlatformerArt.box(Vector3(0.8, height + 1.0, 0.8), frame_mat)
		post.position = Vector3(side * (width * 0.5 + 0.4), (height + 1.0) * 0.5, 0)
		add_child(post)
	var beam := PlatformerArt.box(Vector3(width + 1.6, 0.8, 0.8), frame_mat)
	beam.position.y = height + 0.6
	add_child(beam)
	var field_mat := StandardMaterial3D.new()
	field_mat.albedo_color = Color(1.0, 0.8, 0.2, 0.35)
	field_mat.emission_enabled = true
	field_mat.emission = Color(1.0, 0.75, 0.15)
	field_mat.emission_energy_multiplier = 0.8
	field_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	field_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_field = PlatformerArt.box(Vector3(width, height, 0.1), field_mat)
	_field.position.y = height * 0.5
	add_child(_field)
	_label = Label3D.new()
	_label.font = UIStyle.heading_font()
	_label.font_size = 160
	_label.pixel_size = 0.01
	_label.outline_size = 24
	_label.outline_modulate = Color(UIStyle.NAVY, 0.9)
	_label.position = Vector3(0, height + 0.6, 0.45)
	add_child(_label)


func _process(delta: float) -> void:
	_warn_cooldown = maxf(_warn_cooldown - delta, 0.0)
	if is_open:
		return
	var coins: int = level.coins
	_label.text = "%d / %d COINS" % [mini(coins, required), required]
	if coins >= required:
		open()


func open() -> void:
	is_open = true
	_shape.set_deferred(&"disabled", true)
	_label.text = "GO!"
	var tween := create_tween()
	tween.tween_property(_field, "scale", Vector3(1, 0.01, 1), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(_field.hide)


## Called by the level when the hero bumps the closed gate.
func on_hero_contact(_hero: Hero, _normal: Vector3, _impact: Vector3) -> void:
	if not is_open and _warn_cooldown <= 0.0:
		_warn_cooldown = 1.5
		blocked.emit()
