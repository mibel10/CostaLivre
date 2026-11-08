extends Node3D

const Car = preload("res://scripts/car.gd")
const Player = preload("res://scripts/player.gd")
const Hud = preload("res://scripts/hud.gd")
const Activities = preload("res://scripts/activities.gd")
const Visuals = preload("res://scripts/visuals.gd")
const STOPS := [Vector3(-84, 0, -84), Vector3(84, 0, -84), Vector3(84, 0, 84)]
const SIGN_FONTS := [preload("res://assets/fonts/PlayfairDisplay.ttf"), preload("res://assets/fonts/Roboto.ttf"), preload("res://assets/fonts/Oswald.ttf"), preload("res://assets/fonts/Lobster.ttf")]
var player: CharacterBody3D
var active_car: CharacterBody3D
var cars: Array[CharacterBody3D] = []
var cops: Array[CharacterBody3D] = []
var camera: Camera3D
var camera_yaw := 0.0
var camera_pitch := 0.34
var mouse_idle := 0.0
var heat := 0.0
var response_delay := 0.0
var crime_grace := 0.0
var health := 100.0
var cash := 900
var activities: Node
var bust_progress := 0.0
var finished := false
var won := false
var elapsed := 0.0
var toast := "Um carro está esperando por você. Aproxime-se e aperte E."
var toast_time := 8.0
var marker: Node3D
var hud: Control
var materials := {}
var visuals = Visuals.new()
var engine_audio: AudioStreamPlayer
var rng := RandomNumberGenerator.new()
var settings: Node
var pause_menu: Control
var hud_clock := 0.0
var extra: Node
var life: Node3D
var fps_counter: CanvasLayer
var car_transition := false
var sight_timer := 0.0
var last_seen := false
var camera_check_timer := 0.0
var camera_target := Vector3.ZERO
var game_mode := "sandbox"
var cutscene: Control
var touch_controls: Control
var network: Node
var profile: Node
var station: Node3D
var vehicle_sequence := 0
const SPAWNS := [Vector3(-8,0.3,12),Vector3(76,0.3,84),Vector3(134,0.3,42),Vector3(-134,0.3,-42),Vector3(42,0.3,-134),Vector3(-42,0.3,134),Vector3(8,0.3,-84),Vector3(84,0.3,8),Vector3(-84,0.3,-8),Vector3(126,0.3,-76),Vector3(-126,0.3,76),Vector3(0,0.3,50)]
var camera_shape := SphereShape3D.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	camera_shape.radius = 0.28
	rng.seed = 185
	setup_input()
	build_environment()
	build_city()
	batch_city_geometry()
	var atmosphere := preload("res://scripts/atmosphere.gd").new()
	atmosphere.world = self
	add_child(atmosphere)
	player = Player.new()
	player.world = self
	add_child(player)
	player.position = Vector3(-5, 0.3, 12)
	var starter_beetle := spawn_car(Vector3(-4, 0.2, 5), Color("e8773e"), false, 0)
	starter_beetle.owned = true
	var street_model := 4
	for spot in [Vector3(-46, 0.2, -20), Vector3(38, 0.2, 58), Vector3(88, 0.2, -55), Vector3(-88, 0.2, 65), Vector3(4, 0.2, -102), Vector3(120, 0.2, 25)]:
		spawn_car(spot, Color.from_hsv(rng.randf(), 0.45, 0.85),false,street_model)
		street_model += 1
	for i in 5:
		var base := Vector3(-84 + (i % 3) * 42, 0.2, -84 + (i / 3) * 84)
		var car := spawn_car(base + Vector3(3, 0, 15), Color.from_hsv(i * 0.19, 0.5, 0.8))
		car.traffic = true
		car.route.assign([base + Vector3(3, 0, 3), base + Vector3(39, 0, 3), base + Vector3(39, 0, 39), base + Vector3(3, 0, 39)])
	camera = Camera3D.new()
	add_child(camera)
	camera.fov = 68
	camera.far = 650
	camera.position = Vector3(-5, 5, 20)
	marker = Node3D.new()
	add_child(marker)
	for i in 4:
		var post := box(marker, Vector3(cos(i * PI / 2) * 3, 1.7, sin(i * PI / 2) * 3), Vector3(0.12, 3.4, 0.12), Color("ffe19a"), false, true)
		post.rotation.y = i * PI / 2
	var ring := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 2.8
	mesh.outer_radius = 3.1
	ring.mesh = mesh
	ring.material_override = material(Color("ffce75"), true)
	ring.position.y = 0.14
	marker.add_child(ring)
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Hud.new()
	hud.world = self
	layer.add_child(hud)
	activities = Activities.new()
	activities.world = self
	add_child(activities)
	setup_audio()
	settings = preload("res://scripts/game_settings.gd").new()
	settings.world = self
	add_child(settings)
	profile=preload("res://scripts/player_profile.gd").new()
	profile.world=self
	add_child(profile)
	pause_menu = preload("res://scripts/pause_menu.gd").new()
	pause_menu.world = self
	layer.add_child(pause_menu)
	cutscene = preload("res://scripts/campaign_cutscene.gd").new()
	cutscene.world = self
	layer.add_child(cutscene)
	extra = preload("res://scripts/gameplay_extra.gd").new()
	extra.world = self
	add_child(extra)
	life = preload("res://scripts/city_life.gd").new()
	life.world = self
	add_child(life)
	settings.register_visuals(life)
	fps_counter = preload("res://scripts/fps_counter.gd").new()
	fps_counter.world = self
	add_child(fps_counter)
	if OS.has_feature("android"):
		var touch_layer := CanvasLayer.new()
		touch_layer.layer = 50
		add_child(touch_layer)
		var touch := preload("res://scripts/touch_controls.gd").new()
		touch_controls = touch
		touch.world = self
		touch_layer.add_child(touch)
	station=preload("res://scripts/police_station.gd").new()
	station.world=self
	add_child(station)
	network = preload("res://scripts/lan_session.gd").new()
	network.name = "LanSession"
	network.world = self
	add_child(network)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	pause_menu.show_mode_select()

func start_mode(mode: String) -> void:
	if mode == "campaign" and network != null and network.active():
		notify("Desconecte da sala para jogar a campanha.")
		return
	game_mode = mode
	if is_instance_valid(pause_menu.menu_music):
		pause_menu.menu_music.stop()
	activities.game_mode = mode
	activities.set_menu("")
	if mode == "campaign":
		activities.begin_campaign()
	else:
		activities.job = -1
		marker.visible = false
		notify("Modo jogo livre: explore a cidade, faça contratos ou crie sua própria aventura.")

func _notification(what: int) -> void:
	if not OS.has_feature("android") or activities == null or pause_menu == null:
		return
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if touch_controls != null and touch_controls.editing:
			touch_controls.finish_edit(false)
		elif cutscene != null and cutscene.active:
			cutscene.finish()
		elif activities.bank.hacking:
			var back := InputEventAction.new()
			back.action = "pause"
			back.pressed = true
			activities.bank.handle_input(back)
		elif activities.menu in ["pause","map"]:
			pause_menu.resume()
		elif activities.menu not in ["mode","campaign_complete"]:
			activities.set_menu("pause" if activities.menu == "" else "")
	if what == NOTIFICATION_APPLICATION_PAUSED and activities.menu == "" and not finished:
		activities.set_menu("pause")

func play_cutscene(title: String, subtitle: String, callback: Callable = Callable()) -> void:
	if network!=null and network.active():
		if multiplayer.is_server():
			for peer_id in network.members:
				if peer_id!=1 and not network.members[peer_id].is_empty():
					network.personal.rpc_id(peer_id,"cutscene",{"title":title,"subtitle":subtitle})
		activities.menu="cutscene"
		Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
		cutscene.play(title,subtitle,callback)
		return
	Engine.time_scale = 1
	activities.menu = "cutscene"
	get_tree().paused = true
	engine_audio.stream_paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	cutscene.play(title, subtitle, callback)

func setup_input() -> void:
	var bindings := {"forward": KEY_W, "back": KEY_S, "left": KEY_A, "right": KEY_D, "jump": KEY_SPACE, "sprint": KEY_SHIFT, "crouch": KEY_Z, "interact": KEY_E, "reset": KEY_T, "reload": KEY_R, "activity": KEY_F, "jobs": KEY_M, "map": KEY_TAB, "pause": KEY_ESCAPE, "restart": KEY_ENTER, "credits": KEY_C}
	var config := ConfigFile.new()
	config.load("user://settings.cfg")
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for old_event in InputMap.action_get_events(action):
			if old_event is InputEventKey:
				InputMap.action_erase_event(action, old_event)
		var event := InputEventKey.new()
		event.physical_keycode = config.get_value("controls", action, bindings[action])
		InputMap.action_add_event(action, event)
	for action in ["shoot", "aim"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		if OS.has_feature("android"):
			continue
		var mouse := InputEventMouseButton.new()
		mouse.button_index = MOUSE_BUTTON_LEFT if action == "shoot" else MOUSE_BUTTON_RIGHT
		InputMap.action_add_event(action, mouse)

func material(color: Color, glow := false) -> StandardMaterial3D:
	var key := color.to_html() + str(glow)
	if materials.has(key):
		return materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	if glow:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 1.4
	materials[key] = mat
	return mat

func box(parent: Node3D, at: Vector3, size: Vector3, color: Color, solid := false, glow := false) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.material_override = material(color, glow)
	if solid and size.y > 6 and maxf(size.x, size.z) > 8:
		visual.material_override = visuals.surface("concrete_wall_006", color, 0.28)
	elif size.y < 0.25 and size.x > 20 and size.z > 20:
		visual.material_override = visuals.surface("concrete_wall_006", Color("b8b7ad"), 0.6)
	elif size.y >= 1.4 and size.y <= 1.6 and minf(size.x, size.z) < 0.1:
		var glass := material(color)
		glass.metallic = 0.55
		glass.roughness = 0.18
		visual.material_override = glass
	visual.position = at
	parent.add_child(visual)
	if solid:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var collision := BoxShape3D.new()
		collision.size = size
		shape.shape = collision
		body.add_child(shape)
		visual.add_child(body)
	return visual

func build_environment() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	var sky_mat := PanoramaSkyMaterial.new()
	sky_mat.panorama = preload("res://assets/sky/coast.hdr")
	sky_mat.energy_multiplier = 0.65
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = Color("b4ced8")
	env.ambient_light_energy = 0.4
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.8
	env.fog_enabled = true
	env.fog_light_color = Color("9aafba")
	env.fog_density = 0.0015
	environment.environment = env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-32, -35, 0)
	sun.light_color = Color("fff1d9")
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 100
	add_child(sun)
	var road := box(self, Vector3(376, -0.6, 0), Vector3(1128, 1, 294), Color("4a5359"), true)
	road.material_override = visuals.surface("asphalt_02", Color("b4b7ba"), 0.24)
	road.material_override.uv1_triplanar = false
	road.material_override.uv1_world_triplanar = false
	road.material_override.uv1_scale = Vector3(180, 180, 180)
	box(self, Vector3(-190, -0.75, 0), Vector3(80, 0.5, 520), Color("d6bb87"), true)
	var water := box(self, Vector3(-400, -1.1, 0), Vector3(350, 0.2, 1100), Color("3e8c9e"))
	var water_mat := ShaderMaterial.new()
	water_mat.shader = preload("res://shaders/water.gdshader")
	water.material_override = water_mat
	for i in 28:
		box(self, Vector3(-245 - rng.randf() * 240, -0.95, rng.randf_range(-320, 320)), Vector3(rng.randf_range(15, 55), 0.03, 0.4), Color("88bbc1"))
	for x in [-186, 938]:
		box(self, Vector3(x, 0.4, 0), Vector3(1, 1.2, 290), Color("b0aa99"), true)
	for z in [-144, 144]:
		box(self, Vector3(376, 0.4, z), Vector3(1126, 1.2, 1), Color("b0aa99"), true)
	for i in 18:
		box(self, Vector3(rng.randf_range(-100, 230), 6, -190 - rng.randf() * 90), Vector3(rng.randf_range(18, 45), rng.randf_range(20, 70), 25), Color("78908d"))

func build_hills() -> void:
	for center in [378.0, 714.0]:
		for width in [70.0, 12.0]:
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			var heights := [0.0, 10.0, 10.0, 0.0]
			for segment in 3:
				var left: float = center - 84.0 + segment * 56.0
				var right := left + 56.0
				var offset := 0.02 if width < 20 else 0.0
				var a := Vector3(left, heights[segment] - 0.1 + offset, -width / 2)
				var b := Vector3(left, heights[segment] - 0.1 + offset, width / 2)
				var c := Vector3(right, heights[segment + 1] - 0.1 + offset, -width / 2)
				var d := Vector3(right, heights[segment + 1] - 0.1 + offset, width / 2)
				for vertex in [a, c, b, c, d, b]: surface.add_vertex(vertex)
			surface.generate_normals()
			var mesh := surface.commit()
			var visual := MeshInstance3D.new()
			visual.mesh = mesh
			visual.material_override = material(Color("4a5359") if width < 20 else Color("7e986c"))
			add_child(visual)
			if width > 20:
				var body := StaticBody3D.new()
				var shape := CollisionShape3D.new()
				shape.shape = mesh.create_trimesh_shape()
				body.add_child(shape)
				visual.add_child(body)

func build_hillside_homes() -> void:
	var colors := [Color("dba06d"), Color("d8c18f"), Color("8fafa7"), Color("c78673")]
	for side in [-1, 1]:
		for row in 2:
			for column in 5:
				var x := 359.0 + column * 9.5
				var z: float = side * (13.0 + row * 10.0)
				var color: Color = colors[(column + row + (1 if side > 0 else 0)) % colors.size()]
				box(self, Vector3(x, 11.5, z), Vector3(8, 3.2, 8), color, true)
				box(self, Vector3(x, 13.15, z), Vector3(8.4, 0.2, 8.4), color.darkened(0.3))
				box(self, Vector3(x, 11.0, z - side * 4.02), Vector3(1.5, 2.2, 0.06), Color("42545a"))
		for step in 5:
			var x := 344.0 + step * 1.2
			var ground := (x - 294.0) * 10.0 / 56.0 - 0.1
			box(self, Vector3(x, ground + 0.1, side * 31.0), Vector3(1.3, 0.2, 2), Color("b8b4a2"), true)
func build_supermarkets() -> void:
	for center in [294.0, 798.0]:
		var wall := Color("c3b9a1")
		box(self, Vector3(center, 0.02, -100), Vector3(72, 0.2, 34), Color("b8b4a2"))
		box(self, Vector3(center, 7, -117), Vector3(72, 14, 0.4), wall, true)
		for side in [-1, 1]:
			box(self, Vector3(center + side * 36, 7, -100), Vector3(0.4, 14, 34), wall, true)
			box(self, Vector3(center + side * 20, 7, -83), Vector3(32, 14, 0.4), wall, true)
		box(self, Vector3(center, 10.5, -83), Vector3(8, 7, 0.4), wall, true)
		box(self, Vector3(center, 14.1, -100), Vector3(72, 0.2, 34), Color("81938f"), true)
		box(self, Vector3(center, 0.04, -70), Vector3(72, 0.08, 26), Color("62696a"))
		for x in range(-30, 31, 6):
			box(self, Vector3(center + x, 0.09, -70), Vector3(0.12, 0.02, 10), Color("e7d4a2"))
		for x in range(-27, 28, 9):
			for z in [-109, -99, -89]:
				box(self, Vector3(center + x, 1.1, z), Vector3(2, 2.2, 7), Color("3d5557"), true)
				for shelf in 3:
					box(self, Vector3(center + x + 1.05, 0.5 + shelf * 0.65, z), Vector3(0.2, 0.35, 6), [Color("c99951"), Color("809a65"), Color("b35e49")][shelf])
		sign_text("SUPERMERCADO", Vector3(center, 8.5, -82.7))

func build_city() -> void:
	build_hills()
	build_hillside_homes()
	build_supermarkets()
	# Continuous high collision rails close the four corners, even during jumps.
	for x in [-186,938]:
		var rail := box(self,Vector3(x,6,0),Vector3(2,16,294),Color("b0aa99"),true)
		rail.visible = false
	for z in [-144,144]:
		var rail := box(self,Vector3(376,6,z),Vector3(1128,16,2),Color("b0aa99"),true)
		rail.visible = false
	var colors := [Color("b9ada0"), Color("aeb8b5"), Color("b09b8b"), Color("82959f"), Color("c0bdb2"), Color("9ca49c")]
	var original_rng_state := 0
	for ix in 26:
		if ix == 8: original_rng_state = rng.state
		for iz in 6:
			var x := -147.0 + ix * 42
			var z := -105.0 + iz * 42
			if absf(z) < 35 and (absf(x - 378) < 84 or absf(x - 714) < 84): continue
			if ix in [10, 11, 22, 23] and iz in [0, 1]: continue
			if Vector2(x, z) in [Vector2(21,-105),Vector2(-63,21),Vector2(63,21),Vector2(-63,63),Vector2(-105,-21),Vector2(105,-63),Vector2(147,63),Vector2(105,21)]:
				continue # The bank has its own accessible building and interior.
			if Vector2(x,z) in [Vector2(-63,21),Vector2(63,21),Vector2(-63,63)]:
				continue
			box(self, Vector3(x, 0.015, z), Vector3(29, 0.22, 29), Color("b8b4a2"))
			if ix >= 8 and ix <= 17 and iz == (0 if ix == 12 else 5):
				var facade: Color = colors[ix % colors.size()]
				for side in [-1, 1]:
					box(self, Vector3(x + side * 12, 3, z), Vector3(0.3, 6, 24), facade, true)
					box(self, Vector3(x + side * 7.5, 3, z + 12), Vector3(9, 6, 0.3), facade, true)
				box(self, Vector3(x, 3, z - 12), Vector3(24, 6, 0.3), facade, true)
				box(self, Vector3(x, 5, z + 12), Vector3(6, 2, 0.3), facade, true)
				box(self, Vector3(x, 6.1, z), Vector3(24, 0.2, 24), facade.darkened(0.25), true)
				box(self, Vector3(x - 7, 0.6, z - 7), Vector3(5, 1.2, 1.5), Color("715c44"), true)
				box(self, Vector3(x + 7, 0.6, z - 7), Vector3(5, 1.2, 1.5), Color("52766b"), true)
				continue
			if (ix == 0 or (ix >= 8 and ix % 6 == 0)) and iz in [1, 3, 4]:
				box(self, Vector3(x, 0.15, z), Vector3(26, 0.12, 26), Color("7e986c"))
				for j in 5:
					palm(Vector3(x + rng.randf_range(-10, 10), 0.2, z + rng.randf_range(-10, 10)))
				continue
			if ix in [9, 12, 15, 18, 21] and iz == (0 if ix % 2 == 1 else 5):
				for side in [-1, 1]:
					box(self, Vector3(x + side * 5.75, 7, z), Vector3(10, 14, 22), colors[(ix + side) % colors.size()], true)
					box(self, Vector3(x + side * 5.75, 14.25, z), Vector3(10.2, 0.5, 22.2), Color("62696a"))
				box(self, Vector3(x, 0.14, z), Vector3(1.5, 0.03, 22), Color("555d5d"))
				continue
			var height := rng.randf_range(8, 25) if ix < 3 else rng.randf_range(14, 46)
			var width := rng.randf_range(17, 24)
			var color: Color = colors[rng.randi_range(0, colors.size() - 1)]
			box(self, Vector3(x, height / 2, z), Vector3(width, height, 22), color, true)
			box(self, Vector3(x, height + 0.25, z), Vector3(width + 0.6, 0.5, 22.6), color.darkened(0.22))
			box(self, Vector3(x + 3, height + 0.8, z), Vector3(4, 1.3, 3), Color("7a8584"))
			box(self, Vector3(x, 0.55, z), Vector3(width + 0.3, 1.1, 22.3), Color("62696a"))
			for side in [-1, 1]:
				for mullion in range(-8, 9, 4):
					box(self, Vector3(x + side * (width / 2 + 0.06), height / 2, z + mullion), Vector3(0.12, height, 0.12), Color("404d55"))
				box(self, Vector3(x, 2.8, z + side * 11.1), Vector3(width, 0.24, 0.18), Color("4e5d64"))
			for floor_index in int((height - 3) / 3.3):
				var y := 3.3 + floor_index * 3.3
				for column in 4:
					var px := x - width * 0.36 + column * width * 0.24
					var window_color := Color("44616a") if rng.randf() > 0.25 else Color("e6c995")
					box(self, Vector3(px, y, z + 11.02), Vector3(1.65, 1.5, 0.06), window_color)
					box(self, Vector3(px, y, z - 11.02), Vector3(1.65, 1.5, 0.06), window_color)
				box(self, Vector3(x - width / 2 - 0.02, y, z), Vector3(0.06, 1.5, 17), Color("56717a"))
				box(self, Vector3(x + width / 2 + 0.02, y, z), Vector3(0.06, 1.5, 17), Color("56717a"))
			box(self, Vector3(x, 1.5, z + 11.1), Vector3(3, 3, 0.1), Color("354d58"))
			box(self, Vector3(x, 3.3, z + 12), Vector3(10, 0.3, 2.2), Color("dc885b"))
			if (ix + iz) % 3 == 0:
				var names := ["COSTA CAFÉ", "HOTEL SOL", "MERCADO", "STUDIO 84", "MARÉ ALTA", "GARAGEM"]
				sign_text(names[(ix + iz) % 6], Vector3(x, 4.5, z + 11.1))
	rng.state = original_rng_state
	for road in range(-126, 883, 42):
		for dash in range(-135, 136, 9):
			if absi(dash - roundi(dash / 42.0) * 42) > 8:
				box(self, Vector3(road, 0.012, dash), Vector3(0.15, 0.025, 3.2), Color("e7d4a2"))

		for cross in range(-126, 127, 42):
			for stripe in 5:
				box(self, Vector3(road - 4 + stripe * 2, 0.02, cross + 7), Vector3(0.9, 0.03, 2.3), Color("d6d6c6"))
	for road in range(-126, 127, 42):
		for dash in range(-135, 928, 9):
			if absi(dash - roundi(dash / 42.0) * 42) > 8:
				box(self, Vector3(dash, 0.014, road), Vector3(3.2, 0.025, 0.15), Color("e7d4a2"))
	for z in range(-124, 130, 21):
		palm(Vector3(-137, 0, z))
		box(self, Vector3(-132, 2.8, z), Vector3(0.16, 5.6, 0.16), Color("40515b"))
		box(self, Vector3(-131, 5.6, z), Vector3(2, 0.16, 0.35), Color("fbe3ad"), false, true)
	for x in [-168, 924]:
		for z in range(-135,136,9):
			box(self, Vector3(x,0.01,z),Vector3(0.15,0.025,3),Color("e7d4a2"))
	# Distinct plaza at the starting intersection.
	sign_text("COSTA LIVRE", Vector3(-21, 7, 32.1))

func sign_text(value: String, at: Vector3) -> void:
	var style_index:=absi(value.hash())%4
	var panels: Array=[Color("183b3a"),Color("203b4a"),Color("342f2a"),Color("443245")]
	var accents: Array=[Color("dfb66b"),Color("70d2bd"),Color("f0a65e"),Color("e1a1cf")]
	var text_colors: Array=[Color("fff0ce"),Color("e5f4ed"),Color("fff0d4"),Color("f8e8f3")]
	var width:=clampf(value.length()*0.31,3.8,13.8)
	var plaque:=Node3D.new()
	plaque.position=at
	add_child(plaque)
	box(plaque,Vector3(0,0,-0.18),Vector3(width+0.34,1.56,0.22),Color("17252a"))
	box(plaque,Vector3(0,0,-0.045),Vector3(width,1.28,0.05),panels[style_index])
	box(plaque,Vector3(0,0.57,0),Vector3(width,0.09,0.025),accents[style_index],false,true)
	box(plaque,Vector3(-width*0.43,-0.45,0),Vector3(0.1,0.16,0.025),accents[style_index],false,true)
	var label := Label3D.new()
	label.text = value
	label.font_size = 48
	label.pixel_size = 0.012
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	label.modulate = text_colors[style_index]
	label.outline_modulate = Color("10191c")
	label.outline_size = 6
	label.font=SIGN_FONTS[style_index]
	label.position=Vector3(0,0.02,0.02)
	plaque.add_child(label)
	batch_city_geometry(plaque)

func batch_city_geometry(parent: Node3D = null) -> void:
	if parent == null:
		parent = self
	# Native instancing keeps the generated city affordable on integrated GPUs.
	var groups := {}
	for node in parent.get_children():
		if node is MeshInstance3D and node.mesh is BoxMesh and node.visible and not node.get_meta("keep_mesh",false):
			var mat: Material = node.material_override
			if not groups.has(mat):
				groups[mat] = []
			var transform: Transform3D = node.transform
			transform.basis = transform.basis.scaled(node.mesh.size)
			groups[mat].append(transform)
			for child in node.get_children():
				if child is StaticBody3D:
					child.reparent(parent, true)
			parent.remove_child(node)
			node.queue_free()
	for mat in groups:
		var instances := MultiMeshInstance3D.new()
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		var cube := BoxMesh.new()
		cube.size = Vector3.ONE
		multi.mesh = cube
		multi.instance_count = groups[mat].size()
		for i in groups[mat].size():
			multi.set_instance_transform(i, groups[mat][i])
		instances.multimesh = multi
		instances.material_override = mat
		parent.add_child(instances)

func palm(at: Vector3) -> void:
	visuals.palm(self, at)

func spawn_car(at: Vector3, color: Color, police := false, tier := -1) -> CharacterBody3D:
	var car := Car.new()
	car.world = self
	car.net_id=vehicle_sequence
	vehicle_sequence+=1
	car.paint = color
	car.police = police
	car.tier = tier if tier >= 0 else (rng.randi_range(1,3) if police else rng.randi_range(0,8))
	add_child(car)
	car.position = at
	cars.append(car)
	if police:
		cops.append(car)
	if settings != null:
		settings.register_visuals(car)
	return car

func _unhandled_input(event: InputEvent) -> void:
	if extra != null and extra.handle_input(event):
		return
	if activities != null and activities.handle_input(event):
		return
	if event.is_action_pressed("pause"):
		activities.set_menu("pause")
		return
	if get_tree().paused or (activities != null and activities.menu != ""):
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and elapsed > 0.25:
		camera_yaw -= event.relative.x * 0.003
		camera_pitch = clampf(camera_pitch + event.relative.y * 0.002, -0.45, 1.35)
		mouse_idle = 0
	if event.is_action_pressed("interact") and not finished:
		interact()
	if event.is_action_pressed("reset") and not finished:
		if activities.bank.inside() or activities.bank.phase == 4:
			notify("Saia do banco pela porta da frente.")
			return
		if active_car != null:
			active_car.position = Vector3(clampf(roundf(active_car.position.x / 42) * 42, -126, 882), 1, clampf(active_car.position.z, -130, 130))
			active_car.speed = 0
			active_car.heading = 0
			active_car.rotation = Vector3.ZERO
			notify("Carro reposicionado na rua.")
		else:
			player.position = Vector3(-5, 1, 12)
	if event.is_action_pressed("restart") and finished:
		Engine.time_scale = 1
		get_tree().reload_current_scene()

func interact() -> void:
	if car_transition:
		return
	if active_car != null:
		# Test both doors, then front/rear: never place the character inside a wall.
		for offset in [Vector3(-2.5, 1, 0), Vector3(2.5, 1, 0), Vector3(0, 1, 3.5), Vector3(0, 1, -3.5)]:
			var exit_point: Vector3 = active_car.global_transform * offset
			var query := PhysicsShapeQueryParameters3D.new()
			var capsule := CapsuleShape3D.new()
			capsule.radius = 0.4
			capsule.height = 1.8
			query.shape = capsule
			query.transform = Transform3D(Basis.IDENTITY, exit_point + Vector3(0, 0.9, 0))
			query.collision_mask = 5
			if get_world_3d().direct_space_state.intersect_shape(query).is_empty():
				car_transition = true
				var exiting_car := active_car
				player.position = exit_point
				player.velocity = exiting_car.velocity * 0.4 + Vector3(0, 3, 0)
				player.visible = true
				player.model.process_mode = Node.PROCESS_MODE_INHERIT
				player.collision_layer = 2
				exiting_car.driving = false
				active_car = null
				var door_offset: Vector3 = offset.normalized()*1.05
				door_offset.y = 0
				player.model.position = player.to_local(exiting_car.to_global(door_offset))
				player.model.rotation.y = exiting_car.heading+atan2(-offset.x,-offset.z)
				var exit_tween := create_tween()
				exit_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				exit_tween.tween_property(player.model,"position",Vector3.ZERO,0.32)
				exit_tween.tween_callback(func():
					player.model.position = Vector3.ZERO
					car_transition = false
				)
				return
		notify("Sem espaço para sair. Afaste o carro da parede.")
	else:
		var closest := nearest_car()
		if closest != null:
			if network != null and not network.car_available(closest):
				notify("Este carro esta sendo usado por outro jogador.")
				return
			car_transition = true
			active_car = closest
			active_car.driving = false
			active_car.traffic = false
			player.visible = true
			player.roll_time = 0
			player.model.rotation.x = 0
			player.collision_layer = 0
			player.velocity = Vector3.ZERO
			camera_yaw = active_car.heading
			var entering_car := active_car
			player.model.position = Vector3.ZERO
			var entry_side := -1.0 if entering_car.to_local(player.global_position).x < 0 else 1.0
			var door_target := player.to_local(entering_car.to_global(Vector3(entry_side*1.05,0,0)))
			var enter_tween := create_tween()
			enter_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			enter_tween.tween_property(player.model,"position",door_target,0.32)
			enter_tween.parallel().tween_property(player.model,"rotation:y",entering_car.heading,0.32)
			enter_tween.tween_callback(func():
				player.visible = false
				player.model.position = Vector3.ZERO
				player.model.process_mode = Node.PROCESS_MODE_DISABLED
				entering_car.driving = true
				car_transition = false
			)
			if not active_car.owned:
				if network==null or not network.is_client():
					raise_heat(12)
				active_car.owned = true
				notify("Carro roubado. A polícia foi avisada.")

func nearest_car() -> CharacterBody3D:
	var nearest: CharacterBody3D
	var distance := 4.5
	for car in cars:
		if car.police or car.hp <= 0:
			continue
		var current := player.position.distance_to(car.position)
		if current < distance:
			distance = current
			nearest = car
	return nearest

func subject_position() -> Vector3:
	return active_car.position if active_car != null else player.position

func raise_heat(amount: float) -> void:
	if network!=null and network.is_client():
		network.rules.send_action("crime",{"amount":clampf(amount,0,80)})
		return
	if heat <= 0:
		response_delay = 6
	heat = minf(100, heat + amount)
	crime_grace = 14

func car_by_id(id: int) -> CharacterBody3D:
	for car in cars:
		if car.net_id==id:
			return car
	return null

func update_dispatch(delta: float) -> void:
	if station!=null:
		station.dispatch(delta)

func police_target(observer: Node3D) -> Vector3:
	if network!=null and network.active():
		return network.rules.police_target(observer.position)
	return subject_position()

func police_can_see(observer: Node3D) -> bool:
	var target := police_target(observer) + Vector3(0, 1, 0)
	var origin := observer.position + Vector3(0, 1.5, 0)
	if origin.distance_to(target) > 42:
		return false
	if network!=null and network.active() and origin.distance_to(target)>12 and network.rules.target_crouched(target-Vector3(0,1,0)):
		return false
	var query := PhysicsRayQueryParameters3D.create(origin, target, 1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func safe_camera_position(focus: Vector3, desired: Vector3) -> Vector3:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = camera_shape
	query.transform = Transform3D(Basis.IDENTITY,focus)
	query.motion = desired-focus
	query.collision_mask = 1
	var fractions := get_world_3d().direct_space_state.cast_motion(query)
	return focus+query.motion*fractions[0]

func damage(amount: float) -> void:
	if network!=null and network.active():
		network.rules.hurt_local(amount)
		return
	health = maxf(0, health - amount)
	if health <= 0:
		finish(false)

func notify(message: String) -> void:
	if network!=null and network.rules!=null and network.rules.context_peer>1:
		network.rules.private_notice(network.rules.context_peer,message)
		return
	toast = message
	toast_time = 4.5

func _physics_process(delta: float) -> void:
	if finished or get_tree().paused:
		return
	if engine_audio != null:
		engine_audio.volume_db = -28 if active_car != null else -55
		engine_audio.pitch_scale = 0.7 + absf(active_car.speed) / 24 if active_car != null else 0.7
	if network!=null and network.active():
		network.rules.physics(delta)
		toast_time=maxf(0,toast_time-delta)
		elapsed+=delta
		return
	elapsed += delta
	toast_time = maxf(0, toast_time - delta)
	var pos := subject_position()
	activities.tick(delta)
	update_dispatch(delta)
	var nearest_cop := 1000.0
	sight_timer -= delta
	if sight_timer <= 0:
		sight_timer = 0.14
		last_seen = false
	for cop in cops:
		if cop.hp > 0:
			nearest_cop = minf(nearest_cop, pos.distance_to(cop.position))
			if sight_timer >= 0.14 and not last_seen:
				last_seen = police_can_see(cop)
	for officer in activities.officers:
		if officer.hp > 0:
			nearest_cop = minf(nearest_cop, pos.distance_to(officer.position))
			if sight_timer >= 0.14 and not last_seen:
				last_seen = police_can_see(officer)
	var seen := last_seen
	if heat > 0:
		if not seen and crime_grace <= 0:
			heat = maxf(0, heat - delta * 3.0)
		if seen and nearest_cop < 4.5 and (active_car == null or absf(active_car.speed) < 2):
			bust_progress += delta
			if bust_progress > 9:
				finish(false)
		else:
			bust_progress = maxf(0, bust_progress - delta * 2)
	else:
		bust_progress = 0
func _process(delta: float) -> void:
	if camera == null:
		return
	if get_tree().paused:
		return
	mouse_idle += delta
	if active_car != null and absf(active_car.speed) > 4 and mouse_idle > 1.8:
		camera_yaw = lerp_angle(camera_yaw, active_car.heading, delta * 2)
	var focus := subject_position() + Vector3(0, 1.6, 0)
	var distance := 9.5 if active_car != null else 6.5
	var indoors: bool = active_car == null and (activities.bank.inside() or (life != null and life.inside_room(player.position)))
	if indoors:
		distance = 3.8
	var aiming: bool = active_car == null and Input.is_action_pressed("aim") and activities.weapon > 0
	if active_car == null and activities.weapon > 0:
		focus += Vector3(0.65, 0, 0).rotated(Vector3.UP, camera_yaw)
	if aiming:
		distance = 3.2
	camera.fov = lerpf(camera.fov, 52.0 if aiming else 68.0, 1 - exp(-delta * 10))
	var offset := Vector3(0, sin(camera_pitch) * distance + (0.6 if indoors else 1.2), cos(camera_pitch) * distance).rotated(Vector3.UP, camera_yaw)
	var desired := focus + offset
	camera_check_timer -= delta
	if camera_check_timer <= 0 or aiming:
		camera_check_timer = 0.05
		camera_target = safe_camera_position(focus,desired)-focus
	camera.position = camera.position.lerp(focus+camera_target, 1 - exp(-delta * 12))
	if camera.position.distance_to(focus) > 0.1:
		camera.look_at(camera.position-offset if aiming else focus)
	hud_clock += delta
	if hud_clock >= 0.05:
		hud_clock = 0
		hud.queue_redraw()

func finish(success: bool) -> void:
	if network!=null and network.active():
		network.rules.hurt_local(200)
		return
	if finished:
		return
	finished = true
	activities.bank.hacking = false
	won = success
	extra.begin_death()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func setup_audio() -> void:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = 22050
	var data := PackedByteArray()
	data.resize(44102)
	for i in 22050:
		var t := float(i) / 22050
		var sample := sin(TAU * 65 * t) * 0.5 + sin(TAU * 130 * t) * 0.2 + sin(TAU * 195 * t) * 0.1
		data.encode_s16(i * 2, int(sample * 20000))
	# Keep a guard frame for the WAV loop mixer at loop_end.
	data[44100]=data[0]
	data[44101]=data[1]
	wav.data = data
	engine_audio = AudioStreamPlayer.new()
	engine_audio.stream = wav
	engine_audio.volume_db = -55
	add_child(engine_audio)
	engine_audio.play()

func _exit_tree() -> void:
	if is_instance_valid(engine_audio):
		engine_audio.stop()
		engine_audio.stream = null

func activity_held() -> bool:
	if network!=null and network.active():
		return network.rules.held(network.rules.context_peer if network.rules.context_peer>0 else multiplayer.get_unique_id())
	return Input.is_action_pressed("activity")
