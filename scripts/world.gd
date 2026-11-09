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
var settings: Node
var pause_menu: Control
var hud_clock := 0.0
var extra: Node
var interiors: Node3D
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
	rng.state = -3374745113267529202
	interiors = preload("res://interiors.tscn").instantiate()
	add_child(interiors)
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
	if mode == "sandbox" and game_mode == "campaign":
		life.owned_home = -1
		life.owned_homes.clear()
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
		if bus_passenger:
			return
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
		# Test both doors, then front/rear: never place the character inside a wall.
		var offset := vehicle_exit_offset(active_car)
		if offset != Vector3.ZERO:
			var exit_point := active_car.to_global(offset)
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
		if closest == null:
			return
		if network != null and network.active():
			if not network.car_available(closest) and closest.tier == closest.Catalog.BUS:
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

func raise_heat(amount: float, actor := 0) -> void:
	if network!=null and network.is_client():
		network.rules.send_action("crime",{"amount":clampf(amount,0,80)})
		return
	if network != null and network.active():
		var rules: Node = network.rules
		var id: int = actor if actor > 0 else rules.context_peer
		if id <= 0:
			id = rules.attacker if rules.attacker > 0 else multiplayer.get_unique_id()
		if rules.sheets.has(id) and not rules.is_dead(id):
			rules.sheets[id].erase("wanted_reset")
	if heat <= 0:
		response_delay = 6
	heat = minf(100, heat + amount)
	crime_grace = 14

func check_vehicle_entry(previous: Vector3, current: Vector3, actor := 0) -> void:
	var wanted: float = network.rules.wanted_heat(actor if actor > 0 else multiplayer.get_unique_id()) if network != null and network.active() else heat
	if wanted >= 60.0 or previous.is_equal_approx(current):
		return
	if life.inside_public_interior(current) and not life.inside_public_interior(previous):
		raise_heat(maxf(0.0, 60.0 - heat), actor)

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
	var mission_vehicle: Node = car_by_id(int(observer.get_meta("mission_vehicle",-1)))
	if mission_vehicle != null and mission_vehicle.hp > 0: return mission_vehicle.position
	if network!=null and network.active():
		var assigned: int = int(observer.get_meta("police_target_peer",0))
		if assigned > 0 and network.members.has(assigned) and not network.rules.is_dead(assigned):
			return network.rules.position_of(assigned)
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
	if not get_tree().paused:
		tick_vehicle_entries(delta)
	if finished or get_tree().paused:
		return
	if engine_audio != null:
		engine_audio.volume_db = -28 if active_car != null else -55
		engine_audio.pitch_scale = 0.7 + absf(active_car.speed) / 24 if active_car != null else 0.7
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
	if cutscene == null or not cutscene.active:
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

func finish(success: bool) -> void:
	if network!=null and network.active():
		network.rules.hurt_local(200)
		return
	if finished:
		return
	finished = true
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
	player.velocity = Vector3.ZERO
	player.visible = true
	player.collision_layer = 2
	player.model.visible = true
	player.model.process_mode = Node.PROCESS_MODE_INHERIT
	player.model.position = Vector3.ZERO
	player.model.rotation = Vector3.ZERO
	player.roll_time = 0
	health = 100
	heat = 0
	finished = false
	Engine.time_scale = 1
	extra.death_filter.hide()
	camera.position = player.position + Vector3(0,4,7)
	camera_check_timer = 0
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if retry_after_death:
		retry_after_death = false
		if activities.campaign_index == 5:
			activities.bank.phase = 0
			activities.bank.taken = [false, false, false]
			activities.bank.mistakes = 0
			activities.bank.lockout = 0
			activities.bank.door.rotation.y = 0
			activities.bank.security_light.material_override = material(Color("ef9d6b"), true)
			activities.bank.screen.material_override = material(Color("66bbcc"), true)
			for bag in activities.bank.bag_models: bag.visible = true
		activities.save_campaign()
		activities.start_job(activities.campaign_index)
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
