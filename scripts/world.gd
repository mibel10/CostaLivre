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
var sniper_scope_hidden := false
var camera_yaw := 0.0
var camera_pitch := 0.34
var mouse_idle := 0.0
var heat := 0.0
const HEAT_DECAY_RATE := 8.0
const CRIME_GRACE_SECONDS := 6.0
var response_delay := 0.0
var crime_grace := 0.0
var health := 100.0
var cash := 900
var activities: Node
var bust_progress := 0.0
const PRISON_SPAWN := Vector3(1012, 0.3, 40)
const PRISON_INTERIOR := AABB(Vector3(1005.2, -0.4, 35.2), Vector3(59.6, 10.3, 39.6))
const PRISON_POINTS := [Vector3(1012,0,40), Vector3(1012,0,61), Vector3(1035,0,60), Vector3(1054,0,65), Vector3(1035,0,48), Vector3(1035,0,73)]
const PRISON_TEXT := ["Pegue a ferramenta na cela", "Agache para abrir o acesso ao corredor", "Segure F para desligar as câmeras", "Encontre o cartão de acesso", "Segure F para desativar o alarme", "Abra a saída"]
const PRISON_GUARD_POSTS := [Vector3(1015,0.3,53), Vector3(1033,0.3,59), Vector3(1051,0.3,66)]
var prison_stage := -1
var prison_progress := 0.0
var prison_after_death := false
var retry_after_death := false
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
var city_event_rng := RandomNumberGenerator.new()
var city_event_clock := 70.0
var witness_call_times := {}
var settings: Node
var pause_menu: Control
var hud_clock := 0.0
var extra: Node
var interiors: Node3D
var atmosphere_cycle
var life: Node3D
var fps_counter: CanvasLayer
var car_transition := false
const VEHICLE_ENTRY_TIME := 2.0
var vehicle_entries := {}
var entry_visual := false
var vehicle_falls := {}
var opened_vehicle_doors := {}
var bus_passenger := false
var traffic_refresh := 0.0
var sight_timer := 0.0
var last_seen := false
var camera_check_timer := 0.0
var camera_target := Vector3.ZERO
var camera_focus_previous := Vector3.ZERO
var camera_focus_current := Vector3.ZERO
var camera_focus_interval := 1.0 / 60.0
var camera_focus_elapsed := 0.0
var camera_focus_ready := false
var game_mode := "sandbox"
var admin_used := false
var cutscene: Control
var touch_controls: Control
var network: Node
var profile: Node
var station: Node3D
const FUEL_STATIONS := [Vector3(134, 0, 134), Vector3(-134, 0, -134)]
const MAP_EAST := 1344.0
var vehicle_sequence := 0
const SPAWNS := [Vector3(-8,0.3,12),Vector3(76,0.3,84),Vector3(134,0.3,42),Vector3(-134,0.3,-42),Vector3(42,0.3,-134),Vector3(-42,0.3,134),Vector3(8,0.3,-84),Vector3(84,0.3,8),Vector3(-84,0.3,-8),Vector3(126,0.3,-76),Vector3(-126,0.3,76),Vector3(0,0.3,50)]
var camera_shape := SphereShape3D.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	camera_shape.radius = 0.28
	rng.seed = 185
	city_event_rng.randomize()
	city_event_clock = city_event_rng.randf_range(65.0, 100.0)
	batch_city_geometry(self)
	create_fuel_station()
	setup_input()
	rng.state = -3374745113267529202
	interiors = preload("res://interiors.tscn").instantiate()
	add_child(interiors)
	atmosphere_cycle = preload("res://scripts/atmosphere.gd").new()
	atmosphere_cycle.name = "AtmosphereCycle"
	atmosphere_cycle.world = self
	add_child(atmosphere_cycle)
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
	for x in range(210,883,84):
		for z in [-126,84]:
			if z == -126 and x in [294,798]: continue
			var base := Vector3(x,0.2,z)
			var car := spawn_car(base+Vector3(3,0,15),Color.from_hsv(float(x)/1000.0,0.45,0.8),false,4+(x/84)%5)
			car.traffic = true
			car.route.assign([base+Vector3(3,0,3),base+Vector3(39,0,3),base+Vector3(39,0,39),base+Vector3(3,0,39)])
			spawn_car(base+Vector3(7,0,15),Color.from_hsv(float(x+z)/1200.0,0.4,0.85),false,1+(x/84)%8)
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
	# Separate blocks spread the extra traffic without queuing cars on the existing circuits.
	var extra_blocks := [
		Vector2i(-126, -42), Vector2i(-84, -42), Vector2i(0, -42), Vector2i(42, -42),
		Vector2i(84, 0), Vector2i(42, 42), Vector2i(-84, 84), Vector2i(0, 84),
		Vector2i(210, 0), Vector2i(252, 0), Vector2i(546, 0), Vector2i(840, 0),
		Vector2i(378, 0), Vector2i(714, 0),
	]
	for i in extra_blocks.size():
		var block: Vector2i = extra_blocks[i]
		var base := Vector3(block.x, 0.2, block.y)
		var car := spawn_car(base + Vector3(39, 0, 21), Color.from_hsv(fposmod(0.11 + i * 0.17, 1.0), 0.45, 0.82), false, 1 + i % 8)
		car.traffic = true
		car.route.assign([base + Vector3(3, 0, 3), base + Vector3(39, 0, 3), base + Vector3(39, 0, 39), base + Vector3(3, 0, 39)])
		car.route_index = 2
		car.heading = PI
		car.rotation.y = PI
	var bus_routes := [
		[Vector3(-126,0.2,0),Vector3(-126,0.2,84),Vector3(84,0.2,84),Vector3(84,0.2,-84),Vector3(-126,0.2,-84)],
		[Vector3(294,0.2,-126),Vector3(546,0.2,-126),Vector3(798,0.2,-126),Vector3(798,0.2,126),Vector3(294,0.2,126)],
		[Vector3(882,0.2,-84),Vector3(882,0.2,84),Vector3(714,0.2,126),Vector3(546,0.2,84),Vector3(714,0.2,-84)]
	]
	for i in bus_routes.size():
		var bus := spawn_car(bus_routes[i][0],Color("e8bd4c"),false,preload("res://scripts/vehicle_catalog.gd").BUS)
		bus.traffic = true
		bus.route.assign(bus_routes[i])
		bus.route_index = 1
	var escape_car := spawn_car(Vector3(1048, 0.2, 84), Color("567b8a"), false, 7)
	escape_car.heading = PI / 2
	escape_car.rotation.y = escape_car.heading
	network = preload("res://scripts/lan_session.gd").new()
	network.name = "LanSession"
	network.world = self
	add_child(network)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	pause_menu.show_mode_select()

func start_mode(mode: String) -> void:
	if mode != "sandbox" and restart_after_admin():
		return
	if mode == "campaign" and network != null and network.active():
		notify("Desconecte da sala para jogar a campanha.")
		return
	if mode == "sandbox" and game_mode == "campaign":
		life.owned_home = -1
		life.owned_homes.clear()
		if prison_stage >= 0:
			prison_stage = -1
			prison_progress = 0.0
			player.position = SPAWNS[0]
			player.velocity = Vector3.ZERO
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
		hud.show_tutorial()

func restart_after_admin() -> bool:
	if not admin_used:
		return false
	get_tree().reload_current_scene.call_deferred()
	return true

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
	var bindings := {"forward": KEY_W, "back": KEY_S, "left": KEY_A, "right": KEY_D, "jump": KEY_SPACE, "sprint": KEY_SHIFT, "crouch": KEY_Z, "interact": KEY_E, "reset": KEY_T, "flip": KEY_V, "reload": KEY_R, "activity": KEY_F, "jobs": KEY_M, "map": KEY_TAB, "pause": KEY_ESCAPE, "restart": KEY_ENTER, "credits": KEY_C}
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
	# Chunked native instancing reduces static draw calls without spanning the whole map.
	var groups := {}
	for node in parent.get_children():
		if not node is MeshInstance3D or not node.mesh is BoxMesh or not node.visible or node.get_meta("keep_mesh",false):
			continue
		if node.visibility_range_end > 0.0 or node.visibility_range_begin > 0.0 or node.layers != 1 or node.transparency > 0.0:
			continue
		var material: Material = node.material_override if node.material_override != null else node.mesh.surface_get_material(0)
		if not material is StandardMaterial3D:
			continue
		var mat: StandardMaterial3D = material
		if mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or mat.albedo_color.a < 1.0:
			continue
		var safe_children := true
		for child in node.get_children():
			if not child is StaticBody3D:
				safe_children = false
		if not safe_children:
			continue
		var cell := Vector2i(floori(node.position.x / 64.0), floori(node.position.z / 64.0))
		var key := "%d:%d:%d:%d" % [mat.get_instance_id(), cell.x, cell.y, node.cast_shadow]
		if not groups.has(key):
			groups[key] = {"material": mat, "transforms": [], "cast_shadow": node.cast_shadow}
		var transform: Transform3D = node.transform
		transform.basis = transform.basis.scaled(node.mesh.size)
		groups[key].transforms.append(transform)
		for child in node.get_children():
			child.reparent(parent, true)
		parent.remove_child(node)
		node.queue_free()
	for key in groups:
		var batch: Dictionary = groups[key]
		var instances := MultiMeshInstance3D.new()
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		var cube := BoxMesh.new()
		cube.size = Vector3.ONE
		multi.mesh = cube
		multi.instance_count = batch.transforms.size()
		for i in batch.transforms.size():
			multi.set_instance_transform(i, batch.transforms[i])
		instances.multimesh = multi
		instances.material_override = batch.material
		instances.cast_shadow = batch.cast_shadow
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

func restore_pointer() -> void:
	if activities == null or activities.bank == null:
		return
	var pointer_needed: bool = finished or activities.menu != "" or activities.bank.local_hacking()
	pointer_needed = pointer_needed or (extra != null and extra.wheel)
	if network != null and network.active():
		pointer_needed = pointer_needed or network.offer_panel.visible or network.rules.local_mission_hacking()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if pointer_needed else Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if vehicle_falls.has(vehicle_local_id()):
		return
	if network != null and network.offer_panel.visible:
		return
	if extra != null and extra.handle_input(event):
		return
	if event.is_action_pressed("activity") and not finished and activities.menu == "" and active_car != null and not bus_passenger and near_fuel_station(active_car.position):
		if active_car.refuel_time > 0.0 or active_car.hp <= 0:
			return
		if absf(active_car.speed) > 0.25:
			notify("Pare o carro junto à bomba.")
		elif active_car.fuel >= 1.0:
			notify("O tanque já está cheio.")
		elif network != null and network.active():
			network.rules.send_action("refuel")
		else:
			active_car.refuel_time = 5.0
			notify("Abastecendo...")
		return
	if activities != null and activities.handle_input(event):
		return
	if event.is_action_pressed("pause"):
		activities.set_menu("pause")
		return
	if get_tree().paused or (activities != null and activities.menu != ""):
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and elapsed > 0.25:
		camera_yaw -= event.relative.x * 0.003 * settings.camera_sensitivity
		camera_pitch = clampf(camera_pitch + event.relative.y * 0.002 * settings.camera_sensitivity, -0.45, 1.35)
		mouse_idle = 0
	if prison_stage_for() >= 0 and (event.is_action_pressed("reset") or event.is_action_pressed("interact")):
		return
	if event.is_action_pressed("interact") and not finished:
		interact()
	if event.is_action_pressed("flip") and not finished and not bus_passenger and active_car != null:
		if active_car.can_right_vehicle():
			if network.active():
				network.rules.send_action("right_vehicle")
			elif not active_car.right_vehicle():
				notify("Sem espaço para desvirar o carro.")
		return
	if event.is_action_pressed("reset") and not finished:
		if bus_passenger:
			return
		if activities.bank.inside() or activities.bank.phase == 4:
			notify("Saia do banco pela porta da frente.")
			return
		if active_car != null:
			if active_car.tumbling:
				return
			active_car.position = Vector3(clampf(roundf(active_car.position.x / 42) * 42, -126, 882), 1, clampf(active_car.position.z, -130, 130))
			active_car.speed = 0
			active_car.heading = 0
			active_car.rotation = Vector3.ZERO
			notify("Carro reposicionado na rua.")
		else:
			player.position = Vector3(-5, 1, 12)
	if event.is_action_pressed("restart") and finished:
		respawn_local()

func vehicle_exit_offset(car: Node3D) -> Vector3:
	var rear: float = car.Catalog.SIZES[car.tier].z / 2.0 + 1.0 if car.tier == car.Catalog.BUS else 3.5
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collision_mask = 5
	for offset: Vector3 in [Vector3(-2.5, 1, 0), Vector3(2.5, 1, 0), Vector3(0, 1, rear), Vector3(0, 1, -rear)]:
		query.transform = Transform3D(Basis.IDENTITY, car.to_global(offset) + Vector3(0, 0.9, 0))
		if get_world_3d().direct_space_state.intersect_shape(query).is_empty():
			return offset
	return Vector3.ZERO

func interact() -> void:
	if car_transition or vehicle_falls.has(vehicle_local_id()):
		return
	if bus_passenger:
		network.rules.send_action("bus_exit")
		return
	if active_car != null:
		if active_car.tumbling and absf(active_car.speed) >= 2.0:
			return
		# Test both doors, then front/rear: never place the character inside a wall.
		var offset := vehicle_exit_offset(active_car)
		if offset != Vector3.ZERO:
			var exit_point := active_car.to_global(offset)
			car_transition = true
			var exiting_car := active_car
			exiting_car.refuel_time = 0.0
			exiting_car.refuel_peer = 0
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
		if closest == null:
			return
		if network != null and network.active():
			if not network.car_available(closest):
				network.rules.send_action("bus_board",{"car":closest.net_id})
			else:
				network.rules.send_action("vehicle_entry",{"car":closest.net_id})
		else:
			request_vehicle_entry(1,closest,player.position)

func request_vehicle_entry(id: int, car: Node3D, at: Vector3) -> void:
	if not is_instance_valid(car) or car.police or car.hp <= 0 or vehicle_entries.has(id) or at.distance_squared_to(car.position) >= 20.25:
		return
	if id == 1 and (active_car != null or car_transition or finished):
		return
	if vehicle_falls.has(id):
		return
	var online: bool = network != null and network.active()
	var driver: int = int(network.owners.get(car.net_id,0)) if online else 0
	if driver == id:
		return
	var victim := driver if driver > 0 else (-1 if car.traffic and absf(car.speed) > 0.5 else 0)
	if victim != 0 and (absf(car.speed) <= 0.5 or car.tier in [9,car.Catalog.BUS]):
		if online:
			network.rules.private_notice(id,"Este veículo está ocupado.")
		else:
			notify("Este veículo está ocupado.")
		return
	for other in vehicle_entries.values():
		if other.car == car.net_id:
			return
	var side := -1.0 if car.to_local(at).x < 0 else 1.0
	var exit_at := Vector3.ZERO
	if victim != 0:
		var offset := vehicle_exit_offset(car)
		if offset == Vector3.ZERO:
			return
		exit_at = car.to_global(offset)
		if absf(offset.x) > 0.1:
			side = signf(offset.x)
	vehicle_entries[id] = {"car":car.net_id,"side":side,"time":0.0,"at":at,"victim":victim,
		"exit":exit_at,"ejected":false,"duration":1.0 if victim != 0 else VEHICLE_ENTRY_TIME}
	if id == 1:
		car_transition = true
		entry_visual = true
		player.velocity = Vector3.ZERO
		player.roll_time = 0
		player.model.position = Vector3.ZERO
		player.model.rotation.x = 0
		notify("Abrindo a porta…" if victim != 0 or car.owned else "Arrombando a trava…")

func vehicle_local_id() -> int:
	return multiplayer.get_unique_id() if network != null and network.active() else 1

func vehicle_held_for_entry(car_id: int) -> bool:
	if vehicle_entries.is_empty():
		return false
	for entry in vehicle_entries.values():
		if entry.car == car_id:
			return true
	return false

func tick_vehicle_entries(delta: float) -> void:
	for id: int in vehicle_falls.keys():
		vehicle_falls[id].time -= delta
		if vehicle_falls[id].time <= 0.0:
			vehicle_falls.erase(id)
			if id == vehicle_local_id() and active_car == null and not finished and (network == null or not network.active() or not network.rules.is_dead(id)):
				player.show()
	var online: bool = network != null and network.active()
	if not online or not network.is_client():
		for id: int in vehicle_entries.keys():
			var entry: Dictionary = vehicle_entries[id]
			var car := car_by_id(entry.car)
			if car == null or car.hp <= 0 or (id == 1 and finished) or (online and (not network.members.has(id) or network.rules.is_dead(id))):
				vehicle_entries.erase(id)
				continue
			entry.time += delta
			if entry.victim != 0 and not entry.ejected and entry.time >= 0.45:
				if online and entry.victim > 0 and int(network.owners.get(car.net_id,0)) != int(entry.victim):
					vehicle_entries.erase(id)
					continue
				eject_vehicle_driver(car,entry,online)
				entry.ejected = true
			if entry.time < entry.duration:
				continue
			vehicle_entries.erase(id)
			if entry.at.distance_squared_to(car.position) >= 20.25 or (online and int(network.owners.get(car.net_id,0)) not in [0,id]):
				continue
			car.traffic = false
			car.traffic_speed = 10.0
			car.traffic_speed_time = 0.0
			if not car.owned or entry.victim != 0:
				car.owned = true
				raise_heat(12,id)
			if online:
				network.owners[car.net_id] = id
				var member: Dictionary = network.members[id]
				member.car = car.net_id
				member.car_position = car.position
				member.car_heading = car.heading
				member.speed = car.speed
				network.vehicle_grants[id] = [car.net_id,Time.get_ticks_msec()+1200]
				network.rules.send_personal(id,"vehicle_enter",{"car":car.net_id})
			else:
				finish_vehicle_entry(car)
	var doors := {}
	for entry in vehicle_entries.values():
		var car := car_by_id(entry.car)
		if car == null or car.hp <= 0 or car.tier == 9:
			continue
		var start := 0.13 if entry.victim != 0 else 1.55
		var amount := smoothstep(start,start+0.25,float(entry.time))
		amount *= 1.0-smoothstep(float(entry.duration)-0.16,float(entry.duration),float(entry.time))
		if amount > 0:
			visuals.pose_car_door(car,entry.side,amount)
			doors[entry.car] = car
	for car_id in opened_vehicle_doors:
		var car: Node3D = opened_vehicle_doors[car_id]
		if not doors.has(car_id) and is_instance_valid(car):
			visuals.pose_car_door(car,0,0)
	opened_vehicle_doors = doors
	var id := vehicle_local_id()
	if vehicle_entries.has(id) and active_car == null:
		var entry: Dictionary = vehicle_entries[id]
		var car := car_by_id(entry.car)
		if car != null:
			car_transition = true
			entry_visual = true
			player.roll_time = 0
			player.model.pose_vehicle_entry(player,car,entry.side,entry.time*VEHICLE_ENTRY_TIME/entry.duration)
	elif entry_visual:
		entry_visual = false
		car_transition = false
		player.model.position = Vector3.ZERO
		player.model.rotation.x = 0

func eject_vehicle_driver(car: Node3D, entry: Dictionary, online: bool) -> void:
	var victim: int = entry.victim
	var outfit := 0
	if online and victim > 0:
		var member: Dictionary = network.members[victim]
		outfit = int(member.get("outfit",0))
		member.car = -1
		member.position = entry.exit
		member.car_position = entry.exit
		member.speed = 0.0
		network.owners.erase(car.net_id)
		network.vehicle_grants.erase(victim)
	car.traffic = false
	var launch := Vector3(entry.side*2.9,1.7,-1.3).rotated(Vector3.UP,car.heading)
	var from := car.to_global(Vector3(entry.side*0.85,0.45,-0.15))
	var data := {"victim":victim,"at":entry.exit,"from":from,"launch":launch,"heading":car.heading,"outfit":outfit}
	play_vehicle_fall(data)
	if online:
		for id in network.members:
			if id != 1 and not network.members[id].is_empty():
				network.personal.rpc_id(id,"vehicle_fall",data)

func play_vehicle_fall(data: Dictionary) -> void:
	var victim: int = data.victim
	if victim > 0:
		vehicle_falls[victim] = {"time":2.0,"at":data.at}
		if victim == vehicle_local_id():
			if active_car != null:
				active_car.driving = false
			active_car = null
			bus_passenger = false
			car_transition = false
			player.position = data.at
			player.velocity = Vector3.ZERO
			player.collision_layer = 2
			player.model.position = Vector3.ZERO
			player.model.rotation = Vector3.ZERO
			player.model.process_mode = Node.PROCESS_MODE_INHERIT
			player.hide()
	var ragdoll := preload("res://scripts/human_visual.gd").new()
	ragdoll.add_to_group("ejected_driver")
	ragdoll.outfit_index = data.outfit
	ragdoll.position = data.from
	ragdoll.rotation.y = data.heading
	add_child(ragdoll)
	ragdoll.start_driver_ragdoll(data.launch)

func finish_vehicle_entry(car: Node3D) -> void:
	if not is_instance_valid(car) or car.hp <= 0 or finished:
		return
	active_car = car
	vehicle_entries.erase(multiplayer.get_unique_id() if network != null and network.active() else 1)
	car.driving = true
	car.traffic = false
	car_transition = false
	entry_visual = false
	player.visible = false
	player.model.position = Vector3.ZERO
	player.model.rotation.x = 0
	player.model.process_mode = Node.PROCESS_MODE_DISABLED
	player.collision_layer = 0
	player.velocity = Vector3.ZERO
	camera_yaw = car.heading

func nearest_car() -> CharacterBody3D:
	var nearest: CharacterBody3D
	var distance := 4.5 * 4.5
	var at := player.position
	for car in cars:
		if car.police or car.hp <= 0:
			continue
		var current := at.distance_squared_to(car.position)
		if current < distance:
			distance = current
			nearest = car
	return nearest

func subject_position() -> Vector3:
	return active_car.position if active_car != null else player.position

func tick_city_events(delta: float) -> void:
	if network != null and network.is_client():
		return
	city_event_clock -= delta
	if city_event_clock > 0.0:
		return
	city_event_clock = city_event_rng.randf_range(75.0, 125.0)
	var observers: Array[Vector3] = [subject_position()]
	if network != null and network.active():
		for id in network.rules.participants():
			if id != multiplayer.get_unique_id():
				observers.append(network.rules.position_of(id))
	var event := city_event_rng.randi_range(0, 3)
	if event == 3:
		spawn_street_rival()
		return
	var nearby: Array[CharacterBody3D] = []
	for car in cars:
		if not car.traffic or car.police or car.hp <= 0 or car == activities.target_car or car in activities.targets:
			continue
		for at in observers:
			var distance_squared := car.position.distance_squared_to(at)
			if distance_squared < 90.0 * 90.0 and distance_squared > 14.0 * 14.0:
				nearby.append(car)
				break
	if nearby.is_empty():
		return
	var car: CharacterBody3D = nearby[city_event_rng.randi_range(0, nearby.size() - 1)]
	if event == 0:
		car.traffic = false
		car.speed = 0.0
		car.velocity = Vector3.ZERO
		car.take_hit(car.hp)
		var other: CharacterBody3D
		for candidate in nearby:
			if candidate != car and candidate.position.distance_squared_to(car.position) < 20.0 * 20.0:
				other = candidate
				break
		if other != null:
			other.traffic = false
			other.speed = 0.0
			other.velocity = Vector3.ZERO
			other.take_hit(35.0)
		announce_city_event("Acidente de trânsito na região. Dirija com cuidado.")
	elif event == 1:
		car.traffic = false
		car.speed = 0.0
		car.velocity = Vector3.ZERO
		car.hp = minf(car.hp, 80.0)
		announce_city_event("Um carro quebrou e bloqueia parte da via.")
	else:
		car.traffic_speed = 16.0
		car.traffic_speed_time = 24.0
		announce_city_event("Motorista imprudente avistado. Mantenha distância.")

func spawn_street_rival() -> void:
	if cars.filter(func(car): return car.has_meta("rival_name") and car.hp > 0).size() >= 3:
		return
	var routes := [
		[Vector3(-126,0.2,-84),Vector3(84,0.2,-84),Vector3(84,0.2,84),Vector3(-126,0.2,84)],
		[Vector3(294,0.2,126),Vector3(798,0.2,126),Vector3(798,0.2,-126),Vector3(294,0.2,-126)],
		[Vector3(882,0.2,84),Vector3(714,0.2,126),Vector3(546,0.2,84),Vector3(714,0.2,-84)]
	]
	var route: Array = routes[city_event_rng.randi_range(0,routes.size()-1)]
	var names := ["Nina Veloz","Duda Turbo","Rafa Costa"]
	var rival_name: String = names[city_event_rng.randi_range(0,names.size()-1)]
	var rival := spawn_car(route[0],Color("d84b5b"),false,city_event_rng.randi_range(3,7))
	rival.traffic = true
	rival.route.assign(route)
	rival.route_index = 1
	mark_street_rival(rival,rival_name)
	announce_city_event("%s apareceu para desafiar os pilotos da região." % rival_name)

func mark_street_rival(car: Node3D, rival_name: String) -> void:
	car.set_meta("rival_name",rival_name)
	var existing_tag := car.get_node_or_null("RivalTag") as Label3D
	if existing_tag != null:
		existing_tag.text = "RIVAL · " + rival_name
		return
	var tag := Label3D.new()
	tag.name = "RivalTag"
	tag.text = "RIVAL · " + rival_name
	tag.font_size = 28
	tag.pixel_size = 0.003
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.modulate = Color("ffd16b")
	tag.position = Vector3(0,2.1,0)
	car.add_child(tag)

func announce_city_event(message: String) -> void:
	if network != null and network.active():
		network.rules.notice_all(message)
	else:
		notify(message)

func witnessed_crime(actor: int, at: Vector3) -> bool:
	if life == null or not at.is_finite():
		return false
	var now := Time.get_ticks_msec()
	if now - int(witness_call_times.get(actor, -15000)) < 15000:
		return false
	for person in life.people:
		if not is_instance_valid(person) or person.hp <= 0 or person.position.distance_squared_to(at) > 20.0 * 20.0:
			continue
		var query := PhysicsRayQueryParameters3D.create(person.position + Vector3.UP * 1.3, at + Vector3.UP, 1)
		query.hit_from_inside = true
		if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			witness_call_times[actor] = now
			return true
	return false

func raise_heat(amount: float, actor := 0) -> void:
	if amount <= 0.0 or not is_finite(amount) or actor < 0:
		return
	if network!=null and network.is_client():
		network.rules.send_action("crime",{"amount":clampf(amount,0,80)})
		return
	var witness_called := false
	if network != null and network.active():
		var rules: Node = network.rules
		var id: int = actor if actor > 0 else rules.context_peer
		if id <= 0:
			id = rules.attacker if rules.attacker > 0 else multiplayer.get_unique_id()
		if not rules.sheets.has(id) or rules.is_dead(id):
			return
		witness_called = witnessed_crime(id, rules.position_of(id))
		if witness_called:
			amount += 12.0
		rules.sheets[id]["wanted_heat"] = minf(100.0, rules.wanted_heat(id) + amount)
		rules.sheets[id]["wanted_grace"] = CRIME_GRACE_SECONDS
	if heat <= 0:
		response_delay = 6
	if network != null and network.active():
		network.rules.refresh_wanted_heat()
	else:
		witness_called = witnessed_crime(1, subject_position())
		if witness_called:
			amount += 12.0
		heat = minf(100, heat + amount)
	crime_grace = CRIME_GRACE_SECONDS
	if witness_called:
		var message := "Uma testemunha viu o crime e chamou a polícia."
		if network != null and network.active():
			network.rules.notice_all(message)
		else:
			notify(message)

func check_vehicle_entry(previous: Vector3, current: Vector3, actor := 0) -> void:
	var wanted: float = network.rules.wanted_heat(actor if actor > 0 else multiplayer.get_unique_id()) if network != null and network.active() else heat
	if wanted >= 60.0 or previous.is_equal_approx(current):
		return
	if life.inside_public_interior(current) and not life.inside_public_interior(previous):
		raise_heat(60.0 - wanted, actor)

func car_by_id(id: int) -> CharacterBody3D:
	if id < 0:
		return null
	for car in cars:
		if car.net_id==id:
			return car
	return null

func update_dispatch(delta: float) -> void:
	if station!=null:
		station.dispatch(delta)

func police_target(observer: Node3D) -> Vector3:
	if bool(observer.get_meta("prison_guard", false)):
		return prison_guard_target(observer.position)
	var mission_vehicle: Node = car_by_id(int(observer.get_meta("mission_vehicle",-1)))
	if mission_vehicle != null and mission_vehicle.hp > 0: return mission_vehicle.position
	if network!=null and network.active():
		return network.rules.police_target_actor(observer.position, int(observer.get_meta("police_target_peer", 0)))[1]
	return subject_position()

func prison_guard_target(from: Vector3) -> Vector3:
	var target := Vector3.INF
	var distance_squared := INF
	if network != null and network.active():
		for id in network.rules.sheets:
			if int(network.rules.sheets[id].get("prison_stage", -1)) < 0:
				continue
			var at: Vector3 = network.rules.position_of(int(id))
			var current := from.distance_squared_to(at)
			if current < distance_squared:
				target = at
				distance_squared = current
	elif prison_stage >= 0:
		target = subject_position()
	return target

func prisoners_present() -> bool:
	if network != null and network.active():
		for sheet in network.rules.sheets.values():
			if int(sheet.get("prison_stage", -1)) >= 0:
				return true
		return false
	return prison_stage >= 0

func update_prison_guards() -> void:
	if network != null and network.is_client():
		return
	var guards: Array = activities.officers.filter(func(officer): return bool(officer.get_meta("prison_guard", false)))
	if not prisoners_present():
		for guard in guards:
			activities.officers.erase(guard)
			guard.queue_free()
		return
	while guards.size() < PRISON_GUARD_POSTS.size():
		var guard := preload("res://scripts/officer.gd").new()
		guard.world = self
		guard.position = PRISON_GUARD_POSTS[guards.size()]
		guard.set_meta("prison_guard", true)
		add_child(guard)
		activities.officers.append(guard)
		guards.append(guard)

func police_can_see(observer: Node3D, at := Vector3.INF) -> bool:
	var target := (at if at.is_finite() else police_target(observer)) + Vector3.UP
	var origin := observer.position + Vector3(0, 1.5, 0)
	var distance_squared := origin.distance_squared_to(target)
	if distance_squared > 42.0 * 42.0:
		return false
	if (network == null or not network.active()) and activities != null and activities.job == 29 and heat <= 0.0 and profile != null and profile.outfit == 5 and distance_squared > 16.0:
		return false
	if network!=null and network.active() and distance_squared > 12.0 * 12.0 and network.rules.target_crouched(target-Vector3(0,1,0)):
		return false
	var query := PhysicsRayQueryParameters3D.create(origin, target, 1)
	query.hit_from_inside = true
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func safe_camera_position(focus: Vector3, desired: Vector3) -> Vector3:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = camera_shape
	query.transform = Transform3D(Basis.IDENTITY,focus)
	query.motion = desired-focus
	query.collision_mask = 1
	var fractions := get_world_3d().direct_space_state.cast_motion(query)
	return focus+query.motion*fractions[0]

func prison_stage_for(id: int = 0) -> int:
	if network != null and network.active():
		var peer := id if id > 0 else multiplayer.get_unique_id()
		return int(network.rules.sheets.get(peer, {}).get("prison_stage", -1))
	return prison_stage

func prison_prompt() -> String:
	var stage := prison_stage_for()
	if stage < 0 or stage >= PRISON_POINTS.size():
		return ""
	if player.position.distance_to(PRISON_POINTS[stage]) < 2.8:
		var text: String = "F / " + PRISON_TEXT[stage]
		if stage in [2, 4]:
			var amount: float = float(network.rules.sheets.get(multiplayer.get_unique_id(), {}).get("prison_progress", 0.0)) if network != null and network.active() else prison_progress
			text += " · %d%%" % roundi(clampf(amount / (5.0 if stage == 2 else 10.0), 0, 1) * 100.0)
		return text
	return "Cadeia / " + PRISON_TEXT[stage]

func tick_prison(id: int, at: Vector3, held: bool, delta: float) -> void:
	var stage := prison_stage_for(id)
	if stage not in [2, 4]:
		return
	var online: bool = network != null and network.active()
	var amount: float = float(network.rules.sheets[id].get("prison_progress", 0.0)) if online else prison_progress
	amount = amount + delta if held and at.distance_to(PRISON_POINTS[stage]) < 2.8 else 0.0
	if online:
		network.rules.sheets[id]["prison_progress"] = amount
	else:
		prison_progress = amount
	if amount >= (5.0 if stage == 2 else 10.0):
		prison_interact(id, at)

func prison_interact(id: int, at: Vector3) -> void:
	var stage := prison_stage_for(id)
	if stage < 0 or stage >= PRISON_POINTS.size() or at.distance_to(PRISON_POINTS[stage]) >= 2.8:
		return
	var online: bool = network != null and network.active()
	var crouched: bool = player.is_crouching if not online or id == multiplayer.get_unique_id() else bool(network.members[id].get("crouch", false))
	if stage == 1 and not crouched:
		if online: network.rules.private_notice(id, "Agache para abrir a passagem.")
		else: notify("Agache para abrir a passagem.")
		return
	var amount: float = float(network.rules.sheets[id].get("prison_progress", 0.0)) if online else prison_progress
	if stage in [2, 4] and amount < (5.0 if stage == 2 else 10.0):
		if online: network.rules.private_notice(id, "Mantenha F pressionado para concluir.")
		else: notify("Mantenha F pressionado para concluir.")
		return
	prison_progress = 0.0
	if online: network.rules.sheets[id]["prison_progress"] = 0.0
	stage += 1
	if network != null and network.active():
		network.rules.sheets[id]["prison_stage"] = stage if stage < PRISON_POINTS.size() else -1
		if stage >= PRISON_POINTS.size():
			network.rules.send_personal(id, "prison_escape", {})
			var exit := Vector3(1035, 0.3, 79)
			network.members[id].position = exit
			network.members[id].car_position = exit
			network.members[id]["elevator_target"] = exit
			network.members[id]["elevator_target_until"] = Time.get_ticks_msec() + 1500
		else:
			network.rules.private_notice(id, PRISON_TEXT[stage])
	else:
		prison_stage = stage if stage < PRISON_POINTS.size() else -1
		if stage >= PRISON_POINTS.size():
			player.position = Vector3(1035,0.3,79)
			notify("Você fugiu da cadeia!")
			if game_mode == "campaign":
				activities.save_campaign()
				activities.start_job(activities.campaign_job_id(activities.campaign_index))
		else:
			notify(PRISON_TEXT[stage])
			if game_mode == "campaign": activities.save_campaign()

func damage(amount: float, by_police := false) -> void:
	if network!=null and network.active():
		network.rules.hurt_local(amount)
		return
	health = maxf(0, health - amount)
	if health <= 0:
		prison_after_death = by_police or prison_stage >= 0
		finish(false)

func notify(message: String) -> void:
	if network!=null and network.rules!=null and network.rules.context_peer>1:
		network.rules.private_notice(network.rules.context_peer,message)
		return
	toast = message
	toast_time = 4.5

func create_fuel_station() -> void:
	for index in FUEL_STATIONS.size():
		var station_root := Node3D.new()
		station_root.name = "Posto_%d" % (index + 1)
		station_root.position = FUEL_STATIONS[index]
		add_child(station_root)
		build_fuel_station(station_root)

func near_fuel_station(at: Vector3, radius := 5.0) -> bool:
	for station_at: Vector3 in FUEL_STATIONS:
		if at.distance_to(station_at) < radius:
			return true
	return false

func build_fuel_station(station_root: Node3D) -> void:
	for spec in [
		[Vector3(0, 4.1, 0), Vector3(8, 0.5, 5), Color("e9bd62")],
		[Vector3(-3.5, 2, -2), Vector3(0.25, 4, 0.25), Color("d6e0d6")],
		[Vector3(3.5, 2, -2), Vector3(0.25, 4, 0.25), Color("d6e0d6")],
		[Vector3(-3.5, 2, 2), Vector3(0.25, 4, 0.25), Color("d6e0d6")],
		[Vector3(3.5, 2, 2), Vector3(0.25, 4, 0.25), Color("d6e0d6")],
		[Vector3(0, 0.8, 0), Vector3(0.8, 1.6, 0.8), Color("d94f3d")]
	]:
		var mesh := MeshInstance3D.new()
		var shape := BoxMesh.new()
		shape.size = spec[1]
		mesh.mesh = shape
		mesh.position = spec[0]
		var material := StandardMaterial3D.new()
		material.albedo_color = spec[2]
		mesh.material_override = material
		station_root.add_child(mesh)

func _physics_process(delta: float) -> void:
	if not get_tree().paused:
		tick_vehicle_entries(delta)
		update_camera_focus_sample(delta)
	if finished or get_tree().paused:
		return
	if network == null or not network.is_client():
		tick_city_events(delta)
	update_prison_guards()
	if prison_stage_for() >= 0 and (network == null or not network.active()):
		tick_prison(1, player.position, Input.is_action_pressed("activity") and activities.menu == "", delta)
	if prison_stage_for() >= 0 and active_car == null:
		player.position.x = clampf(player.position.x, 1005.5, 1064.5)
		player.position.z = clampf(player.position.z, 35.5, 74.0)
	if engine_audio != null:
		engine_audio.volume_db = -28 if active_car != null else -55
		engine_audio.pitch_scale = 0.7 + absf(active_car.speed) / 24 if active_car != null else 0.7
	if active_car != null and active_car.refuel_time > 0.0 and (network == null or not network.active()):
		if active_car.hp <= 0 or absf(active_car.speed) > 0.25 or not near_fuel_station(active_car.position):
			active_car.refuel_time = 0.0
			notify("Abastecimento cancelado.")
		else:
			active_car.refuel_time = maxf(0.0, active_car.refuel_time - delta)
			if active_car.refuel_time <= 0.0:
				active_car.fuel = 1.0
				notify("Tanque cheio.")
	if network == null or not network.is_client():
		traffic_refresh -= delta
		if traffic_refresh <= 0.0:
			traffic_refresh = 0.25
			var observers: Array[Vector3] = [subject_position()]
			if network != null and network.active():
				for peer_id in network.rules.participants():
					if peer_id != multiplayer.get_unique_id():
						observers.append(network.rules.position_of(peer_id))
			for car in cars:
				if not car.traffic:
					continue
				car.traffic_nearby = car == activities.target_car or car in activities.targets
				if not car.traffic_nearby:
					for at in observers:
						if car.position.distance_squared_to(at) <= 180.0 * 180.0:
							car.traffic_nearby = true
							break
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
	if heat > 0:
		sight_timer -= delta
		var check_sight := sight_timer <= 0.0
		if check_sight:
			sight_timer = 0.14
			last_seen = false
		var can_arrest := false
		var on_foot_or_stopped := active_car == null or absf(active_car.speed) < 2.0
		for group in [cops, activities.officers]:
			for observer in group:
				if observer.hp <= 0:
					continue
				var close := on_foot_or_stopped and not can_arrest and pos.distance_squared_to(observer.position) < 4.5 * 4.5
				if (close or (check_sight and not last_seen)) and police_can_see(observer, pos):
					last_seen = true
					can_arrest = can_arrest or close
		if not last_seen and crime_grace <= 0:
			heat = maxf(0, heat - delta * HEAT_DECAY_RATE)
		if can_arrest:
			bust_progress += delta
			if bust_progress >= 3.5:
				prison_after_death = true
				finish(false)
		else:
			bust_progress = 0.0
	else:
		bust_progress = 0
		sight_timer = 0.0
		last_seen = false

func _process(delta: float) -> void:
	var escape_marker: Label3D = get_node_or_null("MarcadorFuga")
	if escape_marker != null:
		var stage := prison_stage_for()
		escape_marker.visible = stage >= 0 and stage < PRISON_POINTS.size() and not finished
		if escape_marker.visible:
			escape_marker.position = PRISON_POINTS[stage] + Vector3.UP * 2.2
	if camera == null:
		return
	var scoped: bool = not get_tree().paused and not finished and active_car == null and not car_transition and activities.menu == "" and not extra.wheel and activities.weapon == 6 and Input.is_action_pressed("aim") and (network == null or not network.active() or not network.rules.is_dead(multiplayer.get_unique_id())) and (cutscene == null or not cutscene.active)
	if sniper_scope_hidden != scoped:
		player.model.visible = not scoped
		sniper_scope_hidden = scoped
	if get_tree().paused:
		return
	if cutscene == null or not cutscene.active:
		mouse_idle += delta
		if active_car != null and absf(active_car.speed) > 4 and mouse_idle > 1.8:
			camera_yaw = lerp_angle(camera_yaw, active_car.heading, delta * 2)
		var focus := rendered_camera_focus(delta)
		var distance := 9.5 if active_car != null else 6.5
		var indoors: bool = active_car == null and (PRISON_INTERIOR.has_point(player.position) or activities.bank.inside() or (life != null and life.inside_room(player.position)))
		if indoors:
			distance = 3.8
		var aiming: bool = active_car == null and Input.is_action_pressed("aim") and activities.weapon > 0
		if active_car == null and activities.weapon > 0:
			focus += Vector3(0.65, 0, 0).rotated(Vector3.UP, camera_yaw)
		if aiming:
			distance = 3.2
		camera.fov = lerpf(camera.fov, (18.0 if activities.weapon == 6 else 52.0) if aiming else 68.0, 1 - exp(-delta * 10))
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

func update_camera_focus_sample(delta: float) -> void:
	var focus := subject_position() + Vector3(0, 1.6, 0)
	if not camera_focus_ready or camera_focus_current.distance_to(focus) > 80.0:
		camera_focus_previous = focus
		camera_focus_current = focus
		camera_focus_ready = true
	else:
		camera_focus_previous = camera_focus_current
		camera_focus_current = focus
	camera_focus_interval = maxf(delta, 0.001)
	camera_focus_elapsed = 0.0

func rendered_camera_focus(delta: float) -> Vector3:
	if not camera_focus_ready:
		return subject_position() + Vector3(0, 1.6, 0)
	camera_focus_elapsed = minf(camera_focus_interval, camera_focus_elapsed + delta)
	return camera_focus_previous.lerp(camera_focus_current, camera_focus_elapsed / camera_focus_interval)

func finish(success: bool) -> void:
	if network!=null and network.active():
		network.rules.hurt_local(200)
		return
	if finished:
		return
	finished = true
	if active_car != null:
		active_car.refuel_time = 0.0
	retry_after_death = game_mode == "campaign" and activities.job >= 0
	activities.job = -1
	activities.progress = 0
	activities.robbery_progress = 0
	activities.pedestrian_robbery_progress = 0
	life.task_progress = 0
	life.stair_chase_started = false
	for officer in activities.officers.duplicate():
		if bool(officer.get_meta("mission_stair", false)):
			activities.officers.erase(officer)
			officer.queue_free()
	marker.visible = false
	activities.bank.hacking = false
	won = success
	extra.begin_death()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func respawn_local() -> void:
	life.offline_building_job.clear()
	if active_car != null: active_car.driving = false
	active_car = null
	car_transition = false
	var home: int = life.owned_home
	player.position = life.HOME_BUILDING + Vector3(0,(home + 1) * 6 + 0.3,5) if home >= 0 else Vector3(-5,0.3,12)
	if prison_after_death or prison_stage >= 0:
		prison_stage = 0
		prison_after_death = false
		player.position = PRISON_SPAWN
	player.velocity = Vector3.ZERO
	player.visible = true
	player.collision_layer = 2
	player.model.visible = true
	player.model.process_mode = Node.PROCESS_MODE_INHERIT
	player.model.position = Vector3.ZERO
	player.model.rotation = Vector3.ZERO
	player.roll_time = 0
	prison_progress = 0.0
	bust_progress = 0.0
	last_seen = false
	sight_timer = 0.0
	health = 100
	heat = 0
	finished = false
	Engine.time_scale = 1
	extra.death_filter.hide()
	camera.position = player.position + Vector3(0,4,7)
	camera_check_timer = 0
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if retry_after_death and activities.campaign_index == 5:
		activities.bank.phase = 0
		activities.bank.taken = [false, false, false]
		activities.bank.mistakes = 0
		activities.bank.lockout = 0
		activities.bank.door.rotation.y = 0
		activities.bank.security_light.material_override = material(Color("ef9d6b"), true)
		activities.bank.screen.material_override = material(Color("66bbcc"), true)
		for bag in activities.bank.bag_models: bag.visible = true
	if prison_stage >= 0:
		retry_after_death = false
		notify("Você está preso. " + PRISON_TEXT[prison_stage])
		if game_mode == "campaign": activities.save_campaign()
		return
	if retry_after_death:
		retry_after_death = false
		activities.save_campaign()
		activities.start_job(activities.campaign_job_id(activities.campaign_index))
	else:
		if game_mode == "campaign": activities.save_campaign()
		notify("Você renasceu.")

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
