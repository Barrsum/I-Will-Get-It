extends RailShooterLevel
## Level 2 — Railgun Alley. Walk down a sunset city street shooting pop-up targets in the
## street, in windows and on rooftops. Early waves teach, later waves add side-to-side
## bonus plates and friendly hearts you must not shoot.

const FACADE_SHADER: Shader = preload("res://assets/shaders/building_facade.gdshader")
const ROAD_HALF_WIDTH := 6.0
const FACADE_X := 9.0  ## Building fronts sit this far either side of the road centre.
const BUILDING_DEPTH := 12.0
const WALL_COLORS: Array[Color] = [
	Color(0.88, 0.52, 0.4), Color(0.95, 0.82, 0.6), Color(0.45, 0.72, 0.7), Color(0.93, 0.7, 0.35),
	Color(0.68, 0.58, 0.85), Color(0.8, 0.4, 0.45), Color(0.6, 0.78, 0.5),
]

## [{side, z_front, z_back, height}] — building fronts, used to place window/roof targets.
var _buildings: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func build_set() -> void:
	_rng.seed = 2026
	_environment()
	var street_end := -track_length - 60.0
	_street(12.0, street_end)
	for side in [-1.0, 1.0]:
		_building_row(side, 14.0, street_end)
	_lamps(10.0, street_end)
	_props()
	_finish_gate(-track_length)


func build_targets() -> Array[Dictionary]:
	_rng.seed = 7
	var targets: Array[Dictionary] = []
	var z := -14.0
	var wave := 0
	while z > -track_length + 12.0:
		var t := -z / track_length  # 0 at the start, 1 at the finish.
		var count := 1 if wave < 4 else _rng.randi_range(1, 2 if t < 0.5 else 3)
		var used_x: Array[float] = []
		for i in count:
			var spot := _pick_spot(z - _rng.randf_range(0.0, 5.0), t, wave, used_x)
			if spot.is_empty():
				continue
			spot.kind = _pick_kind(t)
			spot.lifetime = lerpf(4.6, 2.6, t)
			if spot.kind == TargetPlate.Kind.BONUS:
				spot.lifetime += 0.8
				spot.sway = 1.4 if spot.post else 0.0
			spot.trigger_z = z + _rng.randf_range(24.0, 30.0)
			targets.append(spot)
		wave += 1
		z -= _rng.randf_range(7.0, 10.0)
	return targets


func _pick_kind(t: float) -> TargetPlate.Kind:
	var roll := _rng.randf()
	if t > 0.25 and roll < 0.15:
		return TargetPlate.Kind.FRIENDLY
	if t > 0.35 and roll > 0.86:
		return TargetPlate.Kind.BONUS
	return TargetPlate.Kind.NORMAL


## A target spot at depth z: street (on a post), a window, or a rooftop.
func _pick_spot(z: float, t: float, wave: int, used_x: Array[float]) -> Dictionary:
	var roll := _rng.randf()
	if wave < 3 or roll < 0.4:
		var x := _rng.randf_range(-4.5, 4.5)
		for other in used_x:
			if absf(other - x) < 2.0:
				x = clampf(other + 2.5 * signf(x - other + 0.01), -4.5, 4.5)
		used_x.append(x)
		return {"position": Vector3(x, 0.0, z), "face": Vector3(0, 1.5, z + 18.0), "post": true}
	var side := -1.0 if _rng.randf() < 0.5 else 1.0
	var building := _building_at(side, z)
	if building.is_empty():
		return {}
	if roll < 0.78 or t < 0.3:
		var floors := int((building.height - 4.0) / 3.2)
		var level_index := _rng.randi_range(0, clampi(floors - 1, 0, 4))
		var y := 4.0 + 3.2 * level_index + 0.8
		return {"position": Vector3(side * (FACADE_X - 0.15), y, z), "face": Vector3(0, 1.5, z + 16.0), "post": false}
	return {"position": Vector3(side * (FACADE_X + 0.8), building.height, z), "face": Vector3(0, 1.5, z + 18.0), "post": true}


func _building_at(side: float, z: float) -> Dictionary:
	for building in _buildings:
		if building.side == side and z <= building.z_front and z >= building.z_back:
			return building
	return {}


# --- Scenery ------------------------------------------------------------------------------------

func _environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.2, 0.22, 0.5)
	sky_material.sky_horizon_color = Color(1.0, 0.58, 0.38)
	sky_material.ground_horizon_color = Color(1.0, 0.58, 0.38)
	sky_material.ground_bottom_color = Color(0.2, 0.15, 0.2)
	sky_material.sun_angle_max = 12.0
	var sky := Sky.new()
	sky.sky_material = sky_material
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 5.0
	env.ssao_enabled = true
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.08
	env.fog_enabled = true
	env.fog_light_color = Color(1.0, 0.62, 0.45)
	env.fog_density = 0.006
	env.fog_sky_affect = 0.3
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.72, 0.5)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)
	# Low sun at the far end of the street, raking across the facades.
	sun.basis = Basis.looking_at(Vector3(-0.35, -0.35, 0.87).normalized())


func _street(z_start: float, z_end: float) -> void:
	var length := z_start - z_end
	var center_z := (z_start + z_end) * 0.5
	var road := StaticBody3D.new()
	road.collision_layer = Hero.LAYER_WORLD
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(ROAD_HALF_WIDTH * 2.0 + 8.0, 1.0, length)
	road.add_child(shape)
	road.add_child(PlatformerArt.box(Vector3(ROAD_HALF_WIDTH * 2.0, 1.0, length), PlatformerArt.flat(Color(0.22, 0.22, 0.26), 0.9)))
	road.position = Vector3(0, -0.5, center_z)
	add_child(road)
	var paint := PlatformerArt.flat(Color(0.95, 0.85, 0.5), 0.6)
	var z := z_start
	while z > z_end:
		var dash := PlatformerArt.box(Vector3(0.18, 0.02, 2.4), paint)
		dash.position = Vector3(0, 0.01, z)
		add_child(dash)
		z -= 6.0
	for side in [-1.0, 1.0]:
		var walk := PlatformerArt.box(Vector3(FACADE_X - ROAD_HALF_WIDTH, 0.2, length), PlatformerArt.flat(Color(0.62, 0.6, 0.6), 0.85))
		walk.position = Vector3(side * (ROAD_HALF_WIDTH + (FACADE_X - ROAD_HALF_WIDTH) * 0.5), 0.1, center_z)
		add_child(walk)


func _building_row(side: float, z_start: float, z_end: float) -> void:
	var z := z_start
	var index := 0
	while z > z_end:
		var width := _rng.randf_range(7.0, 13.0)
		var height := _rng.randf_range(10.0, 26.0) if z < 0.0 else _rng.randf_range(10.0, 16.0)
		var color: Color = WALL_COLORS[_rng.randi() % WALL_COLORS.size()]
		var body := StaticBody3D.new()
		body.collision_layer = Hero.LAYER_WORLD
		body.position = Vector3(side * (FACADE_X + BUILDING_DEPTH * 0.5), height * 0.5, z - width * 0.5)
		var shape := CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		(shape.shape as BoxShape3D).size = Vector3(BUILDING_DEPTH, height, width - 0.2)
		body.add_child(shape)
		var material := ShaderMaterial.new()
		material.shader = FACADE_SHADER
		material.set_shader_parameter(&"wall_color", color)
		material.set_shader_parameter(&"seed", float(index) + side * 50.0)
		material.set_shader_parameter(&"lit_fraction", _rng.randf_range(0.2, 0.45))
		body.add_child(PlatformerArt.box(Vector3(BUILDING_DEPTH, height, width - 0.2), material))
		var cornice := PlatformerArt.box(Vector3(BUILDING_DEPTH + 0.6, 0.5, width), PlatformerArt.flat(color.darkened(0.3), 0.7))
		cornice.position.y = height * 0.5 + 0.25
		body.add_child(cornice)
		add_child(body)
		_buildings.append({"side": side, "z_front": z, "z_back": z - width, "height": height})
		z -= width
		index += 1


func _lamps(z_start: float, z_end: float) -> void:
	var pole_mat := PlatformerArt.flat(Color(0.18, 0.2, 0.24), 0.5, 0.5)
	var bulb_mat := PlatformerArt.flat(Color(1.0, 0.85, 0.55), 0.3, 0.0, 3.0)
	var z := z_start
	var count := 0
	while z > z_end:
		for side in [-1.0, 1.0]:
			var lamp := Node3D.new()
			lamp.position = Vector3(side * (ROAD_HALF_WIDTH + 0.8), 0.2, z)
			var pole := PlatformerArt.cylinder(0.08, 5.0, pole_mat, 12)
			pole.position.y = 2.5
			lamp.add_child(pole)
			var arm := PlatformerArt.box(Vector3(1.2, 0.08, 0.08), pole_mat)
			arm.position = Vector3(-side * 0.55, 4.95, 0)
			lamp.add_child(arm)
			var bulb := PlatformerArt.sphere(0.2, bulb_mat)
			bulb.position = Vector3(-side * 1.05, 4.8, 0)
			lamp.add_child(bulb)
			if count % 2 == 0:
				var light := OmniLight3D.new()
				light.light_color = Color(1.0, 0.8, 0.5)
				light.light_energy = 2.0
				light.omni_range = 9.0
				light.position = bulb.position
				lamp.add_child(light)
			add_child(lamp)
		z -= 16.0
		count += 1


## Parked cars and crates along the kerbs.
func _props() -> void:
	var z := -6.0
	while z > -track_length:
		var side := -1.0 if _rng.randf() < 0.5 else 1.0
		if _rng.randf() < 0.6:
			var car := Node3D.new()
			car.position = Vector3(side * (ROAD_HALF_WIDTH - 1.3), 0, z)
			var paint: Color = WALL_COLORS[_rng.randi() % WALL_COLORS.size()].darkened(0.1)
			var body := PlatformerArt.box(Vector3(1.8, 0.8, 4.0), PlatformerArt.flat(paint, 0.3, 0.3))
			body.position.y = 0.7
			car.add_child(body)
			var cabin := PlatformerArt.box(Vector3(1.6, 0.6, 2.2), PlatformerArt.flat(Color(0.2, 0.25, 0.35), 0.2, 0.4))
			cabin.position = Vector3(0, 1.4, -0.2)
			car.add_child(cabin)
			for wheel_z in [-1.3, 1.3]:
				for wheel_x in [-0.9, 0.9]:
					var wheel := PlatformerArt.cylinder(0.35, 0.25, PlatformerArt.flat(Color(0.08, 0.08, 0.1), 0.8), 16)
					wheel.rotation.z = PI * 0.5
					wheel.position = Vector3(wheel_x, 0.35, wheel_z)
					car.add_child(wheel)
			add_child(car)
		else:
			var crate := PlatformerArt.box(Vector3.ONE * 1.1, PlatformerArt.tile_material(&"used"))
			crate.position = Vector3(side * (ROAD_HALF_WIDTH + 1.2), 0.75, z)
			crate.rotation.y = _rng.randf_range(-0.4, 0.4)
			add_child(crate)
		z -= _rng.randf_range(9.0, 18.0)


func _finish_gate(z: float) -> void:
	var gate := Node3D.new()
	gate.position = Vector3(0, 0, z - 2.0)
	var post_mat := PlatformerArt.flat(Color(0.2, 0.22, 0.3), 0.5, 0.4)
	for side in [-1.0, 1.0]:
		var post := PlatformerArt.box(Vector3(0.6, 7.0, 0.6), post_mat)
		post.position = Vector3(side * (ROAD_HALF_WIDTH + 0.5), 3.5, 0)
		gate.add_child(post)
	var banner := PlatformerArt.box(Vector3(ROAD_HALF_WIDTH * 2.0 + 1.6, 1.6, 0.3), PlatformerArt.flat(UIStyle.ACCENT, 0.4, 0.0, 0.4))
	banner.position.y = 6.4
	gate.add_child(banner)
	var text := Label3D.new()
	text.text = "FINISH"
	text.font = UIStyle.heading_font()
	text.font_size = 220
	text.pixel_size = 0.006
	text.modulate = UIStyle.NAVY
	text.outline_size = 0
	text.position = Vector3(0, 6.4, 0.2)
	gate.add_child(text)
	add_child(gate)
