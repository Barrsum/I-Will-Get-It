extends SpeedLevel
## Level 3 — Whirlwind Woods. A high-speed run over grassy platforms floating above a deep
## forest: boost pads, two loops, a boosted ramp jump, a coin gate and a spring up to a high ridge.
## Course runs toward -Z; the forest floor sits far below (falling = respawn at checkpoint).

const FOREST_FLOOR := -22.0

var _rng := RandomNumberGenerator.new()


func build_course() -> void:
	_rng.seed = 31
	spawn_point = Vector3(0, 0.1, 6.0)
	rank_times = Vector3(35.0, 50.0, 70.0)
	_environment()

	# A — start straight into loop 1.
	_platform(Vector3(0, 0, -24), Vector3(16, 3, 72))
	add_coin_line(Vector3(0, 1, -2), Vector3(0, 1, -14), 7)
	add_boost_pad(Vector3(0, 0, -18))
	add_coin_line(Vector3(0, 1, -22), Vector3(0, 1, -30), 5)
	add_boost_pad(Vector3(0, 0, -33))
	add_loop(Vector3(0, 0, -40), 8.0)  # Exits at x = +4, z = -54.
	add_checkpoint(Vector3(0, 0, -56))

	# B — boosted ramp jump over the first gap.
	add_boost_pad(Vector3(4, 0, -57))
	_ramp(Vector3(0, 0, -60), 12.0, 14.0, 16.0)
	add_coin_arc(Vector3(0, 5.2, -75), Vector3(0, 1.2, -88), 2.5, 7)

	# C — coin runway to the gate.
	_platform(Vector3(0, 0, -119), Vector3(16, 3, 62))
	add_checkpoint(Vector3(0, 0, -95))
	add_coin_line(Vector3(-4, 1, -95), Vector3(-4, 1, -115), 6)
	add_coin_line(Vector3(4, 1, -118), Vector3(4, 1, -136), 6)
	add_coin_line(Vector3(0, 1, -104), Vector3(0, 1, -112), 3)
	add_coin_gate(Vector3(0, 0, -140), 25, 16.0)

	# D — spring up to the high ridge, loop 2.
	add_spring(Vector3(0, 0, -146), 27.0, 12.0)
	_platform(Vector3(0, 10, -196), Vector3(14, 3, 78))
	add_checkpoint(Vector3(0, 10, -163), 14.0)
	add_coin_line(Vector3(0, 11, -162), Vector3(0, 11, -172), 5)
	add_boost_pad(Vector3(0, 10, -175))
	add_loop(Vector3(0, 10, -183), 7.0, -4.0)  # Exit lane on the left.
	add_boost_pad(Vector3(-4, 10, -205))
	add_coin_line(Vector3(-4, 11, -210), Vector3(-4, 11, -228), 7)

	# E — drop to the finish.
	_platform(Vector3(0, 0, -270), Vector3(20, 3, 60))
	add_coin_line(Vector3(0, 1, -246), Vector3(0, 1, -266), 6)
	add_finish(Vector3(0, 0, -285), 18.0)

	_forest()


# --- Geometry -------------------------------------------------------------------------------------

## Grass-topped earth block; `top_center` is the middle of the walkable top face.
func _platform(top_center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Hero.LAYER_WORLD
	body.position = top_center - Vector3(0, size.y * 0.5, 0)
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = size
	body.add_child(shape)
	body.add_child(PlatformerArt.box(size, PlatformerArt.tile_material(&"dirt")))
	var grass := PlatformerArt.box(Vector3(size.x + 0.2, 0.4, size.z + 0.2), PlatformerArt.tile_material(&"grass"))
	grass.position.y = size.y * 0.5 - 0.15
	body.add_child(grass)
	# Speed lane: a light path down the middle.
	var lane := PlatformerArt.box(Vector3(4.0, 0.05, size.z - 1.0), PlatformerArt.flat(Color(0.95, 0.85, 0.6), 0.8))
	lane.position.y = size.y * 0.5 + 0.06
	body.add_child(lane)
	add_child(body)


## Kicker ramp starting at `base` (front-bottom edge centre), rising toward -Z.
func _ramp(base: Vector3, width: float, length: float, angle_deg: float) -> void:
	var angle := deg_to_rad(angle_deg)
	var along := Vector3(0, sin(angle), -cos(angle))
	var normal := Vector3(0, cos(angle), sin(angle))
	var thickness := 1.0
	var body := StaticBody3D.new()
	body.collision_layer = Hero.LAYER_WORLD
	body.position = base + along * length * 0.5 - normal * thickness * 0.5
	body.rotation.x = angle
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(width, thickness, length)
	body.add_child(shape)
	body.add_child(PlatformerArt.box(Vector3(width, thickness, length), PlatformerArt.flat(Color(0.95, 0.55, 0.2), 0.5)))
	add_child(body)
	# Support block under the ramp so it doesn't float.
	var rise := length * sin(angle)
	var support := PlatformerArt.box(Vector3(width, rise + 3.0, 2.0), PlatformerArt.tile_material(&"dirt"))
	support.position = base + Vector3(0, (rise - 3.0) * 0.5, -length * cos(angle) + 1.0)
	add_child(support)


func _environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.2, 0.5, 0.95)
	sky_material.sky_horizon_color = Color(0.7, 0.86, 1.0)
	sky_material.ground_horizon_color = Color(0.7, 0.86, 1.0)
	sky_material.ground_bottom_color = Color(0.2, 0.35, 0.2)
	var sky := Sky.new()
	sky.sky_material = sky_material
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.1
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	env.ssao_enabled = true
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.fog_enabled = true
	env.fog_light_color = Color(0.7, 0.85, 1.0)
	env.fog_density = 0.004
	env.fog_sky_affect = 0.0
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	add_child(sun)
	sun.basis = Basis.looking_at(Vector3(0.4, -0.75, -0.5).normalized())


## Deep forest below and around the course.
func _forest() -> void:
	var floor_mesh := PlatformerArt.box(Vector3(700, 1, 800), PlatformerArt.flat(Color(0.18, 0.36, 0.16), 0.95))
	floor_mesh.position = Vector3(0, FOREST_FLOOR, -140)
	add_child(floor_mesh)
	var trunk_mat := PlatformerArt.flat(Color(0.42, 0.28, 0.17), 0.9)
	var leaf_mats: Array[Material] = [
		PlatformerArt.flat(Color(0.2, 0.55, 0.22), 0.85), PlatformerArt.flat(Color(0.28, 0.65, 0.25), 0.85),
		PlatformerArt.flat(Color(0.16, 0.45, 0.2), 0.85),
	]
	for i in 170:
		var x := _rng.randf_range(-70.0, 70.0)
		var z := _rng.randf_range(40.0, -330.0)
		if absf(x) < 12.0:
			x = signf(x + 0.01) * _rng.randf_range(12.0, 20.0)  # Keep the course lane clear.
		var top := _rng.randf_range(-4.0, 14.0)
		var tree := Node3D.new()
		tree.position = Vector3(x, FOREST_FLOOR, z)
		var trunk_height := top - FOREST_FLOOR
		var trunk := PlatformerArt.cylinder(_rng.randf_range(0.5, 0.9), trunk_height, trunk_mat, 10)
		trunk.position.y = trunk_height * 0.5
		tree.add_child(trunk)
		var crown_size := _rng.randf_range(3.5, 6.0)
		for c in 3:
			var crown := PlatformerArt.sphere(crown_size * (1.0 - c * 0.22), leaf_mats[_rng.randi() % leaf_mats.size()])
			crown.position = Vector3(_rng.randf_range(-1, 1), trunk_height + c * crown_size * 0.6, _rng.randf_range(-1, 1))
			tree.add_child(crown)
		add_child(tree)
	# Distant mountains.
	for i in 12:
		var mountain := PlatformerArt.sphere(_rng.randf_range(50, 90), PlatformerArt.flat(Color(0.45, 0.6, 0.62), 0.95), Vector3(1.3, 0.8, 1.0))
		mountain.position = Vector3(_rng.randf_range(-350, 350), FOREST_FLOOR - 10.0, _rng.randf_range(-450, -600) if i < 8 else _rng.randf_range(-300, 100))
		if i >= 8:
			mountain.position.x = 300.0 * (1.0 if i % 2 == 0 else -1.0)
		add_child(mountain)
