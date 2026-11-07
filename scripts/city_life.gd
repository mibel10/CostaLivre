extends Node3D

const Pedestrian = preload("res://scripts/pedestrian.gd")
const Design = preload("res://scripts/interior_design.gd")
const PLACES := [Vector3(-63,0,21),Vector3(63,0,21),Vector3(-63,0,63),Vector3(-105,0,-21),Vector3(105,0,-63),Vector3(147,0,63)]
const TITLES := ["CAFÉ MARÉ", "CLÍNICA COSTA", "RESIDENCIAL COSTA", "OFICINA DO PORTO", "MERCADO DA PRAIA", "ESTÚDIO SOLAR"]
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
const WORK_POINTS := [Vector3(-4,0,4),Vector3(4,0,1),Vector3(0,0,-6)]

func _ready() -> void:
	apartment_elevator_doors.resize(10)
	for i in PLACES.size():
		build_room(i)
	for floor_number in range(1,10):
		build_room(2,floor_number)
	for floor_number in range(1,8):
		build_room(5,floor_number)
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

func build_room(index: int, floor_number := 0) -> void:
	var room := Node3D.new()
	room.position = PLACES[index]+Vector3(0,floor_number*6,0)
	add_child(room)
	rooms.append(room)
	var colors := [Color("8e6246"),Color("789999"),Color("8c8b79")]
	var floor_color: Color=colors[index%3]
	var floor_material: Material=world.material([Color("84694e"),Color("a9b6b2"),Color("96846b")][index%3])
	if index==2 and floor_number>0:
		build_stairwell_floor(room,Vector3(0,-0.2,0),Vector3(25,0.2,24),floor_color,true)
		build_stairwell_floor(room,Vector3(0,-0.075,0),Vector3(24.5,0.02,23.5),floor_color,false,floor_material)
	else:
		world.box(room,Vector3(0,-0.2,0),Vector3(25,0.2,24),floor_color,true)
		var floor_visual: MeshInstance3D = world.box(room,Vector3(0,-0.075,0),Vector3(24.5,0.02,23.5),floor_color)
		floor_visual.material_override=floor_material
	if index!=2 or floor_number==9:
		world.box(room,Vector3(0,5.8,0),Vector3(25,0.2,24),Color("bcc0b5"),true)
	for side in [-1,1]:
		world.box(room,Vector3(side*12.4,2.9,0),Vector3(0.3,5.8,24),colors[index%3],true)
		world.box(room,Vector3(side*7.5,2.9,11.8),Vector3(9,5.8,0.3),colors[index%3],true)
	world.box(room,Vector3(0,2.9,-11.8),Vector3(25,5.8,0.3),colors[index%3],true)
	world.box(room,Vector3(0,4.8,11.8),Vector3(6,2,0.3),colors[index%3],true)
	if index == 2:
		for side in [-1,1]:
			for pane in [-7,0,7]:
				world.box(room,Vector3(side*12.58,3,pane),Vector3(0.04,1.7,2.5),Color("67979d"))
	if floor_number > 0:
		world.box(room,Vector3(0,1.3,11.8),Vector3(6,2.6,0.3),Color("56717a"),true)
	var title: String = TITLES[index]
	world.sign_text(("RESIDENCIAL COSTA / ANDAR %d" % (floor_number+1)) if index == 2 else title,room.position+Vector3(0,4.8,12.1))
	if index == 3:
		world.box(room,Vector3(-7,0.9,-7),Vector3(7,0.16,1.7),Color("675443"),true)
		for x in [-9,-5]:
			world.box(room,Vector3(x,0.4,-7),Vector3(0.15,0.8,1.5),Color("36434a"),true)
		for x in [-9,-7,-5]:
			world.box(room,Vector3(x,1.2,-7),Vector3(0.8,0.5,0.5),Color("a64636"))
		world.box(room,Vector3(8,1.3,-8),Vector3(3,2.6,1.5),Color("3b5961"),true)
	elif index == 4:
		for x in [-7,7]:
			for z in [-6,0]:
				world.box(room,Vector3(x,1,z),Vector3(3,2,1.2),Color("3d5557"),true)
				for shelf in 3:
					for product in 4:
						world.box(room,Vector3(x-1.1+product*0.7,0.5+shelf*0.65,z+0.67),Vector3(0.4,0.4,0.22),[Color("c99951"),Color("809a65"),Color("b35e49")][shelf])
		world.box(room,Vector3(-7,0.7,7),Vector3(5,1.4,1.2),Color("6d5240"),true)
	elif index == 0:
		world.box(room,Vector3(-7,0.7,-7),Vector3(6,1.4,1.3),Color("593c2c"),true)
		for x in [-5,5]:
			for z in [-3,5]:
				Design.cylinder(world,room,Vector3(x,0.9,z),1.1,0.12,Color("7c523a"))
				Design.cylinder(world,room,Vector3(x,0.45,z),0.12,0.9,Color("34444b"))
				Design.chair(world,room,Vector3(x,0,z+1.5))
	elif index == 1:
		world.box(room,Vector3(-7,0.6,-7),Vector3(6,1.2,1.3),Color("385a60"),true)
		for x in [-6,6]:
			world.box(room,Vector3(x,0.6,0),Vector3(2,0.3,3.5),Color("c4d5ce"),true)
			world.box(room,Vector3(x,0.9,-1),Vector3(1.5,0.22,0.6),Color("e6e4d3"))
	elif index == 5:
		world.sign_text("DATA CENTER / ACESSO RESTRITO",room.position+Vector3(0,3.4,-11.4))
		for x in [-8,-4,0,4,8]:
			world.box(room,Vector3(x,1.65,-7),Vector3(2.2,3.3,1.6),Color("263d4b"),true)
			for y in [0.65,1.15,1.65,2.15,2.65]:
				world.box(room,Vector3(x-0.68,y,-6.16),Vector3(0.12,0.08,0.04),Color("71d5c2"),false,true)
		world.box(room,Vector3(0,1.05,0),Vector3(4.4,0.14,1.2),Color("26333c"),true)
		world.box(room,Vector3(0,1.5,-0.45),Vector3(1.1,0.72,0.08),Color("37b99c"),false,true)
	else:
		world.box(room,Vector3(-6,0.5,-4),Vector3(3,0.8,4),Color("52766b"),true)
		world.box(room,Vector3(6,0.5,-3),Vector3(4,1,1.2),Color("715c44"),true)
		world.box(room,Vector3(0,0.8,-10),Vector3(5,1.6,0.5),Color("22333d"))
	world.box(room,Vector3(0,5.5,0),Vector3(3,0.08,0.4),Color("fff1ca"),false,true)
	for i in WORK_POINTS.size():
		world.box(room,WORK_POINTS[i]+Vector3(0,0.65,0),Vector3(1.2,1.3,0.7),Color("376b70"),true)
		world.box(room,WORK_POINTS[i]+Vector3(0,1.4,0),Vector3(0.7,0.3,0.15),Color("7cd3b4"),false,true)
	if index in [2,5]:
		if index==2:
			build_apartment_elevator(room,floor_number)
		else:
			world.box(room,Vector3(8,1.4,7.8),Vector3(3,2.8,0.2),Color("4c6570"))
			world.box(room,Vector3(10,1.2,8),Vector3(0.25,0.5,0.2),Color("d6b56e"))
			world.sign_text("F / ELEVADOR / TORRE",room.position+Vector3(8,3,8))
	if index==2 and floor_number<9:
		build_apartment_stairs(room)
	world.batch_city_geometry(room)

func build_stairwell_floor(parent: Node3D, center: Vector3, size: Vector3, color: Color, solid: bool, floor_material: Material = null) -> void:
	var left: float=-size.x/2
	var right: float=size.x/2
	var back: float=-size.z/2
	var front: float=size.z/2
	var pieces: Array=[
		[Vector3((left-11.0)/2,center.y,0),Vector3(-11.0-left,size.y,size.z)],
		[Vector3((-5.0+right)/2,center.y,0),Vector3(right+5.0,size.y,size.z)],
		[Vector3(-8.0,center.y,(back-10.0)/2),Vector3(6.0,size.y,-10.0-back)],
		[Vector3(-8.0,center.y,(-6.0+front)/2),Vector3(6.0,size.y,front+6.0)]
	]
	for piece in pieces:
		var floor_piece: MeshInstance3D=world.box(parent,piece[0],piece[1],color,solid)
		if floor_material!=null:
			floor_piece.material_override=floor_material

func build_apartment_stairs(room: Node3D) -> void:
	var wood:=Color("77644f")
	var flight_one: MeshInstance3D=world.box(room,Vector3(-8,1.5,-9),Vector3(4.9,0.22,2.1),Color("62666a"),true)
	flight_one.rotation.z=atan2(3.0,4.8)
	var flight_two: MeshInstance3D=world.box(room,Vector3(-8,4.5,-7),Vector3(4.9,0.22,2.1),Color("62666a"),true)
	flight_two.rotation.z=-atan2(3.0,4.8)
	world.box(room,Vector3(-6,3.02,-8),Vector3(1.8,0.2,2.4),Color("62666a"),true)
	for step in 11:
		world.box(room,Vector3(-10.1+step*0.4,0.14+step*0.28,-9),Vector3(0.42,0.16,1.9),wood)
		world.box(room,Vector3(-6.0-step*0.4,3.14+step*0.28,-7),Vector3(0.42,0.16,1.9),wood)
	for side in [-1.0,1.0]:
		var rail_one: MeshInstance3D=world.box(room,Vector3(-8,1.92,-9+side),Vector3(4.9,0.08,0.08),Color("a38c69"))
		rail_one.rotation.z=atan2(3.0,4.8)
		var rail_two: MeshInstance3D=world.box(room,Vector3(-8,4.92,-7+side),Vector3(4.9,0.08,0.08),Color("a38c69"))
		rail_two.rotation.z=-atan2(3.0,4.8)

func build_apartment_elevator(room: Node3D, floor_number: int) -> void:
	world.box(room,Vector3(8,1.45,-11.05),Vector3(4.0,2.9,0.2),Color("303c43"),true)
	for side in [-1.0,1.0]:
		world.box(room,Vector3(8+side*1.95,1.45,-9.35),Vector3(0.2,2.9,3.6),Color("59676b"),true)
	world.box(room,Vector3(8,1.4,-8.08),Vector3(2.75,2.55,0.08),Color("151d21"))
	world.box(room,Vector3(8,2.92,-7.88),Vector3(3.7,0.22,0.2),Color("b0a17f"))
	for side in [-1.0,1.0]:
		world.box(room,Vector3(8+side*1.82,1.4,-7.88),Vector3(0.18,2.8,0.2),Color("b0a17f"))
	var left_door: MeshInstance3D=world.box(room,Vector3(7.3,1.4,-7.86),Vector3(1.34,2.56,0.14),Color("829093"))
	var right_door: MeshInstance3D=world.box(room,Vector3(8.7,1.4,-7.86),Vector3(1.34,2.56,0.14),Color("829093"))
	for door in [left_door,right_door]:
		door.set_meta("keep_mesh",true)
		door.set_meta("closed_position",door.position)
		var inset: MeshInstance3D=world.box(door,Vector3(0,0,0.09),Vector3(0.08,2.25,0.025),Color("aab2ac"))
		inset.set_meta("keep_mesh",true)
	apartment_elevator_doors[floor_number]=[left_door,right_door]
	world.box(room,Vector3(10.15,1.5,-7.8),Vector3(0.45,0.88,0.16),Color("25343a"))
	world.box(room,Vector3(10.15,1.88,-7.69),Vector3(0.25,0.18,0.035),Color("79d2ba"),false,true)
	for button in 3:
		world.box(room,Vector3(10.15,1.52-button*0.22,-7.67),Vector3(0.12,0.12,0.035),Color("d5bd8d"),false,true)
	world.sign_text("ELEVADOR / ANDAR %02d" % (floor_number+1),room.position+Vector3(8,3.45,-7.8))

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
	var apartment:=at-PLACES[2]
	if Vector2(apartment.x-8,apartment.z+6.7).length_squared()<9.0 and apartment.y>=-0.5 and apartment.y<60.0:
		return "apartment"
	var tower:=at-PLACES[5]
	if Vector2(tower.x-8,tower.z-9.0).length_squared()<9.0 and tower.y>=-0.5 and tower.y<48.0:
		return "tower"
	return ""

func elevator_position(building: String, floor_number: int) -> Vector3:
	return (PLACES[2] if building=="apartment" else PLACES[5])+Vector3(8,floor_number*6+0.2,-6.7 if building=="apartment" else 9.0)

func mission_position() -> Vector3:
	var a: Node = world.activities
	if a.job>=17:
		var floors: Array = {17:[2,5,3],18:[4,6,1],19:[7,5,3]}[a.job]
		if a.stage>=3:
			return PLACES[5]+Vector3(0,0,17)
		return PLACES[5]+Vector3(0,floors[a.stage]*6,0)+WORK_POINTS[a.stage%WORK_POINTS.size()]
	if not TASKS.has(a.job):
		return Vector3.ZERO
	var task: Array = TASKS[a.job]
	return PLACES[task[0]]+Vector3(0,task[1]*6,0)+WORK_POINTS[mini(a.stage,2)]

func task_label() -> String:
	var a: Node = world.activities
	if a.job>=17:
		var tasks: Array={17:["Desativar cameras","Hackear o servidor central","Baixar arquivos do mainframe","Sair do predio sem ser visto"],18:["Entrar agachado no controle","Hackear o sistema de acesso","Copiar a chave-mestra","Escapar da equipe policial"],19:["Achar o terminal no setimo andar","Invadir o servidor protegido","Apagar os rastros digitais","Descer e sumir da busca"]}[a.job]
		return "%s / %d%% / agache (Z) e segure F" % [tasks[a.stage],roundi(task_progress/OPERATION_TASK_DURATION*100)]
	if not TASKS.has(a.job):
		return "Explore a cidade"
	var task: Array = TASKS[a.job]
	return "%s / %d%% / segure F" % [task[2+mini(a.stage,2)],roundi(task_progress/BUILDING_TASK_DURATION*100)]

func inside_room(at: Vector3) -> bool:
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
	panel.position = Vector2(-220,-250)
	panel.size = Vector2(440,500)
	elevator_ui.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	var title := Label.new()
	title.text = "ESCOLHA O ANDAR / ELEVADOR"
	column.add_child(title)
	for floor_number in 10:
		var button := Button.new()
		button.text = "Andar %02d" % (floor_number+1)
		button.custom_minimum_size.y = 36
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
	if building=="" or floor_number<0 or floor_number>9:
		world.notify("Aproxime-se do elevador para escolher um andar.")
		return
	var apartment:=building=="apartment"
	var base:Vector3=PLACES[2] if apartment else PLACES[5]
	if not apartment and floor_number>7:
		world.notify("Este elevador atende os andares 1 a 8.")
		return
	var current_floor:=clampi(roundi((world.player.position.y-base.y)/6.0),0,9 if apartment else 7)
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

func prompt() -> String:
	if world.active_car != null:
		return ""
	var at: Vector3 = world.player.position
	if elevator_building_at(at)!="":
		return "F / Escolher andar do elevador"
	if (TASKS.has(world.activities.job) or world.activities.job>=17) and at.distance_to(mission_position())<2.5:
		return task_label()
	if inside_room(at):
		return "F / Atendimento, descanso ou servico local"
	return ""

func interact() -> bool:
	if world.active_car != null:
		return false
	var at: Vector3 = world.player.position
	if elevator_building_at(at)!="":
		world.activities.set_menu("elevator")
		elevator_ui.show()
		return true
	if (TASKS.has(world.activities.job) or world.activities.job>=17) and at.distance_to(mission_position())<2.5:
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
	var special:bool=a.job>=17
	if (not TASKS.has(a.job) and not special) or world.active_car!=null or world.player.position.distance_to(mission_position())>2.5 or not world.activity_held() or (special and not world.player.is_crouching):
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
