class_name PlatformerLevel
extends Node3D
## Base for classic side-scrolling platformer levels (2.5D).
## A level subclass only supplies `get_map()` — an ASCII grid, one character per cell,
## top row first — and this class builds geometry, pickups, enemies and the backdrop,
## spawns the hero in side-scroll mode and runs the rules (power-up, damage, death,
## checkpoints, coins, timer, goal).
##
## Map legend:
##   #  ground (grass on top)      H  hard block           B  brick
##   ?  coin block                 M  mushroom block       o  coin
##   g  Grumble enemy              P  pipe top-left (2 wide; fill the rest of the pipe with p)
##   K  checkpoint                 S  hero spawn           F  goal flagpole
##   .  empty

const HERO_SCENE: PackedScene = preload("res://scenes/characters/hero/hero.tscn")
const NORMAL_SIZE := 1.0
const SUPER_SIZE := 1.3
const KILL_HEIGHT := -6.0
const INVULNERABLE_TIME := 2.0
const GROUND_BACK := -6.0  ## Ground slabs extend this far back (Z) for depth.
const EARTH_DEPTH := 14.0  ## Extra (visual-only) depth under ground rows.

@export var level_title := "LEVEL"
@export var boast := ""

var hero: Hero
var coins := 0
var hud: PlatformerHUD
var map_width_cells := 0

var _cell := PlatformerArt.CELL
var _spawn := Vector3.ZERO
var _checkpoints: Array[Checkpoint] = []
var _dying := false
var _complete := false
var _invulnerable := 0.0
var _pending_grow := false


## Override: the level layout. All rows should be the same length.
func get_map() -> PackedStringArray:
	return PackedStringArray()


func _ready() -> void:
	_build_environment()
	_build_from_map(get_map())
	_build_backdrop()
	_spawn_hero()
	hud = PlatformerHUD.new()
	add_child(hud)
	hud.setup(self)
	add_child(PauseMenu.new())
	if Game.checkpoint_index < 0 and Game.deaths == 0:
		hud.show_intro(level_title, boast)


func _process(delta: float) -> void:
	if _complete or _dying:
		return
	Game.elapsed += delta
	if _invulnerable > 0.0:
		_invulnerable -= delta
		hero.visual_root.visible = _invulnerable <= 0.0 or fmod(_invulnerable, 0.16) > 0.08


func _physics_process(_delta: float) -> void:
	if _dying or _complete:
		return
	if hero.global_position.y < KILL_HEIGHT:
		kill_hero(false)
	elif _pending_grow and hero.set_size_scale(SUPER_SIZE):
		_pending_grow = false
		hero.visual_root.scale = Vector3.ONE * NORMAL_SIZE
		create_tween().tween_property(hero.visual_root, "scale", Vector3.ONE * SUPER_SIZE, 0.45) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


# --- Rules ------------------------------------------------------------------------------------

func add_coin() -> void:
	coins += 1
	hud.set_coins(coins)


func collect_mushroom(mushroom: PowerMushroom) -> void:
	mushroom.queue_free()
	if hero.size_scale < SUPER_SIZE and not _pending_grow:
		_pending_grow = true
		hud.toast("SUPER SIZE!")
	else:
		add_coin()


func hero_touched_enemy(enemy: Grumble) -> void:
	if _dying or _complete or enemy.is_dead():
		return
	var falling_onto := hero.velocity.y < 1.0 and hero.global_position.y > enemy.global_position.y + Grumble.HEIGHT * 0.45
	if falling_onto:
		enemy.stomp()
		hero.velocity.y = hero.jump_velocity * (0.8 if hero.is_jump_held() else 0.5)
		hero.skin.play_jump()
	else:
		damage_hero()


func damage_hero() -> void:
	if _dying or _complete or _invulnerable > 0.0:
		return
	if hero.size_scale > NORMAL_SIZE + 0.01:
		hero.set_size_scale(NORMAL_SIZE)
		_pending_grow = false
		_invulnerable = INVULNERABLE_TIME
		hero.skin.play_hit()
		hud.toast("OUCH!")
	else:
		kill_hero(true)


func kill_hero(play_animation: bool) -> void:
	if _dying:
		return
	_dying = true
	Game.deaths += 1
	hero.set_frozen(true)
	hero.visual_root.visible = true
	if play_animation:
		hero.skin.play_death()
	await get_tree().create_timer(1.4 if play_animation else 0.5).timeout
	Game.reload_level()


func reach_checkpoint(checkpoint: Checkpoint) -> void:
	var index := _checkpoints.find(checkpoint)
	if index > Game.checkpoint_index:
		Game.checkpoint_index = index
		checkpoint.activate()
		hud.toast("CHECKPOINT!")


func reach_goal(flagpole: Flagpole) -> void:
	if _complete or _dying:
		return
	_complete = true
	hero.set_frozen(true)
	hero.visual_root.visible = true
	var ground_y := flagpole.global_position.y
	var slide_time := clampf((hero.global_position.y - ground_y) / 9.0, 0.3, 1.2)
	hero.skin.play_fall()
	flagpole.lower_flag(slide_time)
	var tween := create_tween()
	tween.tween_property(hero, "global_position",
		Vector3(flagpole.global_position.x - 0.5, ground_y, 0.0), slide_time).set_trans(Tween.TRANS_QUAD)
	await tween.finished
	hero.visual_root.rotation.y = 0.0  # Turn to face the camera.
	hero.skin.play_emote()
	hud.show_level_results(coins, Game.elapsed, Game.deaths)


## Bumping a block from below knocks out any enemy standing on it.
func knock_out_enemies_on(block: Node3D) -> void:
	var top := block.global_position.y + _cell * 0.5
	for node in get_tree().get_nodes_in_group(&"grumble"):
		var enemy := node as Grumble
		if absf(enemy.global_position.x - block.global_position.x) < _cell * 0.9 \
				and absf(enemy.global_position.y - top) < 0.4:
			enemy.knock_out()


func spawn_block_coin(where: Vector3) -> void:
	var coin := Coin.new()
	coin.level = self
	coin.popup = true
	coin.position = where
	add_child(coin)
	add_coin()


func spawn_mushroom(block_center: Vector3) -> void:
	var mushroom := PowerMushroom.new()
	mushroom.level = self
	mushroom.position = block_center + Vector3.DOWN * _cell * 0.5
	mushroom.direction = 1.0
	add_child(mushroom)


func spawn_debris(where: Vector3, material: Material) -> void:
	for i in 4:
		var chunk := PlatformerArt.box(Vector3.ONE * _cell * 0.45, material)
		chunk.position = where + Vector3((i % 2 - 0.5) * 0.6, (i / 2 - 0.5) * 0.6, 0.4)
		add_child(chunk)
		var side := -1.0 if i % 2 == 0 else 1.0
		var peak := chunk.position + Vector3(side * 1.2, 2.5 + (i / 2) * 1.2, 0)
		var tween := chunk.create_tween().set_parallel()
		tween.tween_property(chunk, "position:x", chunk.position.x + side * 3.0, 0.9)
		tween.tween_property(chunk, "position:y", peak.y, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(chunk, "position:y", where.y - 12.0, 0.6).set_delay(0.3).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(chunk, "rotation", Vector3(randf() * 6, randf() * 6, randf() * 6), 0.9)
		tween.chain().tween_callback(chunk.queue_free)


# --- Building -----------------------------------------------------------------------------------

func _cell_origin(x: int, y: int) -> Vector3:
	return Vector3(x * _cell, y * _cell, 0.0)


func _cell_center(x: int, y: int) -> Vector3:
	return _cell_origin(x, y) + Vector3(0.5, 0.5, 0.0) * _cell


func _build_from_map(rows: PackedStringArray) -> void:
	var height := rows.size()
	map_width_cells = 0
	for row in rows:
		map_width_cells = maxi(map_width_cells, row.length())
	var char_at := func(x: int, y: int) -> String:
		var r := height - 1 - y
		if r < 0 or r >= height or x < 0 or x >= rows[r].length():
			return "."
		return rows[r][x]

	for y in height:
		var x := 0
		while x < map_width_cells:
			var c: String = char_at.call(x, y)
			match c:
				"#", "H":
					# Merge horizontal runs of the same solid (split ground runs by grass/no grass).
					var top: bool = c == "#" and char_at.call(x, y + 1) != "#"
					var end := x
					while end + 1 < map_width_cells and char_at.call(end + 1, y) == c \
							and (c != "#" or (char_at.call(end + 1, y + 1) != "#") == top):
						end += 1
					_solid_run(x, end, y, c == "#", top)
					x = end
				"B":
					_bump_block(x, y, BumpBlock.Kind.BRICK)
				"?":
					_bump_block(x, y, BumpBlock.Kind.COIN)
				"M":
					_bump_block(x, y, BumpBlock.Kind.MUSHROOM)
				"o":
					var coin := Coin.new()
					coin.level = self
					coin.position = _cell_center(x, y)
					add_child(coin)
				"g":
					var enemy := Grumble.new()
					enemy.level = self
					enemy.position = _cell_origin(x, y) + Vector3(_cell * 0.5, 0.02, 0)
					add_child(enemy)
				"P":
					var pipe_height := 0
					while char_at.call(x, y - pipe_height) in ["P", "p"]:
						pipe_height += 1
					_pipe(x, y - pipe_height + 1, pipe_height)
				"K":
					var checkpoint := Checkpoint.new()
					checkpoint.level = self
					checkpoint.position = _cell_origin(x, y) + Vector3(_cell * 0.5, 0, 0)
					add_child(checkpoint)
					_checkpoints.append(checkpoint)
				"S":
					_spawn = _cell_origin(x, y) + Vector3(_cell * 0.5, 0.05, 0)
				"F":
					var flag := Flagpole.new()
					flag.level = self
					flag.position = _cell_origin(x, y) + Vector3(_cell * 0.5, 0, 0)
					add_child(flag)
			x += 1

	# Checkpoints are ordered left to right regardless of map scan order.
	_checkpoints.sort_custom(func(a: Checkpoint, b: Checkpoint) -> bool: return a.position.x < b.position.x)
	for i in _checkpoints.size():
		if i <= Game.checkpoint_index:
			_checkpoints[i].activate(true)


func _solid_run(x0: int, x1: int, y: int, is_ground: bool, grass_top: bool) -> void:
	var width := (x1 - x0 + 1) * _cell
	var body := StaticBody3D.new()
	body.collision_layer = Hero.LAYER_WORLD
	body.collision_mask = 0
	var depth := (_cell * 0.5 - GROUND_BACK) if is_ground else _cell
	var center_z := (_cell * 0.5 + GROUND_BACK) * 0.5 if is_ground else 0.0
	body.position = Vector3(x0 * _cell + width * 0.5, (y + 0.5) * _cell, center_z)
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(width, _cell, depth)
	body.add_child(shape)
	if is_ground:
		# Visual earth extends well below the collision so the land has mass and pits read as chasms.
		var earth := PlatformerArt.box(Vector3(width, _cell + EARTH_DEPTH, depth), PlatformerArt.tile_material(&"dirt"))
		earth.position.y = -EARTH_DEPTH * 0.5
		body.add_child(earth)
	else:
		body.add_child(PlatformerArt.box(Vector3(width, _cell, depth), PlatformerArt.tile_material(&"hard")))
	if grass_top:
		var grass := PlatformerArt.box(Vector3(width + 0.1, 0.35, depth + 0.1), PlatformerArt.tile_material(&"grass"))
		grass.position.y = _cell * 0.5 - 0.1
		body.add_child(grass)
	add_child(body)


func _bump_block(x: int, y: int, kind: BumpBlock.Kind) -> void:
	var block := BumpBlock.new()
	block.kind = kind
	block.level = self
	block.position = _cell_center(x, y)
	add_child(block)


## Pipe occupying cells x..x+1, rows bottom_y..bottom_y+height-1.
func _pipe(x: int, bottom_y: int, height: int) -> void:
	var total := height * _cell
	var body := StaticBody3D.new()
	body.collision_layer = Hero.LAYER_WORLD
	body.collision_mask = 0
	body.position = _cell_origin(x, bottom_y) + Vector3(_cell, 0, 0)
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(_cell * 2.0, total, _cell * 2.0)
	shape.position.y = total * 0.5
	body.add_child(shape)
	var green := PlatformerArt.flat(Color(0.2, 0.72, 0.3), 0.3)
	var shaft := PlatformerArt.cylinder(_cell * 0.85, total - 0.6, green)
	shaft.position.y = (total - 0.6) * 0.5
	body.add_child(shaft)
	var rim := PlatformerArt.cylinder(_cell, 0.6, PlatformerArt.flat(Color(0.25, 0.8, 0.35), 0.3))
	rim.position.y = total - 0.3
	body.add_child(rim)
	var hole := PlatformerArt.cylinder(_cell * 0.75, 0.05, PlatformerArt.flat(Color(0.03, 0.12, 0.05), 0.9))
	hole.position.y = total + 0.005
	body.add_child(hole)
	add_child(body)


func _spawn_hero() -> void:
	hero = HERO_SCENE.instantiate() as Hero
	hero.side_scroll = true
	hero.can_mantle = false
	hero.can_aim = false
	hero.jog_speed = 7.0
	hero.sprint_speed = 11.0
	hero.ground_acceleration = 45.0
	hero.ground_deceleration = 55.0
	hero.air_acceleration = 35.0
	hero.air_drag = 6.0
	hero.jump_height = 7.2
	hero.jump_time_to_peak = 0.5
	hero.jump_time_to_descent = 0.4
	hero.jump_release_gravity_multiplier = 3.0
	hero.max_fall_speed = 30.0
	hero.slide_min_entry_speed = 9.0
	var start := _spawn
	if Game.checkpoint_index >= 0 and Game.checkpoint_index < _checkpoints.size():
		start = _checkpoints[Game.checkpoint_index].position + Vector3(0, 0.05, 0)
	hero.position = start
	add_child(hero)
	hero.camera.side_distance = 17.0
	hero.camera.side_height = 3.4
	hero.camera.side_fov = 40.0
	hero.camera.side_limit_left = 10.5
	hero.camera.snap()


func _build_environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.22, 0.52, 0.98)
	sky_material.sky_horizon_color = Color(0.72, 0.87, 1.0)
	sky_material.ground_horizon_color = Color(0.72, 0.87, 1.0)
	sky_material.ground_bottom_color = Color(0.35, 0.55, 0.3)
	sky_material.sky_curve = 0.1
	var sky := Sky.new()
	sky.sky_material = sky_material
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.5
	env.ambient_light_color = Color(0.85, 0.85, 0.95)
	env.ambient_light_energy = 1.2
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	env.ssao_enabled = true
	env.ssao_intensity = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.fog_enabled = true
	env.fog_light_color = Color(0.72, 0.85, 1.0)
	env.fog_density = 0.004
	env.fog_sky_affect = 0.0
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 70.0
	add_child(sun)
	# Light from the upper left, slightly toward the camera, so block fronts are lit.
	sun.basis = Basis.looking_at(Vector3(0.45, -0.75, -0.5).normalized())


## Non-colliding scenery: distant meadow, rolling hills, bushes, clouds and an end castle.
func _build_backdrop() -> void:
	var length := map_width_cells * _cell
	var ground_top := 2 * _cell
	var meadow := PlatformerArt.box(Vector3(length + 400, 1.0, 300), PlatformerArt.flat(Color(0.33, 0.68, 0.28), 0.95))
	meadow.position = Vector3(length * 0.5, ground_top - 0.6, GROUND_BACK - 150.5)
	add_child(meadow)

	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var hill_colors := [Color(0.3, 0.66, 0.3), Color(0.38, 0.74, 0.34), Color(0.26, 0.58, 0.3)]
	var x := -30.0
	while x < length + 60.0:
		var radius := rng.randf_range(9.0, 18.0)
		var hill := PlatformerArt.sphere(radius, PlatformerArt.flat(hill_colors[rng.randi() % 3], 0.95), Vector3(1.4, 0.7, 1.0))
		hill.position = Vector3(x, ground_top - radius * 0.25, rng.randf_range(-60.0, -35.0))
		add_child(hill)
		x += rng.randf_range(18.0, 34.0)

	x = 6.0
	while x < length:
		var bush := Node3D.new()
		bush.position = Vector3(x, ground_top, GROUND_BACK + 1.5)
		for i in 3:
			var puff := PlatformerArt.sphere(rng.randf_range(0.8, 1.3), PlatformerArt.flat(Color(0.28, 0.66, 0.24), 0.9))
			puff.position = Vector3((i - 1) * 1.1, 0.3, 0)
			bush.add_child(puff)
		add_child(bush)
		x += rng.randf_range(10.0, 22.0)

	x = 0.0
	var white := PlatformerArt.flat(Color(1, 1, 1), 1.0, 0.0, 0.15)
	while x < length + 40.0:
		var cloud := Node3D.new()
		cloud.position = Vector3(x, rng.randf_range(20.0, 27.0), rng.randf_range(-45.0, -25.0))
		for i in 4:
			var puff := PlatformerArt.sphere(rng.randf_range(1.6, 2.6), white, Vector3(1.2, 0.85, 0.8))
			puff.position = Vector3((i - 1.5) * 2.2, sin(i * 1.7) * 0.6, 0)
			cloud.add_child(puff)
		add_child(cloud)
		x += rng.randf_range(20.0, 36.0)

	# Castle just past the flag.
	var castle := Node3D.new()
	castle.position = Vector3(length - 12.0, ground_top, -3.0)
	var stone := PlatformerArt.tile_material(&"hard")
	var keep := PlatformerArt.box(Vector3(9, 7.5, 5), stone)
	keep.position.y = 3.75
	castle.add_child(keep)
	for i in 5:
		var merlon := PlatformerArt.box(Vector3(1.2, 1.2, 5), stone)
		merlon.position = Vector3(-3.9 + i * 1.95, 8.1, 0)
		castle.add_child(merlon)
	var door := PlatformerArt.box(Vector3(2.2, 3.6, 0.2), PlatformerArt.flat(Color(0.1, 0.06, 0.05), 0.9))
	door.position = Vector3(0, 1.8, 2.5)
	castle.add_child(door)
	add_child(castle)
