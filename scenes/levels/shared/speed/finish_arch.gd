class_name FinishArch
extends Area3D
## Finish gate: run through it to complete the level.

signal crossed

@export var width := 16.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = Hero.LAYER_HERO
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(width, 8.0, 1.0)
	shape.position.y = 4.0
	add_child(shape)
	var post_mat := PlatformerArt.flat(Color(0.95, 0.95, 0.97), 0.3, 0.3)
	for side in [-1.0, 1.0]:
		var post := PlatformerArt.box(Vector3(0.8, 8.0, 0.8), post_mat)
		post.position = Vector3(side * width * 0.5, 4.0, 0)
		add_child(post)
	var banner := PlatformerArt.box(Vector3(width + 0.8, 1.8, 0.4), PlatformerArt.flat(UIStyle.ACCENT, 0.4))
	banner.position.y = 8.4
	add_child(banner)
	var text := Label3D.new()
	text.text = "FINISH"
	text.font = UIStyle.heading_font()
	text.font_size = 240
	text.pixel_size = 0.008
	text.modulate = UIStyle.NAVY
	text.outline_size = 0
	text.position = Vector3(0, 8.4, 0.25)
	add_child(text)
	body_entered.connect(func(body: Node3D) -> void:
		if body is Hero:
			crossed.emit())
