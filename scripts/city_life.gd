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
var leisure_cooldown := 0.0
var elevator_ui: Control
var apartment_elevator_doors: Array = []
var elevator_traveling := false
var elevator_arrival_received := false
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
	apartment_elevator_doors.resize(10)
	for floor_number in 10:
		var room: Node = rooms[2 if floor_number == 0 else floor_number + 5]
		apartment_elevator_doors[floor_number] = [room.get_node("ElevatorLeft"), room.get_node("ElevatorRight")]
	build_elevator_menu()
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
		people.append(ped)
	for i in 3:
		var staff := Pedestrian.new()
		staff.world = world
		staff.appearance_index = i+2
		staff.stationary = true
		staff.tint = Color("93a5b0")
		add_child(staff)
		staff.position = world.activities.bank.to_global(Vector3(-9+i*3,0,-1.6))
		people.append(staff)

	for i in PLACES.size():
		var contact := Pedestrian.new()
		contact.world = world
		contact.appearance_index = i+3
		contact.stationary = true
		contact.tint = Color("a6b19c")
		add_child(contact)
		contact.position = PLACES[i]+Vector3(1,0,5)
		people.append(contact)

func apartment_stair_route() -> Array[Vector3]:
	var route: Array[Vector3]=[]
	for floor_number in 9:
		var base:=PLACES[2]+Vector3(0,floor_number*6,0)
		route.append_array([base+Vector3(-8,1.5,-9),base+Vector3(-6,3,-9),base+Vector3(-6,3,-8),base+Vector3(-8,4.5,-7),base+Vector3(-10,6,-7)])
	return route

func apartment_tenth_floor_occupied() -> bool:
	if world.network!=null and world.network.active():
		for id in world.network.rules.participants():
			if on_apartment_tenth_floor(world.network.rules.position_of(id)):
				return true
		return false
	return on_apartment_tenth_floor(world.player.position)

func on_apartment_tenth_floor(at: Vector3) -> bool:
	var local:=at-PLACES[2]
	return local.y>=54.0 and local.y<59.8 and absf(local.x)<12.0 and absf(local.z)<12.0

func elevator_building_at(at: Vector3) -> String:
	var housing := at - HOME_BUILDING
	if Vector2(housing.x - 8, housing.z + 6.5).length_squared() < 9.0 and housing.y >= -0.5 and housing.y < 78.0: return "housing"
	var apartment:=at-PLACES[2]
	if Vector2(apartment.x-8,apartment.z+6.7).length_squared()<9.0 and apartment.y>=-0.5 and apartment.y<60.0:
		return "apartment"
	var tower:=at-PLACES[5]
	if Vector2(tower.x-8,tower.z-9.0).length_squared()<9.0 and tower.y>=-0.5 and tower.y<48.0:
		return "tower"
	return ""

func elevator_position(building: String, floor_number: int) -> Vector3:
	if building == "housing": return HOME_BUILDING + Vector3(8,floor_number*6+0.2,-6.5)
	return (PLACES[2] if building=="apartment" else PLACES[5])+Vector3(8,floor_number*6+0.2,-6.7 if building=="apartment" else 9.0)

func mission_position() -> Vector3:
	var a: Node = world.activities
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
		button.text = "Terreo / Recepcao" if floor_number == 0 else "Andar %02d" % floor_number
		button.custom_minimum_size.y = 32
		button.pressed.connect(use_elevator.bind(floor_number))
		column.add_child(button)
	var close := Button.new()
	close.text = "Voltar"
	close.pressed.connect(func(): elevator_ui.hide(); world.activities.set_menu(""))
	column.add_child(close)
	elevator_ui.hide()

func use_elevator(floor_number: int) -> void:
	if elevator_traveling:
		return
	var building:=elevator_building_at(world.player.position)
	if building=="" or floor_number<0 or floor_number>(12 if building=="housing" else 11):
		world.notify("Aproxime-se do elevador para escolher um andar.")
		return
	var apartment:=building=="apartment"
	var base:Vector3=HOME_BUILDING if building=="housing" else (PLACES[2] if apartment else PLACES[5])
	if (building=="tower" and floor_number>7) or (apartment and floor_number>9):
		world.notify("Este elevador atende os andares 1 a %d." % (10 if apartment else 8))
		return
	var current_floor:=clampi(roundi((world.player.position.y-base.y)/6.0),0,12 if building=="housing" else (9 if apartment else 7))
	elevator_traveling=true
	elevator_ui.hide()
	if apartment:
		set_elevator_doors(current_floor,true)
		set_elevator_doors(floor_number,true)
	if world.network!=null and world.network.is_client():
		elevator_arrival_received=false
	announce_elevator_trip(current_floor,floor_number,building)
	if world.network!=null and world.network.is_client():
		await get_tree().create_timer(1.5,true).timeout
		if apartment:
			set_elevator_doors(current_floor,false)
			set_elevator_doors(floor_number,false)
		if not elevator_arrival_received:
			world.notify("O elevador nao respondeu. Tente novamente.")
		world.activities.set_menu("")
		elevator_traveling=false
		return
	if apartment:
		await get_tree().create_timer(0.35,true).timeout
	world.player.position=elevator_position(building,floor_number)
	world.player.velocity = Vector3.ZERO
	refresh=0.5
	world.camera_check_timer = 0
	world.notify("Elevador / andar %02d" % (floor_number+1))
	if apartment:
		await get_tree().create_timer(0.55,true).timeout
		set_elevator_doors(current_floor,false)
		set_elevator_doors(floor_number,false)
	world.activities.set_menu("")
	elevator_traveling=false

func set_elevator_doors(floor_number: int, open: bool) -> void:
	if floor_number<0 or floor_number>=apartment_elevator_doors.size() or apartment_elevator_doors[floor_number]==null:
		return
	for index in 2:
		var door: MeshInstance3D=apartment_elevator_doors[floor_number][index]
		var closed: Vector3=door.get_meta("closed_position")
		var offset:float=(-0.68 if index==0 else 0.68) if open else 0.0
		var tween:=door.create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_property(door,"position",closed+Vector3(offset,0,0),0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func announce_elevator_trip(source: int, destination: int, building: String) -> void:
	if world.network==null or not world.network.active():
		return
	if multiplayer.is_server():
		for id in world.network.members:
			if id!=1:
				world.network.personal.rpc_id(id,"elevator",{"actor":1,"from":source,"to":destination,"building":building,"position":elevator_position(building,destination)})
	else:
		world.network.rules.send_action("elevator",{"from":source,"to":destination})

func apply_elevator_arrival(at: Vector3) -> void:
	if not at.is_finite():
		return
	world.player.position=at
	world.player.velocity=Vector3.ZERO
	refresh=0.5
	world.camera_check_timer=0
	elevator_arrival_received=true

func animate_remote_elevator(source: int, destination: int) -> void:
	set_elevator_doors(source,true)
	set_elevator_doors(destination,true)
	await get_tree().create_timer(0.85,true).timeout
	set_elevator_doors(source,false)
	set_elevator_doors(destination,false)

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
	if elevator_building_at(at)!="":
		return "F / Escolher andar do elevador"
	if (TASKS.has(world.activities.job) or NEW_TASKS.has(world.activities.job) or world.activities.job in [24,25,26]) and at.distance_to(mission_position())<2.5:
		return task_label()
	if inside_room(at):
		if absf(at.x - HOME_BUILDING.x) < 12 and absf(at.z - HOME_BUILDING.z) < 12 and at.y >= 0 and at.y < 78: return ""
		return "F / Atendimento, descanso ou servico local"
	return ""

func interact() -> bool:
	if world.active_car != null:
		return false
	var at: Vector3 = world.player.position
	var home_floor := home_floor_at(at)
	if home_floor >= 0:
		buy_home(home_floor)
		return true
	if elevator_building_at(at)!="":
		world.activities.set_menu("elevator")
		var building := elevator_building_at(at)
		var column: VBoxContainer = elevator_ui.get_child(0).get_child(0)
		for i in 13:
			var button: Button = column.get_child(i+1)
			button.visible = i <= (12 if building == "housing" else (9 if building == "apartment" else 7))
			button.text = ("Terreo / Recepcao" if i == 0 else "Andar %02d" % i) if building == "housing" else "Andar %02d" % (i+1)
		elevator_ui.show()
		return true
	if (TASKS.has(world.activities.job) or NEW_TASKS.has(world.activities.job) or world.activities.job in [24,25,26]) and at.distance_to(mission_position())<2.5:
		return true # Holding F advances the work in tick_tasks.
	if leisure_cooldown>0:
		return false
	for i in PLACES.size():
		if (at-PLACES[i]).length()<10:
			leisure_cooldown = 8
			match i:
				0:
					if world.cash>=20:
						world.cash-=20
						world.health=minf(100,world.health+15)
						world.notify("Cafe servido / +15 de vida / $20")
				1:
					if world.cash>=100:
						world.cash-=100
						world.health=100
						world.notify("Atendimento concluido / vida cheia / $100")
				2:
					world.health=minf(100,world.health+20)
					world.notify("Descansou no residencial / +20 de vida")
				_:
					if world.activities.game_mode == "sandbox" and world.activities.job < 0:
						world.activities.start_job({3:7,4:10,5:11}[i])
					else:
						world.notify("Conclua seu contrato atual para iniciar outro servico.")
			return true
	return false

func tick_leisure(delta: float) -> void:
	leisure_cooldown=maxf(0,leisure_cooldown-delta)

func tick_tasks(delta: float) -> void:
	var a: Node = world.activities
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

func begin_apartment_stair_chase() -> void:
	if stair_chase_started:
		return
	stair_chase_started=true
	world.heat=maxf(world.heat,65.0)
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
	var inside_tower := -1
	if world.active_car==null:
		for index in [2,5]:
			var local: Vector3=subject-PLACES[index]
			if absf(local.x)<12.2 and absf(local.z)<11.7 and local.y>=-0.5 and local.y<(60.0 if index==2 else 48.0):
				inside_tower=index
				break
	for room in rooms:
		var offset: Vector3=room.position-subject
		var near: bool=offset.x*offset.x+offset.z*offset.z<10000.0
		if near and inside_tower>=0 and room.position.x==PLACES[inside_tower].x and room.position.z==PLACES[inside_tower].z:
			near=absf(offset.y)<9.0
		room.visible=near

func _process(delta: float) -> void:
	if elevator_ui != null and world.activities.menu != "elevator":
		elevator_ui.hide()
	refresh += delta
	if refresh < 0.5:
		return
	refresh = 0
	if world.network!=null and world.network.active() and world.network.is_client():
		var subject: Vector3=world.subject_position()
		for ped in people:
			ped.visible=ped.hp>0 and ped.position.distance_squared_to(subject)<3600
			ped.model.process_mode=Node.PROCESS_MODE_INHERIT if ped.visible else Node.PROCESS_MODE_DISABLED
			ped.set_physics_process(false)
		refresh_room_visibility(subject)
		return
	var observers: Array[Vector3]=[world.subject_position()]
	if world.network!=null and world.network.active() and multiplayer.is_server():
		for id in world.network.rules.participants():
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
		var simulate: bool=ped.hp>0 and distances[ped]<3600 and active_count<[24,20,16,12,10][world.settings.quality]
		if simulate:
			active_count+=1
		var near: bool=ped.position.distance_squared_to(world.subject_position())<3600 and ped.hp>0
		ped.visible=near and (simulate or (world.network!=null and world.network.is_client()))
		ped.model.process_mode=Node.PROCESS_MODE_INHERIT if ped.visible else Node.PROCESS_MODE_DISABLED
		ped.set_physics_process(simulate and not ped.stationary and not (world.network!=null and world.network.is_client()))
	refresh_room_visibility(world.subject_position())
