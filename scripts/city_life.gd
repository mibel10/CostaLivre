extends Node3D

const Pedestrian = preload("res://scripts/pedestrian.gd")
const HOME_BUILDING := Vector3(861,0,-105)
const PLACES := [Vector3(-63,0,21),Vector3(63,0,21),Vector3(-63,0,63),Vector3(-105,0,-21),Vector3(105,0,-63),Vector3(147,0,63)]
const TITLES := ["CAFÉ MARÉ", "CLÍNICA COSTA", "RESIDENCIAL COSTA", "OFICINA DO PORTO", "MERCADO DA PRAIA", "ESTÚDIO SOLAR"]
var owned_home := -1
var owned_homes: Array[int] = []
var world: Node3D
var people: Array[CharacterBody3D] = []
var rooms: Array[Node3D] = []
var refresh := 0.0
var task_progress := 0.0
const BUILDING_OFFERS := {
	"cafe": ["Café Maré", "Comprar café (+15 de vida) · $20", "Saiu café fresco. Quer um?"],
	"clinic": ["Clínica Costa", "Pedir tratamento · $100", "Posso cuidar desses ferimentos."],
	"rest": ["Recepção", "Descansar (+20 de vida)", "Pode sentar e descansar um pouco."],
	"market": ["Mercado da Praia", "Comprar lanche (+25 de vida) · $35", "Quer um lanche para a viagem?"],
	"office": ["Serviço de entregas", "Entregar 3 caixas em 60 s · +$200", "Tem três caixas para distribuir. Você pode ajudar?"],
	"bank": ["Banco Costa", "Entregar 3 malotes em 60 s · +$200", "Precisamos levar estes malotes aos pontos de coleta."],
	"guns": ["Arsenal", "Ver catálogo de armas comuns", "Quer ver o que temos no balcão?"],
	"cars": ["Concessionária", "Ver catálogo de veículos", "Procurando um veículo?"],
	"garage": ["Garagem Costa", "Ver serviços da oficina", "O que seu carro está precisando?"],
}
const BUILDING_REWARD := 200
const BUILDING_JOB_TIME := 60.0
const DELIVERY_POINTS := [Vector3(-3,0,8),Vector3(3,0,7),Vector3(0,0,3)]
const BANK_WORK_POINTS := [Vector3(-3,0,8),Vector3(3,0,5),Vector3(0,0,11)]
var building_contacts := {}
var offline_building_job := {}
var building_dialog: CenterContainer
var building_title: Label
var building_choice: Button
var building_marker: Label3D
var selected_contact := -1
var elevator_ui: Control
const ELEVATOR_FLOORS := {"housing": 13, "apartment": 10, "tower": 8}
const ELEVATOR_CENTERS := {"housing": Vector3(869,0,-111.5), "apartment": Vector3(-55,0,53.74), "tower": Vector3(155,0,72)}
const ELEVATOR_SPEED := 8.0
const DOOR_TIME := 0.3
const ELEVATOR_CALL := -1
const ELEVATOR_BASEMENT := -2
const BASEMENT_HEIGHT := -8.3
var elevators := {}
var elevator_cabins := {}
var elevator_gates := {}
var elevator_ride := ""
var elevator_offset := Vector3.ZERO
var stair_chase_started := false
const BUILDING_TASK_DURATION := 5.0
const OPERATION_TASK_DURATION := 10.0
const TASKS := {
	7: [3,0,"Reparar motor","Trocar bateria","Calibrar ferramentas"],
	9: [1,0,"Examinar paciente","Preparar medicamento","Desinfetar bancada"],
	10: [4,0,"Conferir produtos","Registrar estoque","Lacrar encomenda"],
	11: [5,0,"Ligar servidor","Recuperar arquivo","Enviar gravacao"],
	12: [2,9,"Acessar terminal","Decifrar arquivo","Recolher documentos"],
	13: [1,0,"Separar material","Atender paciente","Finalizar prontuario"],
	14: [2,3,"Verificar energia","Consertar painel","Ativar seguranca"],
	15: [2,7,"Consultar cameras","Reforcar fechadura","Proteger documentos"],
	16: [0,0,"Preparar cafe","Servir mesa","Fechar caixa"]}
const NEW_TASKS := {
	17: [[Vector3(298,0,-88),Vector3(298,0,-99),Vector3(298,0,-110)], ["Conferir entrega", "Organizar estoque", "Registrar produtos"]],
	18: [[Vector3(802,0,-88),Vector3(802,0,-99),Vector3(802,0,-110)], ["Receber mercadoria", "Repor prateleiras", "Concluir entrega"]],
	19: [[Vector3(189,0,105),Vector3(231,0,105),Vector3(273,0,105)], ["Verificar escritório", "Recolher documentos", "Entregar relatório"]],
	20: [[Vector3(315,0,105),Vector3(357,0,-105),Vector3(399,0,105)], ["Inspecionar sala", "Conferir instalações", "Finalizar vistoria"]],
	21: [[Vector3(290,0,-88),Vector3(290,0,-99),Vector3(290,0,-110)], ["Recolher pedidos", "Separar suprimentos", "Conferir carga"]],
	22: [[Vector3(441,0,105),Vector3(483,0,105),Vector3(525,0,105)], ["Consultar arquivo", "Buscar assinatura", "Protocolar documentos"]],
	23: [[Vector3(567,0,105),Vector3(802,0,-99),Vector3(294,0,-78)], ["Recolher encomenda", "Entregar pedido", "Finalizar contrato"]]
}
const WORK_POINTS := [Vector3(-4,0,4),Vector3(4,0,1),Vector3(0,0,-6)]

func _ready() -> void:
	for i in 22:
		rooms.append(world.interiors.get_node("Rooms/Room%d" % i))
	build_elevators()
	build_elevator_menu()
	build_contact_dialog()
	for i in 32:
		var center := Vector3(-105+(i%4)*42,0,-63+((i/4)%4)*42)
		var ped := Pedestrian.new()
		ped.world = world
		ped.appearance_index = i
		ped.tint = Color.from_hsv(i*0.12,0.25,0.8)
		ped.route.assign([center+Vector3(-13,0,-13),center+Vector3(55,0,-13),center+Vector3(55,0,13),center+Vector3(-13,0,13)])
		add_child(ped)
		ped.position = ped.route[i%4]
		ped.point = (i+1)%4
		if i < 3:
			var offer: String = ["guns","cars","garage"][i]
			var center_at: Vector3 = [world.activities.GUN_SHOP,world.activities.DEALER,world.activities.GARAGE][i]
			ped.position = center_at + Vector3(2,0,-1.5)
			ped.stationary = true
			building_contacts[people.size()] = [offer,center_at]
		people.append(ped)
	for i in 36:
		var center := Vector3(231+(i%9)*84,0,-63+((i/9)%2)*126)
		var ped := Pedestrian.new()
		ped.world = world
		ped.appearance_index = i
		ped.route.assign([center+Vector3(-13,0,-13),center+Vector3(13,0,-13),center+Vector3(13,0,13),center+Vector3(-13,0,13)])
		add_child(ped)
		ped.position = ped.route[i%4]
		ped.point = (i+1)%4
		people.append(ped)
	for i in 3:
		var staff := Pedestrian.new()
		staff.world = world
		staff.appearance_index = i+2
		staff.stationary = true
		staff.tint = Color("93a5b0")
		add_child(staff)
		staff.position = world.activities.bank.to_global(Vector3(-9+i*3,0,-1.6))
		if i == 0:
			building_contacts[people.size()] = ["bank",world.activities.bank.global_position]
		people.append(staff)

	for i in PLACES.size():
		var contact := Pedestrian.new()
		contact.world = world
		contact.appearance_index = i+3
		contact.stationary = true
		contact.tint = Color("a6b19c")
		add_child(contact)
		contact.position = PLACES[i]+Vector3(1,0,5)
		contact.set_meta("building_center",PLACES[i])
		building_contacts[people.size()] = [["cafe","clinic","rest","office","market","office"][i],PLACES[i]]
		people.append(contact)
	for store in 2:
		var cx: float = [294,798][store]
		for cashier in 5:
			var staff := Pedestrian.new()
			staff.name = "Mercado%dCaixa%d" % [store,cashier]
			staff.set_meta("supermarket_cashier", true)
			staff.world = world
			staff.appearance_index = cashier+store
			staff.stationary = true
			add_child(staff)
			staff.position = Vector3(cx-33,0,-111+cashier*5.5)
			staff.model.rotation.y = -PI/2
			people.append(staff)
		for i in 8:
			var shopper := Pedestrian.new()
			shopper.world = world
			shopper.name = "Mercado%dCliente%d" % [store,i]
			shopper.appearance_index = i+store
			shopper.shopper = true
			var aisle := cx-22.5+(i%6)*9.0
			shopper.route.assign([Vector3(aisle,0,-84),Vector3(aisle,0,-94.5),Vector3(cx-29.2,0,-94.5),Vector3(cx-29.2,0,-111+(i%5)*5.5),Vector3(cx-29.2,0,-114.5),Vector3(aisle,0,-114.5),Vector3(aisle,0,-84),Vector3(cx,0,-84),Vector3(cx,0,-80),Vector3(cx,0,-84)])
			add_child(shopper)
			shopper.position = shopper.route[i%shopper.route.size()]
			shopper.point = (i+1)%shopper.route.size()
			people.append(shopper)
	var lobbies: Array = PLACES.duplicate()
	for index in range(8,18):
		lobbies.append(Vector3(-147+index*42,0,-105 if index == 12 else 105))
	lobbies.append(HOME_BUILDING)
	for index in lobbies.size():
		# The six original buildings already have one service NPC each.
		for slot in (2 if index < PLACES.size() else 3):
			var resident := Pedestrian.new()
			resident.name = "Predio%02dNPC%d" % [index,slot]
			resident.world = world
			resident.appearance_index = index+slot
			resident.stationary = true
			resident.set_meta("building_center",lobbies[index])
			add_child(resident)
			resident.position = lobbies[index]+[Vector3(-8,0,8),Vector3(8,0,6),Vector3(0,0,-7)][slot]
			resident.model.rotation.y = [-PI/4,PI/3,PI][slot]
			if index >= PLACES.size() and slot == 0:
				building_contacts[people.size()] = ["rest" if lobbies[index] == HOME_BUILDING else "office",lobbies[index]]
			people.append(resident)

func apartment_stair_route() -> Array[Vector3]:
	var route: Array[Vector3]=[]
	for floor_number in 9:
		var base:=PLACES[2]+Vector3(0,floor_number*6,0)
		route.append_array([base+Vector3(-8,1.5,-9),base+Vector3(-6,3,-9),base+Vector3(-6,3,-8),base+Vector3(-8,4.5,-7),base+Vector3(-10,6,-7)])
	return route

func apartment_tenth_floor_actor() -> int:
	if world.network!=null and world.network.active():
		for id in world.network.rules.participants():
			if on_apartment_tenth_floor(world.network.rules.position_of(id)):
				return id
		return -1
	return 0 if on_apartment_tenth_floor(world.player.position) else -1

func on_apartment_tenth_floor(at: Vector3) -> bool:
	var local:=at-PLACES[2]
	return local.y>=54.0 and local.y<59.8 and absf(local.x)<12.0 and absf(local.z)<12.0

func elevator_building_at(at: Vector3) -> String:
	for building: String in ELEVATOR_FLOORS:
		var offset: Vector3 = at - ELEVATOR_CENTERS[building]
		var front := elevator_front(building) * offset.z
		if absf(offset.x) < 1.65 and front > -1.4 and front < 3.0 and offset.y >= BASEMENT_HEIGHT-0.25 and offset.y < (ELEVATOR_FLOORS[building]-1)*6+2.8:
			return building
	return ""

func elevator_front(building: String) -> float:
	return -1.0 if building == "tower" else 1.0

func elevator_position(building: String, floor_number: int) -> Vector3:
	if floor_number == ELEVATOR_BASEMENT:
		return ELEVATOR_CENTERS[building] + Vector3(0,BASEMENT_HEIGHT,0)
	var floor_height := 0.0 if building == "housing" else -0.09
	return ELEVATOR_CENTERS[building] + Vector3(0, floor_number*6+floor_height, 0)

func inside_cabin(at: Vector3, origin: Vector3) -> bool:
	var offset := at - origin
	return absf(offset.x) < 1.3 and absf(offset.z) < 1.3 and offset.y >= -0.12 and offset.y < 2.55

func elevator_box(parent: Node3D, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = at
	parent.add_child(mesh)
	return mesh

func elevator_collision(parent: CollisionObject3D, at: Vector3, size: Vector3) -> CollisionShape3D:
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collision.shape = box
	collision.position = at
	parent.add_child(collision)
	return collision

func build_elevators() -> void:
	var wall := StandardMaterial3D.new()
	wall.albedo_color = Color("#637887")
	var door := StandardMaterial3D.new()
	door.albedo_color = Color("#adbcc8")
	for building: String in ELEVATOR_FLOORS:
		var front := elevator_front(building)
		var cabin := AnimatableBody3D.new()
		cabin.sync_to_physics = false
		add_child(cabin)
		for part in [[Vector3(0,-0.06,0),Vector3(2.72,0.12,2.72)],
			[Vector3(0,2.68,0),Vector3(2.72,0.12,2.72)],
			[Vector3(0,1.32,-front*1.32),Vector3(2.72,2.64,0.08)],
			[Vector3(-1.32,1.32,0),Vector3(0.08,2.64,2.72)],
			[Vector3(1.32,1.32,0),Vector3(0.08,2.64,2.72)]]:
			elevator_box(cabin, part[0], part[1], wall)
			elevator_collision(cabin, part[0], part[1])
		var leaves := []
		for side in [-1,1]:
			leaves.append(elevator_box(cabin, Vector3(side*0.64,1.32,front*1.32), Vector3(1.28,2.64,0.07), door))
		elevator_cabins[building] = [cabin,leaves]
		var gates := {}
		var stops := range(ELEVATOR_FLOORS[building])
		stops.append(ELEVATOR_BASEMENT)
		for floor_number in stops:
			var origin := elevator_position(building,floor_number)
			var gate := StaticBody3D.new()
			add_child(gate)
			gate.position = origin + Vector3(0,0,front*1.42)
			var panels := []
			if building == "apartment" and floor_number >= 0:
				var room: Node3D = rooms[2 if floor_number == 0 else floor_number+5]
				panels = [room.get_node("ElevatorLeft"),room.get_node("ElevatorRight")]
			else:
				for side in [-1,1]:
					panels.append(elevator_box(gate, Vector3(side*0.69,1.34,0), Vector3(1.38,2.68,0.08), door))
			for panel: MeshInstance3D in panels:
				panel.set_meta("closed_position",panel.position)
			gates[floor_number] = [elevator_collision(gate, Vector3(0,1.34,0), Vector3(2.76,2.68,0.10)),panels]
		elevator_gates[building] = gates
		elevators[building] = {"floor":0,"target":0,"phase":"closed","time":0.0,"riders":{}}
		update_elevator_geometry(building)

func elevator_origin(building: String) -> Vector3:
	var state: Dictionary = elevators[building]
	var start := elevator_position(building,state.floor)
	if state.phase != "travel":
		return start
	return start.move_toward(elevator_position(building,state.target),state.time*ELEVATOR_SPEED)

func update_elevator_geometry(building: String) -> void:
	var state: Dictionary = elevators[building]
	var cabin: AnimatableBody3D = elevator_cabins[building][0]
	cabin.position = elevator_origin(building)
	var opening := 0.0
	match state.phase:
		"opening": opening = clampf(state.time / DOOR_TIME,0,1)
		"open": opening = 1.0
		"closing": opening = 1.0-clampf(state.time / DOOR_TIME,0,1)
	var leaves: Array = elevator_cabins[building][1]
	for i in 2:
		leaves[i].position.x = (-1 if i == 0 else 1)*(0.64+opening*1.27)
		leaves[i].visible = opening < 0.99
	for floor_number in elevator_gates[building]:
		var gate: Array = elevator_gates[building][floor_number]
		var amount := opening if floor_number == state.floor else 0.0
		gate[0].disabled = amount >= 0.99
		for i in 2:
			var panel: MeshInstance3D = gate[1][i]
			var closed: Vector3 = panel.get_meta("closed_position")
			panel.position.x = closed.x + (-1 if i == 0 else 1)*amount*1.36

func request_elevator(at: Vector3, destination: int) -> void:
	var building := elevator_building_at(at)
	if building.is_empty():
		return
	var state: Dictionary = elevators[building]
	var floor_number := ELEVATOR_BASEMENT if at.y < -4.0 else roundi(at.y/6.0)
	if not elevator_gates[building].has(floor_number) or state.phase in ["closing","travel","opening"]:
		return
	var origin := elevator_position(building,floor_number)
	if absf(at.y-origin.y) > 1.35:
		return
	var aboard: bool = state.floor == floor_number and inside_cabin(at,origin)
	if elevator_gates[building].has(destination):
		if not aboard:
			return
	elif destination == ELEVATOR_CALL:
		if aboard or state.floor == floor_number:
			if state.phase != "open":
				state.phase = "opening"
			state.time = 0.0
			return
		destination = floor_number
	else:
		return
	if state.floor == destination:
		if state.phase != "open":
			state.phase = "opening"
		state.time = 0.0
		return
	state.target = destination
	state.phase = "closing" if state.phase == "open" else "travel"
	state.time = 0.0
	if state.phase == "travel":
		collect_elevator_riders(building)

func collect_elevator_riders(building: String) -> void:
	var state: Dictionary = elevators[building]
	var origin := elevator_position(building,state.floor)
	var online: bool = world.network != null and world.network.active()
	var ids: Array = world.network.rules.participants() if online else [1]
	state.riders.clear()
	for id in ids:
		if id == 1:
			if world.active_car != null:
				continue
		elif world.network.rules.bus_riders.has(id) or int(world.network.members[id].get("car",-1)) >= 0:
			continue
		var at: Vector3 = world.network.rules.position_of(id) if online else world.player.position
		if inside_cabin(at,origin):
			state.riders[id] = at - origin

func elevator_rider_position(id: int) -> Variant:
	for building: String in elevators:
		var state: Dictionary = elevators[building]
		if state.riders.has(id):
			return elevator_origin(building) + state.riders[id]
	return null

func update_elevator_riders(building: String, online: bool, arriving: bool) -> void:
	var state: Dictionary = elevators[building]
	var origin := elevator_origin(building)
	for id in state.riders.keys():
		var at: Vector3 = origin + state.riders[id]
		if online and (not world.network.members.has(id) or world.network.rules.is_dead(id)):
			state.riders.erase(id)
			continue
		if id == 1:
			move_elevator_rider(at)
			if arriving:
				refresh = 0.5
				world.camera_check_timer = 0
		elif online:
			var member: Dictionary = world.network.members[id]
			member.position = at
			member.car_position = at
			member.held = false
			if arriving:
				member.elevator_target = at
				member.elevator_target_until = Time.get_ticks_msec()+600
				world.network.rules.send_personal(id,"elevator",{"position":at})

func apply_elevator_snapshot(data: Dictionary) -> void:
	var previous := elevators
	elevators = data
	for building: String in elevators:
		if elevators[building].phase == "closed" and (previous[building].phase != "closed" or previous[building].floor != elevators[building].floor):
			update_elevator_geometry(building)
	var id := multiplayer.get_unique_id()
	for building: String in elevators:
		var state: Dictionary = elevators[building]
		if state.riders.has(id):
			elevator_ride = building
			elevator_offset = state.riders[id]
			if world.activities.menu == "elevator":
				world.activities.set_menu("")
			return
	if not elevator_ride.is_empty() and not world.network.rules.is_dead(id):
		apply_elevator_arrival(elevator_origin(elevator_ride)+elevator_offset)
		elevator_ride = ""

func leave_elevator_session() -> void:
	for building: String in elevators:
		var riders: Dictionary = elevators[building].riders
		var origin := elevator_origin(building)
		var at: Vector3 = world.player.position
		riders.clear()
		if elevators[building].phase == "travel" and inside_cabin(at,origin):
			riders[1] = at-origin
	elevator_ride = ""

func _physics_process(delta: float) -> void:
	var online: bool = world.network != null and world.network.active()
	var client: bool = online and world.network.is_client()
	for building: String in elevators:
		var state: Dictionary = elevators[building]
		if state.phase == "closed":
			continue
		state.time += delta
		if not client:
			match state.phase:
				"closing":
					if state.time >= DOOR_TIME:
						state.time = 0.0
						state.phase = "closed" if state.floor == state.target else "travel"
						if state.phase == "travel":
							collect_elevator_riders(building)
				"travel":
					var arrived := elevator_origin(building).is_equal_approx(elevator_position(building,state.target))
					update_elevator_riders(building,online,arrived)
					if arrived:
						state.floor = state.target
						state.phase = "opening"
						state.time = 0.0
						state.riders.clear()
				"opening":
					if state.time >= DOOR_TIME:
						state.phase = "open"
						state.time = 0.0
				"open":
					if state.time >= 15.0:
						state.target = state.floor
						state.phase = "closing"
						state.time = 0.0
		update_elevator_geometry(building)
	if client and not elevator_ride.is_empty() and not world.network.rules.is_dead(multiplayer.get_unique_id()):
		move_elevator_rider(elevator_origin(elevator_ride)+elevator_offset)
	elif not client:
		elevator_ride = ""

func mission_position() -> Vector3:
	var a: Node = world.activities
	if a.ACTION_JOBS.has(a.job): return a.action_destination()
	if a.job in [24,25,26]:
		var floors: Array = {24:[2,5,3],25:[4,6,1],26:[7,5,3]}[a.job]
		if a.stage>=3:
			return PLACES[5]+Vector3(0,0,17)
		return PLACES[5]+Vector3(0,floors[a.stage]*6,0)+WORK_POINTS[a.stage%WORK_POINTS.size()]
	if NEW_TASKS.has(a.job): return NEW_TASKS[a.job][0][mini(a.stage,2)]
	if not TASKS.has(a.job):
		return Vector3.ZERO
	var task: Array = TASKS[a.job]
	return PLACES[task[0]]+Vector3(0,task[1]*6,0)+WORK_POINTS[mini(a.stage,2)]

func task_label() -> String:
	var a: Node = world.activities
	if a.ACTION_JOBS.has(a.job): return a.action_objective()
	if a.job in [24,25,26]:
		var tasks: Array={24:["Desativar cameras","Hackear o servidor central","Baixar arquivos do mainframe","Sair do predio sem ser visto"],25:["Entrar agachado no controle","Hackear o sistema de acesso","Copiar a chave-mestra","Escapar da equipe policial"],26:["Achar o terminal no oitavo andar","Invadir o servidor protegido","Apagar os rastros digitais","Descer e sumir da busca"]}[a.job]
		return "%s / %d%% / agache (Z) e segure F" % [tasks[a.stage],roundi(task_progress/OPERATION_TASK_DURATION*100)]
	if NEW_TASKS.has(a.job): return "%s / %d%% / segure F" % [NEW_TASKS[a.job][1][mini(a.stage,2)], roundi(task_progress/BUILDING_TASK_DURATION*100)]
	if not TASKS.has(a.job):
		return "Explore a cidade"
	var task: Array = TASKS[a.job]
	return "%s / %d%% / segure F" % [task[2+mini(a.stage,2)],roundi(task_progress/BUILDING_TASK_DURATION*100)]

func inside_room(at: Vector3) -> bool:
	var housing := at - HOME_BUILDING
	if absf(housing.x) < 12 and absf(housing.z) < 12 and housing.y >= -0.5 and housing.y < 78: return true
	for room in rooms:
		var local: Vector3 = at-room.position
		if absf(local.x)<12.2 and absf(local.z)<11.7 and local.y>=-0.5 and local.y<5.8:
			return true
	return false

func inside_public_interior(at: Vector3) -> bool:
	if inside_room(at) or (at.y >= -0.5 and world.activities.bank.contains_position(at)):
		return true
	# Inner faces of the two supermarket shells in main.tscn.
	return at.y >= -0.5 and at.y < 14.0 and at.z > -116.8 and at.z < -83.2 and (absf(at.x - 294.0) < 35.8 or absf(at.x - 798.0) < 35.8)

func build_elevator_menu() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	layer.process_mode=Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	elevator_ui = Control.new()
	elevator_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(elevator_ui)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-220,-290)
	panel.size = Vector2(440,580)
	elevator_ui.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	var title := Label.new()
	title.text = "ESCOLHA O ANDAR / ELEVADOR"
	column.add_child(title)
	for floor_number in 13:
		var button := Button.new()
		button.text = "Térreo" if floor_number == 0 else "Andar %02d" % floor_number
		button.custom_minimum_size.y = 32
		button.pressed.connect(use_elevator.bind(floor_number))
		column.add_child(button)
	var basement := Button.new()
	basement.text = "Subsolo"
	basement.custom_minimum_size.y = 32
	basement.pressed.connect(use_elevator.bind(ELEVATOR_BASEMENT))
	column.add_child(basement)
	var close := Button.new()
	close.text = "Voltar"
	close.pressed.connect(func(): elevator_ui.hide(); world.activities.set_menu(""))
	column.add_child(close)
	elevator_ui.hide()

func use_elevator(floor_number: int) -> void:
	if world.active_car != null:
		return
	if world.activities.menu == "elevator":
		world.activities.set_menu("")
	if world.network != null and world.network.active():
		world.network.rules.send_action("elevator",{"to":floor_number})
	else:
		request_elevator(world.player.position,floor_number)

func apply_elevator_arrival(at: Vector3) -> void:
	if not at.is_finite():
		return
	move_elevator_rider(at)
	refresh = 0.5
	world.camera_check_timer = 0

func move_elevator_rider(at: Vector3) -> void:
	world.player.position = at
	world.player.velocity = Vector3.ZERO

func elevator_interaction(at: Vector3) -> int:
	var building := elevator_building_at(at)
	if building.is_empty():
		return 0
	var state: Dictionary = elevators[building]
	if state.phase in ["travel","closing","opening"]:
		return 1
	return 3 if inside_cabin(at,elevator_origin(building)) else 2

func home_floor_at(at: Vector3) -> int:
	var local := at - HOME_BUILDING
	var floor_number := roundi(local.y / 6.0)-1
	if floor_number < 0 or floor_number >= 12 or absf(local.y - (floor_number+1) * 6.0) > 2.0: return -1
	return floor_number if Vector2(local.x, local.z - 11.0).length() < 2.5 else -1

func buy_home(floor_number: int) -> void:
	if floor_number < 0 or floor_number >= 12: return
	if world.network != null and world.network.active():
		var id: int = world.network.rules.context_peer if world.network.rules.context_peer > 0 else multiplayer.get_unique_id()
		world.network.rules.buy_home(id, floor_number)
		return
	if owned_homes.has(floor_number):
		world.notify("Este apartamento já é seu.")
	elif owned_home >= 0:
		world.notify("Cada jogador pode ter apenas um apartamento.")
	elif world.cash < 1000:
		world.notify("Dinheiro insuficiente: apartamento custa $1000.")
	else:
		world.cash -= 1000
		owned_homes.append(floor_number)
		var previous_home := owned_home
		owned_home = floor_number
		if world.activities.game_mode == "campaign" and not world.activities.save_campaign():
			owned_homes.erase(floor_number)
			owned_home = previous_home
			world.cash += 1000
			return
		world.notify("Apartamento comprado por $1000.")

func prompt() -> String:
	if world.active_car != null:
		return ""
	var at: Vector3 = world.player.position
	var home_floor := home_floor_at(at)
	if home_floor >= 0:
		if world.network != null and world.network.active():
			for id in world.network.rules.sheets:
				if home_floor in world.network.rules.sheets[id].get("homes", []):
					return "Seu apartamento" if id == multiplayer.get_unique_id() else "Apartamento ocupado"
		elif owned_homes.has(home_floor):
			return "Seu apartamento"
		return "F / Comprar apartamento - $1000"
	match elevator_interaction(at):
		1: return "Elevador em movimento"
		2: return "F / Chamar elevador"
		3: return "F / Escolher andar do elevador"
	if near_building_mission(at):
		return task_label()
	var job := building_job_for(building_player_id())
	if not job.is_empty() and at.distance_squared_to(building_destination(job)) < 4.0:
		return "F / Entregar %s (%d/3)" % ["malote" if building_contacts[job.contact][0] == "bank" else "caixa",job.step+1]
	if building_contact_at(at) >= 0:
		return "F / Conversar"
	return ""

func interact() -> bool:
	if world.active_car != null:
		return false
	var at: Vector3 = world.player.position
	var home_floor := home_floor_at(at)
	if home_floor >= 0:
		buy_home(home_floor)
		return true
	var elevator_action := elevator_interaction(at)
	if elevator_action == 1:
		return true
	if elevator_action == 2:
		use_elevator(ELEVATOR_CALL)
		return true
	if elevator_action == 3:
		world.activities.set_menu("elevator")
		var building := elevator_building_at(at)
		var column: VBoxContainer = elevator_ui.get_child(0).get_child(0)
		for i in 13:
			var button: Button = column.get_child(i+1)
			button.visible = i < ELEVATOR_FLOORS[building]
			button.text = "Térreo" if i == 0 else "Andar %02d" % (i if building == "housing" else i+1)
		elevator_ui.show()
		return true
	if near_building_mission(at):
		return true # Holding F advances the work in tick_tasks.
	return false

func near_building_mission(at: Vector3) -> bool:
	var current: int = world.activities.job
	return (TASKS.has(current) or NEW_TASKS.has(current) or current in [24,25,26]) and at.distance_squared_to(mission_position()) < 6.25

func build_contact_dialog() -> void:
	building_dialog = CenterContainer.new()
	building_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	elevator_ui.get_parent().add_child(building_dialog)
	var panel := PanelContainer.new()
	building_dialog.add_child(panel)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 390
	column.add_theme_constant_override("separation",8)
	panel.add_child(column)
	building_title = Label.new()
	building_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(building_title)
	building_choice = Button.new()
	building_choice.custom_minimum_size.y = 56
	building_choice.pressed.connect(func(): submit_building_choice(selected_contact))
	column.add_child(building_choice)
	var close := Button.new()
	close.text = "Sair"
	close.custom_minimum_size.y = 56
	close.pressed.connect(func(): world.activities.set_menu(""); building_dialog.hide())
	column.add_child(close)
	building_dialog.hide()
	building_marker = Label3D.new()
	building_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	building_marker.no_depth_test = true
	building_marker.pixel_size = 0.007
	building_marker.modulate = Color("#ffd778")
	building_marker.hide()
	add_child(building_marker)

func building_player_id() -> int:
	return multiplayer.get_unique_id() if world.network != null and world.network.active() else 1

func building_job_for(id: int) -> Dictionary:
	if world.network != null and world.network.active():
		var sheet: Dictionary = world.network.rules.sheets.get(id,{})
		return sheet.get("building_job",{})
	return offline_building_job

func building_contact_at(at: Vector3) -> int:
	var nearest := -1
	var limit := 9.0
	for index: int in building_contacts:
		var npc: CharacterBody3D = people[index]
		var distance := at.distance_squared_to(npc.position)
		if npc.hp > 0 and distance < limit and absf(at.y-npc.position.y) < 1.5:
			nearest = index
			limit = distance
	return nearest

func building_destination(job: Dictionary) -> Vector3:
	var contact: Array = building_contacts[job.contact]
	return contact[1] + (BANK_WORK_POINTS if contact[0] == "bank" else DELIVERY_POINTS)[job.step]

func interact_building() -> bool:
	if world.active_car != null:
		return false
	var at: Vector3 = world.player.position
	if home_floor_at(at) >= 0 or elevator_interaction(at) != 0 or near_building_mission(at):
		return false
	var job := building_job_for(building_player_id())
	if not job.is_empty() and at.distance_squared_to(building_destination(job)) < 4.0:
		submit_building_choice(-1)
		return true
	var contact := building_contact_at(at)
	if contact < 0:
		return false
	selected_contact = contact
	var offer: Array = BUILDING_OFFERS[building_contacts[contact][0]]
	building_title.text = "%s\n%s" % [offer[0],offer[2]]
	building_choice.text = offer[1]
	world.activities.set_menu("building_contact")
	building_dialog.show()
	return true

func submit_building_choice(contact: int) -> void:
	if world.activities.menu == "building_contact":
		world.activities.set_menu("")
		building_dialog.hide()
	if world.active_car != null:
		return
	if contact >= 0 and building_contact_at(world.player.position) == contact:
		var offer: String = building_contacts[contact][0]
		if offer in ["guns","cars","garage"]:
			if world.activities.nearby_place() == offer:
				world.activities.set_menu(offer)
			return
	if world.network != null and world.network.active():
		world.network.rules.send_action("building_contact",{"contact":contact})
	else:
		apply_building_choice(1,world.player.position,contact)

func apply_building_choice(id: int, at: Vector3, contact: int) -> void:
	var job := building_job_for(id)
	if contact == -1:
		if job.is_empty() or job.remaining <= 0 or at.distance_squared_to(building_destination(job)) >= 4.0:
			return
		job.step += 1
		if job.step == 3:
			job.clear()
			world.cash += BUILDING_REWARD
			world.notify("Serviço concluído · +$%d" % BUILDING_REWARD)
		return
	if contact < 0 or contact != building_contact_at(at):
		return
	match building_contacts[contact][0]:
		"office", "bank":
			if not job.is_empty():
				world.notify("Conclua a entrega em andamento.")
				return
			job.merge({"contact":contact,"step":0,"remaining":BUILDING_JOB_TIME})
			world.notify("Entregue os 3 volumes nos pontos marcados.")
		"cafe": purchase_building_service(20,15.0,"Café servido")
		"clinic": purchase_building_service(100,100.0,"Tratamento concluído")
		"market": purchase_building_service(35,25.0,"Lanche consumido")
		"rest": purchase_building_service(0,20.0,"Você descansou")

func purchase_building_service(price: int, recovery: float, message: String) -> void:
	if world.health >= 100:
		world.notify("Sua vida já está cheia.")
		return
	if not world.activities.spend(price):
		return
	world.health = minf(100,world.health+recovery)
	world.notify(message)

func tick_building_job(id: int, delta: float) -> bool:
	var job := building_job_for(id)
	if job.is_empty():
		return false
	job.remaining -= delta
	if job.remaining > 0:
		return false
	job.clear()
	return true

func tick_tasks(delta: float) -> void:
	var a: Node = world.activities
	if a.ACTION_JOBS.has(a.job):
		task_progress = 0
		return
	var special:bool=a.job in [24,25,26]
	if (not TASKS.has(a.job) and not NEW_TASKS.has(a.job) and not special) or world.active_car!=null or world.player.position.distance_to(mission_position())>2.5 or not world.activity_held() or (special and not world.player.is_crouching):
		task_progress=0
		return
	if special and a.stage==1 and world.network!=null and world.network.active():
		world.network.rules.begin_mission_hack(world.network.rules.context_peer if world.network.rules.context_peer>0 else multiplayer.get_unique_id())
		task_progress=0
		return
	task_progress+=delta
	if task_progress>=(OPERATION_TASK_DURATION if special else BUILDING_TASK_DURATION):
		task_progress=0
		a.stage+=1
		world.extra.play("cash" if not special else "hack",-23)
		if a.stage>=(4 if special else 3):
			a.complete_job()
		else:
			world.notify("Servico concluido. Proxima tarefa marcada no predio.")

func begin_apartment_stair_chase(actor := 0) -> void:
	if stair_chase_started:
		return
	stair_chase_started=true
	var wanted: float = world.heat
	if world.network.active():
		if actor == 0:
			actor = world.network.rules.context_peer
		if actor == 0:
			actor = multiplayer.get_unique_id()
		wanted = world.network.rules.wanted_heat(actor)
	world.raise_heat(maxf(0.0, 65.0 - wanted), actor)
	var route:=apartment_stair_route()
	for i in 3:
		var officer:=preload("res://scripts/officer.gd").new()
		officer.world=world
		officer.mission_stair=true
		officer.set_meta("mission_stair",true)
		officer.mission_stair_route=route.duplicate()
		officer.collision_mask=3
		officer.position=PLACES[2]+[Vector3(-10,0.2,-9),Vector3(-9.5,0.2,-9.5),Vector3(-10.4,0.2,-8.5)][i]
		officer.fire_time=0.0
		world.add_child(officer)
		world.activities.officers.append(officer)
	world.notify("A policia invadiu o residencial. Suba, se esconda ou prepare-se para o confronto!")

func refresh_room_visibility(subject: Vector3) -> void:
	# The exterior shells are separate from these furnished rooms.
	for room in rooms:
		var offset: Vector3 = room.position - subject
		room.visible = absf(offset.y) < 9.0 and Vector2(offset.x, offset.z).length_squared() < 44.0 * 44.0

func _process(delta: float) -> void:
	if elevator_ui != null and world.activities.menu != "elevator":
		elevator_ui.hide()
	if world.activities.menu != "building_contact":
		building_dialog.hide()
	var service := building_job_for(building_player_id())
	building_marker.visible = not service.is_empty() and not world.finished
	if building_marker.visible:
		building_marker.position = building_destination(service) + Vector3.UP * 1.6
		var label := "Entrega %d/3 · %ds" % [service.step+1,ceili(service.remaining)]
		if building_marker.text != label:
			building_marker.text = label
	refresh += delta
	if refresh < 0.5:
		return
	refresh = 0
	var subject: Vector3 = world.subject_position()
	var online: bool = world.network != null and world.network.active()
	if online and world.network.is_client():
		for ped in people:
			ped.visible=ped.hp>0 and ped.position.distance_squared_to(subject)<3600
			ped.model.process_mode=Node.PROCESS_MODE_INHERIT if ped.visible else Node.PROCESS_MODE_DISABLED
			ped.set_physics_process(false)
		refresh_room_visibility(subject)
		return
	var observers: Array[Vector3] = [subject]
	if online and multiplayer.is_server():
		for id in world.network.rules.participants():
			if id != multiplayer.get_unique_id():
				observers.append(world.network.rules.position_of(id))
	var distances := {}
	for ped in people:
		var nearest := INF
		for observer in observers:
			nearest=minf(nearest,ped.position.distance_squared_to(observer))
		distances[ped]=nearest
	var sorted := people.duplicate()
	sorted.sort_custom(func(a,b): return distances[a]<distances[b])
	var active_count := 0
	for ped in sorted:
		var cashier: bool = ped.has_meta("supermarket_cashier")
		var simulate: bool = ped.hp > 0 and distances[ped] < 3600 and (cashier or active_count < 24)
		if simulate and not cashier:
			active_count += 1
		var near: bool = ped.position.distance_squared_to(subject) < 3600 and ped.hp > 0
		ped.visible = near and simulate
		ped.model.process_mode=Node.PROCESS_MODE_INHERIT if ped.visible else Node.PROCESS_MODE_DISABLED
		ped.set_physics_process(simulate and not ped.stationary)
	refresh_room_visibility(subject)
