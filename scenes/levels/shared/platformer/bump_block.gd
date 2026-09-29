class_name BumpBlock
extends StaticBody3D
## "?" blocks and bricks. Hit from below: coin/mushroom blocks give their item once and turn
## into used blocks; bricks shatter for a super-sized hero and just bounce otherwise.

enum Kind { BRICK, COIN, MUSHROOM }

var kind := Kind.BRICK
var level: PlatformerLevel

var _used := false
var _bouncing := false
var _mesh: MeshInstance3D
var _mark: Label3D


func _ready() -> void:
	collision_layer = Hero.LAYER_WORLD
	collision_mask = 0
	var size := Vector3.ONE * PlatformerArt.CELL
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = size
	add_child(shape)
	_mesh = PlatformerArt.box(size, PlatformerArt.tile_material(&"brick" if kind == Kind.BRICK else &"question"))
	add_child(_mesh)
	if kind != Kind.BRICK:
		_mark = Label3D.new()
		_mark.text = "?"
		_mark.font = UIStyle.HEADING_FONT
		_mark.font_size = 200
		_mark.pixel_size = 0.005
		_mark.outline_size = 24
		_mark.modulate = Color(1, 0.98, 0.9)
		_mark.outline_modulate = Color(0.55, 0.28, 0.02)
		_mark.position.z = size.z * 0.5 + 0.01
		_mesh.add_child(_mark)


## Called by Hero.move() when the hero's capsule touches this block.
func on_hero_contact(hero: Hero, normal: Vector3, impact_velocity: Vector3) -> void:
	if normal.y < -0.6 and impact_velocity.y > 0.5:
		bump(hero)


func bump(hero: Hero) -> void:
	if _bouncing:
		return
	level.knock_out_enemies_on(self)
	match kind:
		Kind.BRICK:
			if hero.size_scale > PlatformerLevel.NORMAL_SIZE + 0.01:
				level.spawn_debris(global_position, _mesh.material_override)
				queue_free()
				return
		Kind.COIN:
			if not _used:
				level.spawn_block_coin(global_position + Vector3.UP * PlatformerArt.CELL)
				_mark_used()
		Kind.MUSHROOM:
			if not _used:
				level.spawn_mushroom(global_position)
				_mark_used()
	_bounce()


func _mark_used() -> void:
	_used = true
	_mesh.material_override = PlatformerArt.tile_material(&"used")
	if _mark:
		_mark.queue_free()
		_mark = null


func _bounce() -> void:
	_bouncing = true
	var tween := create_tween().set_trans(Tween.TRANS_QUAD)
	tween.tween_property(_mesh, "position:y", 0.35, 0.07).set_ease(Tween.EASE_OUT)
	tween.tween_property(_mesh, "position:y", 0.0, 0.1).set_ease(Tween.EASE_IN)
	tween.finished.connect(func() -> void: _bouncing = false)
