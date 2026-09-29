extends RailShooterLevel
## Level 2 — Invasion Alley. The hero drops out of the portal into a futuristic city in the
## middle of an alien invasion, lands on top of a tank, and the Commander drives him down the
## avenue while glowing aliens drop from the sky onto rooftops, window ledges and the street.

const FACADE_SHADER: Shader = preload("res://assets/shaders/future_facade.gdshader")
const HERO_SKIN: PackedScene = preload("res://scenes/characters/hero/hero_skin.tscn")
const ROAD_HALF_WIDTH := 7.0
const FACADE_X := 11.0
const BUILDING_DEPTH := 16.0
const START_Z := 10.0
const WALLS: Array[Color] = [
	Color(0.92, 0.93, 0.95), Color(0.86, 0.88, 0.9), Color(0.93, 0.9, 0.84), Color(0.84, 0.88, 0.93),
	Color(0.78, 0.8, 0.84),
]
const ACCENTS: Array[Color] = [
	Color(0.15, 0.65, 0.8), Color(0.95, 0.55, 0.2), Color(0.3, 0.45, 0.85), Color(0.85, 0.3, 0.3),
]
const AD_WORDS: Array[String] = ["NOVA", "SKYLINE", "ORBIT", "AERO", "VEXA", "HELIX"]

var _buildings: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _commander: HeroSkin
var _tank_body: Node3D
var _smoke: Array[Node3D] = []
var _time := 0.0


# --- Story ----------------------------------------------------------------------------------------

func intro() -> void:
	var portal := Portal.new()
	portal.radius = 2.2
	add_child(portal)
	var drop_from := mount_position() + Vector3(0, 9.0, 7.0)
	portal.global_position = drop_from
	portal.rotation.x = deg_to_rad(-60.0)
	hero_on_mount = false
	hero.global_position = drop_from
	hero.skin.set_gun_mode(false)
	hero.skin.play_fall()
	hud.show_intro(level_title, boast)
	await portal.open(0.6)

	# Tumble out of the portal and land on the tank.
	var fall := create_tween()
	fall.tween_method(func(t: float) -> void:
		var flat := drop_from.lerp(mount_position(), t)
		hero.global_position = flat + Vector3.UP * sin(t * PI) * 2.0, 0.0, 1.0, 1.0)
	await fall.finished
	hero_on_mount = true
	hero.skin.set_gun_mode(true)
	_shake_tank(0.25)
	portal.close()

	await speak([
		{"speaker": "COMMANDER", "voice": &"commander", "text": "Where the hell did you come from? ...Doesn't matter."},
		{"speaker": "COMMANDER", "voice": &"commander", "text": "You're the new replacement. You're on the gun."},
		{"speaker": "COMMANDER", "voice": &"commander", "text": "Your only job is to shoot these glowing bastards. Hold on!"},
	])


func dialogue_cues() -> Array[Dictionary]:
	return [
		{"at": 0.22, "lines": [{"speaker": "COMMANDER", "voice": &"commander", "text": "They're dropping onto the buildings! Watch the ledges!"}]},
		{"at": 0.42, "lines": [{"speaker": "COMMANDER", "voice": &"commander", "text": "Flyers inbound! Track 'em!"}]},
		{"at": 0.6, "lines": [{"speaker": "COMMANDER", "voice": &"commander", "text": "Big one! Those take three hits. Keep firing!"}]},
		{"at": 0.85, "lines": [{"speaker": "COMMANDER", "voice": &"commander", "text": "Almost through the district. Don't let up!"}]},
	]


func outro() -> void:
	await speak([
		{"speaker": "COMMANDER", "voice": &"commander", "text": "...Not bad, replacement. Not bad at all."},
	])


func speak(lines: Array) -> void:
	_commander.play_clip(&"Sitting_Talking", 0.2)
	await dialogue.say(lines)
	_commander.play_clip(&"Sitting_Idle", 0.3)


func _process(delta: float) -> void:
	super(delta)
	_time += delta
	if _tank_body:
		# Engine rumble + gentle rocking while moving.
		var moving := 1.0 if driving else 0.25
		_tank_body.position.y = sin(_time * 19.0) * 0.015 * moving + sin(_time * 2.7) * 0.02 * moving
		_tank_body.rotation.x = sin(_time * 1.9) * 0.008 * moving
	for i in _smoke.size():
		# Smoke columns slowly billow.
		_smoke[i].scale = Vector3.ONE * (1.0 + sin(_time * 0.6 + i) * 0.06)
		_smoke[i].rotation.y += delta * 0.05


func _shake_tank(amount: float) -> void:
	var tween := create_tween()
	tween.tween_property(_tank_body, "position:y", -amount, 0.06)
	tween.tween_property(_tank_body, "position:y", 0.0, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


# --- Targets --------------------------------------------------------------------------------------

func build_targets() -> Array[Dictionary]:
	_rng.seed = 404
	var targets: Array[Dictionary] = []
	var z := START_Z - 26.0
	var wave := 0
	while z > START_Z - track_length + 14.0:
		var t := (START_Z - z) / track_length
		var count := 1 if wave < 3 else _rng.randi_range(1, 2 if t < 0.4 else 3)
		for i in count:
			var spot := _pick_spot(z - _rng.randf_range(0.0, 6.0), t, wave)
			if spot.is_empty():
				continue
			spot.lifetime = lerpf(5.0, 3.0, t) + (1.5 if spot.kind == AlienTarget.Kind.BRUTE else 0.0)
			spot.trigger_z = z + _rng.randf_range(38.0, 46.0)
			targets.append(spot)
		wave += 1
		z -= _rng.randf_range(8.0, 12.0)
	return targets


func _pick_spot(z: float, t: float, wave: int) -> Dictionary:
	var face := Vector3(0, 2.0, z + 22.0)
	var roll := _rng.randf()
	# Flyers from 40% in, brutes from 60% in (the Commander warns about each).
	if t > 0.42 and roll < 0.22:
		return {"position": Vector3(_rng.randf_range(-5.0, 5.0), _rng.randf_range(5.0, 8.5), z), "face": face,
			"kind": AlienTarget.Kind.FLYER, "sway": 2.2}
	if t > 0.6 and roll > 0.88:
		return {"position": Vector3(_rng.randf_range(-4.0, 4.0), 0.0, z), "face": face, "kind": AlienTarget.Kind.BRUTE}
	if wave < 3 or roll < 0.4:
		return {"position": Vector3(_rng.randf_range(-5.5, 5.5), 0.0, z), "face": face, "kind": AlienTarget.Kind.GRUNT}
	var side := -1.0 if _rng.randf() < 0.5 else 1.0
	var building := _building_at(side, z)
	if building.is_empty():
		return {}
	if t < 0.22 or roll < 0.72:
		# On a balcony ledge.
		var ledges: Array = building.ledges
		var y: float = ledges[_rng.randi() % ledges.size()]
		return {"position": Vector3(side * (FACADE_X - 0.9), y, z), "face": face, "kind": AlienTarget.Kind.GRUNT}
	return {"position": Vector3(side * (FACADE_X + 1.0), building.height, z), "face": face, "kind": AlienTarget.Kind.GRUNT}


func _building_at(side: float, z: float) -> Dictionary:
	for building in _buildings:
		if building.side == side and z <= building.z_front - 1.0 and z >= building.z_back + 1.0:
			return building
	return {}


# --- Tank ----------------------------------------------------------------------------------------

func build_vehicle() -> Node3D:
	var root := Node3D.new()
	root.position = Vector3(0, 0, START_Z)
	_tank_body = Node3D.new()
	root.add_child(_tank_body)
	var paint := PlatformerArt.flat(Color(0.52, 0.55, 0.42), 0.7, 0.2)
	var paint_dark := PlatformerArt.flat(Color(0.36, 0.38, 0.3), 0.7, 0.2)
	var track_mat := PlatformerArt.flat(Color(0.12, 0.12, 0.13), 0.8, 0.3)

	var hull := PlatformerArt.box(Vector3(2.8, 0.9, 6.6), paint)
	hull.position.y = 1.15
	_tank_body.add_child(hull)
	var glacis := PlatformerArt.box(Vector3(2.8, 0.7, 1.4), paint)
	glacis.position = Vector3(0, 1.25, -3.5)
	glacis.rotation.x = -0.55
	_tank_body.add_child(glacis)
	for side in [-1.0, 1.0]:
		var track := PlatformerArt.box(Vector3(0.8, 1.0, 7.0), track_mat)
		track.position = Vector3(side * 1.75, 0.55, 0)
		_tank_body.add_child(track)
		var skirt := PlatformerArt.box(Vector3(0.1, 0.55, 6.8), paint_dark)
		skirt.position = Vector3(side * 2.2, 1.0, 0)
		_tank_body.add_child(skirt)
		for i in 6:
			var wheel := PlatformerArt.cylinder(0.36, 0.3, paint_dark, 14)
			wheel.rotation.z = PI * 0.5
			wheel.position = Vector3(side * 2.17, 0.45, -2.6 + i * 1.04)
			_tank_body.add_child(wheel)
	# Turret the hero rides on.
	var turret := PlatformerArt.box(Vector3(2.3, 0.75, 2.6), paint)
	turret.position = Vector3(0, 1.98, 0.9)
	_tank_body.add_child(turret)
	var cannon := PlatformerArt.cylinder(0.14, 3.2, paint_dark, 12)
	cannon.rotation.x = PI * 0.5
	cannon.position = Vector3(0.75, 2.0, -1.8)
	_tank_body.add_child(cannon)
	var hatch := PlatformerArt.cylinder(0.7, 0.12, paint_dark, 24)
	hatch.position = Vector3(0, 2.4, 1.0)
	_tank_body.add_child(hatch)
	# Driver's hatch up front.
	var driver_ring := PlatformerArt.cylinder(0.5, 0.14, paint_dark, 20)
	driver_ring.position = Vector3(-0.7, 1.66, -2.05)
	_tank_body.add_child(driver_ring)
	for x in [-0.9, 0.9]:
		var lamp := PlatformerArt.sphere(0.12, PlatformerArt.flat(Color(1.0, 0.95, 0.8), 0.2, 0.0, 2.0))
		lamp.position = Vector3(x, 1.5, -3.95)
		_tank_body.add_child(lamp)

	var mount := Marker3D.new()
	mount.name = "Mount"
	mount.position = Vector3(0, 2.46, 1.0)
	_tank_body.add_child(mount)
	var pivot := Marker3D.new()
	pivot.name = "GunPivot"
	root.add_child(pivot)

	# The Commander drives, head and shoulders out of the front hatch.
	_commander = HERO_SKIN.instantiate() as HeroSkin
	_commander.position = Vector3(-0.7, 0.95, -1.9)
	_commander.rotation.y = PI
	_tank_body.add_child(_commander)
	_commander.set_tint(Color(0.36, 0.42, 0.3))
	_commander.play_clip(&"Sitting_Idle", 0.0)
	var head := _commander.attach_to_bone(&"Head")
	var helmet := PlatformerArt.sphere(0.17, PlatformerArt.flat(Color(0.3, 0.34, 0.26), 0.6, 0.1), Vector3(1.1, 0.95, 1.15))
	helmet.position = Vector3(0, 0.12, 0)
	head.add_child(helmet)
	var visor := PlatformerArt.box(Vector3(0.26, 0.06, 0.06), PlatformerArt.flat(Color(0.2, 0.22, 0.25), 0.1, 0.6))
	visor.position = Vector3(0, 0.08, 0.14)
	head.add_child(visor)
	return root


# --- Scenery -------------------------------------------------------------------------------------

func build_set() -> void:
	_rng.seed = 2077
	_environment()
	var street_end := START_Z - track_length - 70.0
	_street(START_Z + 30.0, street_end)
	for side in [-1.0, 1.0]:
		_building_row(side, START_Z + 30.0, street_end)
	_street_furniture(START_Z + 20.0, street_end)
	_mothership()


func _environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.38, 0.55, 0.78)
	sky_material.sky_horizon_color = Color(0.9, 0.8, 0.68)
	sky_material.ground_horizon_color = Color(0.9, 0.8, 0.68)
	sky_material.ground_bottom_color = Color(0.45, 0.46, 0.48)
	sky_material.sun_angle_max = 25.0
	var sky := Sky.new()
	sky.sky_material = sky_material
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	env.ssao_enabled = true
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.fog_enabled = true
	env.fog_light_color = Color(0.88, 0.8, 0.7)
	env.fog_density = 0.0045
	env.fog_sky_affect = 0.2
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.93, 0.82)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 110.0
	add_child(sun)
	sun.basis = Basis.looking_at(Vector3(0.45, -0.72, -0.5).normalized())


func _street(z_start: float, z_end: float) -> void:
	var length := z_start - z_end
	var center_z := (z_start + z_end) * 0.5
	var road := StaticBody3D.new()
	road.collision_layer = Hero.LAYER_WORLD
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(FACADE_X * 2.0, 1.0, length)
	road.add_child(shape)
	road.add_child(PlatformerArt.box(Vector3(ROAD_HALF_WIDTH * 2.0, 1.0, length), PlatformerArt.flat(Color(0.36, 0.37, 0.4), 0.85)))
	road.position = Vector3(0, -0.5, center_z)
	add_child(road)
	var paint := PlatformerArt.flat(Color(0.95, 0.95, 0.92), 0.6)
	var z := z_start
	while z > z_end:
		for x in [-2.4, 2.4]:
			var dash := PlatformerArt.box(Vector3(0.16, 0.02, 3.0), paint)
			dash.position = Vector3(x, 0.01, z)
			add_child(dash)
		z -= 7.0
	for side in [-1.0, 1.0]:
		var walk := PlatformerArt.box(Vector3(FACADE_X - ROAD_HALF_WIDTH, 0.25, length), PlatformerArt.flat(Color(0.74, 0.74, 0.76), 0.8))
		walk.position = Vector3(side * (ROAD_HALF_WIDTH + (FACADE_X - ROAD_HALF_WIDTH) * 0.5), 0.12, center_z)
		add_child(walk)
		var kerb := PlatformerArt.box(Vector3(0.3, 0.28, length), PlatformerArt.flat(Color(0.88, 0.88, 0.88), 0.7))
		kerb.position = Vector3(side * ROAD_HALF_WIDTH, 0.14, center_z)
		add_child(kerb)


func _building_row(side: float, z_start: float, z_end: float) -> void:
	var z := z_start
	var index := 0
	while z > z_end:
		var width := _rng.randf_range(10.0, 17.0)
		var height := _rng.randf_range(24.0, 60.0)
		var accent: Color = ACCENTS[_rng.randi() % ACCENTS.size()]
		var wall: Color = WALLS[_rng.randi() % WALLS.size()]
		var body := StaticBody3D.new()
		body.collision_layer = Hero.LAYER_WORLD
		body.position = Vector3(side * (FACADE_X + BUILDING_DEPTH * 0.5), height * 0.5, z - width * 0.5)
		var shape := CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		(shape.shape as BoxShape3D).size = Vector3(BUILDING_DEPTH, height, width - 0.6)
		body.add_child(shape)
		var material := ShaderMaterial.new()
		material.shader = FACADE_SHADER
		material.set_shader_parameter(&"wall_color", wall)
		material.set_shader_parameter(&"accent_color", accent)
		material.set_shader_parameter(&"accent_every", float(_rng.randi_range(3, 6)))
		material.set_shader_parameter(&"seed", float(index) + side * 50.0)
		body.add_child(PlatformerArt.box(Vector3(BUILDING_DEPTH, height, width - 0.6), material))
		# Stepped crown on top.
		var crown := PlatformerArt.box(Vector3(BUILDING_DEPTH * 0.6, 3.0, (width - 0.6) * 0.6), PlatformerArt.flat(wall.darkened(0.1), 0.5, 0.2))
		crown.position.y = height * 0.5 + 1.5
		body.add_child(crown)
		add_child(body)

		# Balcony ledges on the street side: where aliens land.
		var ledges: Array[float] = []
		var ledge_mat := PlatformerArt.flat(wall.darkened(0.15), 0.5, 0.2)
		var y := 7.0 + _rng.randf_range(0.0, 3.4)
		while y < height - 6.0 and ledges.size() < 4:
			var ledge := PlatformerArt.box(Vector3(1.8, 0.35, width * 0.5), ledge_mat)
			ledge.position = Vector3(side * (FACADE_X - 0.9), y - 0.17, z - width * 0.5)
			add_child(ledge)
			var rail := PlatformerArt.box(Vector3(0.06, 0.9, width * 0.5), PlatformerArt.flat(Color(0.8, 0.85, 0.9), 0.2, 0.6))
			rail.position = Vector3(side * (FACADE_X - 1.75), y + 0.45, z - width * 0.5)
			add_child(rail)
			ledges.append(y)
			y += _rng.randf_range(6.8, 10.2)
		if ledges.is_empty():
			ledges.append(7.0)
		if _rng.randf() < 0.45:
			_ad_board(side, z - width * 0.5, _rng.randf_range(9.0, 16.0), accent)
		if _rng.randf() < 0.3:
			_smoke_column(Vector3(side * (FACADE_X + BUILDING_DEPTH * 0.5), height, z - width * 0.5))
		_buildings.append({"side": side, "z_front": z, "z_back": z - width, "height": height, "ledges": ledges})
		z -= width
		index += 1


## Big billboard panel hung on a facade, readable from the street.
func _ad_board(side: float, z: float, y: float, color: Color) -> void:
	var board := Node3D.new()
	board.position = Vector3(side * (FACADE_X - 0.15), y, z)
	board.rotation.y = -PI * 0.5 * side
	var panel := PlatformerArt.box(Vector3(6.0, 3.2, 0.2), PlatformerArt.flat(color, 0.5))
	board.add_child(panel)
	var text := Label3D.new()
	text.text = AD_WORDS[_rng.randi() % AD_WORDS.size()]
	text.font = UIStyle.heading_font()
	text.font_size = 220
	text.pixel_size = 0.01
	text.modulate = Color(1, 1, 1)
	text.outline_size = 0
	text.position.z = 0.12
	board.add_child(text)
	add_child(board)


## Dark smoke rising from a hit building: the battle is happening all around.
func _smoke_column(base: Vector3) -> void:
	var column := Node3D.new()
	column.position = base
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.3, 0.32, 0.55)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 1.0
	for i in 7:
		var puff := PlatformerArt.sphere(2.2 + i * 0.9, material)
		puff.position = Vector3(sin(i * 1.3) * 1.5 + i * 0.8, 1.5 + i * 3.4, cos(i * 1.1) * 1.5)
		column.add_child(puff)
	var fire := PlatformerArt.sphere(1.6, PlatformerArt.flat(Color(1.0, 0.5, 0.15), 0.3, 0.0, 3.0), Vector3(1.3, 0.6, 1.3))
	fire.position.y = 0.6
	column.add_child(fire)
	add_child(column)
	_smoke.append(column)


func _street_furniture(z_start: float, z_end: float) -> void:
	var pole_mat := PlatformerArt.flat(Color(0.9, 0.9, 0.92), 0.3, 0.4)
	var lamp_mat := PlatformerArt.flat(Color(0.95, 0.97, 1.0), 0.2, 0.0, 1.0)
	var z := z_start
	while z > z_end:
		for side in [-1.0, 1.0]:
			var pole := PlatformerArt.cylinder(0.1, 7.5, pole_mat, 10)
			pole.position = Vector3(side * (ROAD_HALF_WIDTH + 1.0), 3.75, z)
			add_child(pole)
			var arm := PlatformerArt.box(Vector3(2.0, 0.1, 0.25), pole_mat)
			arm.position = Vector3(side * (ROAD_HALF_WIDTH + 0.1), 7.45, z)
			add_child(arm)
			var lamp := PlatformerArt.box(Vector3(0.9, 0.08, 0.3), lamp_mat)
			lamp.position = Vector3(side * (ROAD_HALF_WIDTH - 0.6), 7.38, z)
			add_child(lamp)
		z -= 20.0

	# Barricades and burning wrecks from the fighting.
	z = START_Z - 14.0
	while z > z_end + 40.0:
		var side := -1.0 if _rng.randf() < 0.5 else 1.0
		if _rng.randf() < 0.5:
			_wreck(Vector3(side * (ROAD_HALF_WIDTH - 1.8), 0, z))
		else:
			_barricade(Vector3(side * (ROAD_HALF_WIDTH - 1.2), 0, z))
		z -= _rng.randf_range(14.0, 24.0)


func _wreck(where: Vector3) -> void:
	var wreck := Node3D.new()
	wreck.position = where
	wreck.rotation = Vector3(0, _rng.randf_range(-0.6, 0.6), _rng.randf_range(-0.12, 0.12))
	var hull := PlatformerArt.box(Vector3(2.0, 1.0, 4.4), PlatformerArt.flat(Color(0.25, 0.25, 0.27), 0.8, 0.3))
	hull.position.y = 0.6
	wreck.add_child(hull)
	var cabin := PlatformerArt.box(Vector3(1.8, 0.6, 2.2), PlatformerArt.flat(Color(0.18, 0.18, 0.2), 0.6, 0.3))
	cabin.position = Vector3(0, 1.35, 0.3)
	wreck.add_child(cabin)
	var fire := PlatformerArt.sphere(0.5, PlatformerArt.flat(Color(1.0, 0.5, 0.15), 0.3, 0.0, 3.0), Vector3(1.2, 0.8, 1.2))
	fire.position = Vector3(0, 1.25, -1.4)
	wreck.add_child(fire)
	var smoke_mat := StandardMaterial3D.new()
	smoke_mat.albedo_color = Color(0.28, 0.28, 0.3, 0.5)
	smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for i in 4:
		var puff := PlatformerArt.sphere(0.6 + i * 0.35, smoke_mat)
		puff.position = Vector3(i * 0.3, 2.0 + i * 1.3, -1.4 - i * 0.2)
		wreck.add_child(puff)
	add_child(wreck)


func _barricade(where: Vector3) -> void:
	var barricade := Node3D.new()
	barricade.position = where
	barricade.rotation.y = _rng.randf_range(-0.3, 0.3)
	var block := PlatformerArt.box(Vector3(3.0, 1.0, 0.6), PlatformerArt.flat(Color(0.7, 0.7, 0.68), 0.9))
	block.position.y = 0.5
	barricade.add_child(block)
	var stripe := PlatformerArt.box(Vector3(3.02, 0.14, 0.62), PlatformerArt.flat(Color(0.95, 0.75, 0.1), 0.6))
	stripe.position.y = 0.75
	barricade.add_child(stripe)
	add_child(barricade)


## The alien mothership hanging over the far end of the city, with a tractor beam.
func _mothership() -> void:
	var ship := Node3D.new()
	ship.position = Vector3(0, 110, START_Z - track_length - 160.0)
	var hull := PlatformerArt.sphere(85.0, PlatformerArt.flat(Color(0.32, 0.34, 0.4), 0.4, 0.6), Vector3(1.0, 0.15, 1.0))
	ship.add_child(hull)
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 74.0
	ring_mesh.outer_radius = 77.0
	var ring := MeshInstance3D.new()
	ring.mesh = ring_mesh
	ring.material_override = PlatformerArt.flat(Color(0.35, 1.0, 0.5), 0.2, 0.0, 2.0)
	ring.position.y = -6.0
	ship.add_child(ring)
	var beam_material := StandardMaterial3D.new()
	beam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_material.albedo_color = Color(0.45, 1.0, 0.6, 0.22)
	beam_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var beam_mesh := CylinderMesh.new()
	beam_mesh.top_radius = 6.0
	beam_mesh.bottom_radius = 26.0
	beam_mesh.height = 110.0
	var beam := MeshInstance3D.new()
	beam.mesh = beam_mesh
	beam.material_override = beam_material
	beam.position.y = -63.0
	ship.add_child(beam)
	add_child(ship)
