extends Node

const INVENTORY := ["weapon","rifle_owned","shotgun_owned","smg_owned","heavy_owned","purchased_cars","clips","reserves","fire_cooldown","reload_time","reload_weapon"]
var world: Node3D
var network: Node
var sheets := {}
var context_peer := 0
var bus_riders := {}
var robbery_worker := 0
var attacker := 0
var bank_owner := 1
var last_actions := {}
var shot_send := 0
var spawn_cursor := 0
var local_body: CharacterBody3D
var pending_mission := -1
var mission_offer_deadline := 0
var mission_offer_from := 0
var mission_offer_started := false
var mission_invites := {}
var police_sight_clock := 0.0
var visible_police: Array = []
var mission_hacking_peer := 0
var mission_pattern: Array[int] = []
var mission_entered := 0
var mission_round := 0
var mission_mistakes := 0
var mission_reveal_time := 0.0
var mission_round_time := 0.0

func _ready() -> void:
	local_body=world.player

func local_id() -> int:
	return multiplayer.get_unique_id()

func inventory() -> Dictionary:
	var result := {}
	for key in INVENTORY:
		var value = world.activities.get(key)
		result[key]=value.duplicate() if value is Array else value
	return result

func add_peer(id: int) -> Vector3:
	var inv := {"weapon":1,"rifle_owned":false,"shotgun_owned":false,"smg_owned":false,"heavy_owned":[false,false,false],"purchased_cars":[],"clips":[0,12,0,0,0,0,0,0],"reserves":[0,36,0,0,0,0,0,0],"fire_cooldown":0.0,"reload_time":0.0,"reload_weapon":0}
	sheets[id]={"health":100.0,"cash":900,"inventory":inv,"dead_until":0,"protected_until":Time.get_ticks_msec()+5000,"life":0,"home":-1,"homes":[],"building_job":{}}
	if id==1:
		sheets[id].cash=world.cash
		sheets[id].inventory=inventory()
	var at := next_spawn()
	network.members[id]={"position":at,"car_position":at,"heading":0.0,"car_heading":0.0,"speed":0.0,"car":-1,"name":"Jogador","outfit":0,"held":false,"crouch":false,"arrest_progress":0.0}
	if id==local_id():
		world.player.set_meta("peer_id",id)
	return at

func next_spawn() -> Vector3:
	for attempt in world.SPAWNS.size():
		var at: Vector3=world.SPAWNS[spawn_cursor%world.SPAWNS.size()]
		spawn_cursor+=1
		var clear := true
		for state in network.members.values():
			if not state.is_empty() and at.distance_to(state.car_position)<4:
				clear=false
		for car in world.cars:
			if at.distance_to(car.position)<(15 if car.police and car.police_phase!="parked" else 3):
				clear=false
		if clear:
			return at
	return world.SPAWNS[spawn_cursor%world.SPAWNS.size()]

func is_dead(id: int) -> bool:
	return sheets.has(id) and float(sheets[id].health)<=0

func participants() -> Array:
	var result: Array=[]
	for id in network.members:
		if not is_dead(id) and not network.members[id].is_empty():
			result.append(id)
	return result

func wanted_participants() -> Array:
	return participants().filter(func(id): return not bool(sheets.get(id, {}).get("wanted_reset", false)))

func wanted_heat(id: int) -> float:
	return 0.0 if bool(sheets.get(id, {}).get("wanted_reset", false)) else world.heat

func position_of(id: int) -> Vector3:
	if id==local_id():
		return world.subject_position() if context_peer in [0,local_id()] else network.members.get(id,{}).get("car_position",local_body.position)
	return network.members.get(id,{}).get("car_position",Vector3.ZERO)

func nearest_player(at: Vector3) -> Array:
	var selected := 1
	var distance := INF
	for id in participants():
		var current := at.distance_squared_to(position_of(id))
		if current<distance:
			distance=current
			selected=id
	return [selected,position_of(selected)]

func target_crouched(at: Vector3) -> bool:
	for id in participants():
		if position_of(id).distance_to(at)<2.5 and bool(network.members[id].get("crouch",false)):
			return true
	return false

func local_mission_hacking() -> bool:
	return network.active() and mission_hacking_peer==local_id()

func new_mission_round() -> void:
	mission_pattern.clear()
	for i in 3+mission_round:
		mission_pattern.append(world.rng.randi_range(1,4))
	mission_entered=0
	mission_reveal_time=2.2
	mission_round_time=14.0

func begin_mission_hack(id: int) -> void:
	if mission_hacking_peer!=0 or world.activities.job<24 or world.activities.stage!=1:
		return
	if not held(id) or int(network.members[id].get("car",-1))>=0 or not bool(network.members[id].get("crouch",false)):
		return
	mission_hacking_peer=id
	mission_round=0
	mission_mistakes=0
	new_mission_round()
	private_notice(id,"Terminal seguro: memorize a sequencia e repita os tres circuitos.")

func fail_mission_hack() -> void:
	mission_mistakes+=1
	world.raise_heat(6)
	if mission_mistakes>=3:
		private_notice(mission_hacking_peer,"Falha no terminal. O alarme foi acionado; tente novamente.")
		world.raise_heat(25)
		mission_hacking_peer=0
		mission_mistakes=0
		return
	private_notice(mission_hacking_peer,"Sequencia incorreta (%d/3)." % mission_mistakes)
	new_mission_round()

func enter_mission_digit(id: int,digit: int) -> void:
	if id!=mission_hacking_peer or mission_reveal_time>0 or digit<1 or digit>4:
		return
	if digit!=mission_pattern[mission_entered]:
		fail_mission_hack()
		return
	mission_entered+=1
	if mission_entered<mission_pattern.size(): return
	mission_round+=1
	if mission_round<3:
		new_mission_round()
	else:
		mission_hacking_peer=0
		mission_mistakes=0
		world.activities.stage=2
		world.extra.play("hack")
		private_notice(id,"Servidor invadido. Baixe os arquivos e depois saia sem ser visto.")

func tick_mission_hack(delta: float) -> void:
	if mission_hacking_peer==0: return
	if not sheets.has(mission_hacking_peer) or is_dead(mission_hacking_peer) or world.activities.job<24 or world.activities.stage!=1:
		mission_hacking_peer=0
		return
	mission_reveal_time=maxf(0,mission_reveal_time-delta)
	if mission_reveal_time<=0:
		mission_round_time-=delta
		if mission_round_time<=0:
			fail_mission_hack()

func police_target_actor(at: Vector3) -> Array:
	var selected: Array=[]
	var closest:=INF
	for id in wanted_participants():
		var candidate:Vector3=position_of(id)
		var distance:=at.distance_squared_to(candidate)
		if bool(network.members[id].get("crouch",false)) and distance>=64:
			continue
		if distance<closest:
			selected=[id,candidate]
			closest=distance
	return selected if not selected.is_empty() else nearest_player(at)

func police_target(at: Vector3) -> Vector3:
	return police_target_actor(at)[1]

func held(id: int) -> bool:
	return (Input.is_action_pressed("activity") and world.activities.menu=="") if id==local_id() else bool(network.members.get(id,{}).get("held",false))

func with_actor(id: int, callback: Callable) -> void:
	if not sheets.has(id):
		return
	var previous_context := context_peer
	context_peer=id
	if id==local_id():
		callback.call()
		sheets[id].health=world.health
		sheets[id].cash=world.cash
		sheets[id].inventory=inventory()
		context_peer=previous_context
		return
	if not network.avatars.has(id):
		context_peer=previous_context
		return
	if sheets.has(local_id()):
		sheets[local_id()].cash=world.cash
		sheets[local_id()].health=world.health
	var saved := {"player":world.player,"car":world.active_car,"cash":world.cash,"health":world.health,"inventory":inventory(),"menu":world.activities.menu,"car_page":world.activities.car_page}
	world.player=network.avatars[id].node
	world.active_car=world.car_by_id(int(network.members[id].get("car",-1)))
	world.cash=sheets[id].cash
	world.health=sheets[id].health
	for key in INVENTORY:
		world.activities.set(key,sheets[id].inventory[key])
	callback.call()
	sheets[id].cash=world.cash
	sheets[id].health=world.health
	sheets[id].inventory=inventory()
	world.player=saved.player
	world.active_car=saved.car
	world.cash=sheets.get(local_id(),{}).get("cash",saved.cash)
	world.health=sheets.get(local_id(),{}).get("health",saved.health)
	world.activities.menu=saved.menu
	world.activities.car_page=saved.car_page
	for key in INVENTORY:
		world.activities.set(key,saved.inventory[key])
	context_peer=previous_context

func private_notice(id: int, text: String) -> void:
	if id==local_id():
		world.toast=text
		world.toast_time=5
	else:
		network.personal.rpc_id(id,"notice",{"text":text})

func award(id: int, amount: int) -> void:
	if not sheets.has(id):
		return
	if id==(context_peer if context_peer>0 else local_id()):
		world.cash+=amount
	else:
		sheets[id].cash+=amount
		if id==local_id() and context_peer in [0,local_id()]:
			world.cash=sheets[id].cash

func notice_all(text: String) -> void:
	for id in sheets:
		private_notice(id,text)

func award_all(amount: int) -> void:
	for id in sheets:
		award(id,amount)

func buy_home(id: int, floor_number: int) -> void:
	if not multiplayer.is_server() or not sheets.has(id) or int(network.members[id].get("car", -1)) >= 0 or world.life.home_floor_at(position_of(id)) != floor_number: return
	if floor_number in sheets[id].get("homes", []):
		private_notice(id,"Este apartamento já é seu.")
		return
	if int(sheets[id].get("home", -1)) >= 0:
		private_notice(id,"Cada jogador pode ter apenas um apartamento.")
		return
	for peer_id in sheets:
		if floor_number in sheets[peer_id].get("homes", []):
			private_notice(id,"Este apartamento já tem dono.")
			return
	if world.cash < 1000:
		private_notice(id,"Dinheiro insuficiente: apartamento custa $1000.")
		return
	world.cash -= 1000
	sheets[id]["homes"].append(floor_number)
	sheets[id]["home"] = floor_number
	private_notice(id,"Apartamento comprado por $1000.")

func send_action(kind: String, data := {}) -> void:
	if multiplayer.is_server():
		action(local_id(),kind,data)
	else:
		network.game_action.rpc_id(1,kind,data)

func propose_mission(id: int,index: int) -> void:
	if world.activities.job>=0 or pending_mission>=24:
		private_notice(id,"Conclua o contrato atual antes de abrir outra operacao.")
		return
	var recipients:=[]
	for peer_id in participants():
		if peer_id != id:
			recipients.append(peer_id)
	if recipients.is_empty():
		private_notice(id,"Esta operacao exclusiva precisa de outro jogador na sala.")
		return
	pending_mission=index
	mission_offer_started = false
	mission_offer_from=id
	mission_offer_deadline=Time.get_ticks_msec()+45000
	mission_invites.clear()
	var host_name:=str(network.members.get(id,{}).get("name","Jogador"))
	for peer_id in recipients:
		mission_invites[peer_id]=true
		send_personal(peer_id, "mission_offer", {"index": index, "host": host_name})
	private_notice(id,"Convite enviado. A operacao comeca quando um parceiro aceitar.")

func send_personal(id: int, kind: String, data: Dictionary) -> void:
	if id == local_id():
		receive_event(kind, data)
	else:
		network.personal.rpc_id(id, kind, data)

func teleport_to_contract(id: int, at: Vector3) -> void:
	bus_riders.erase(id)
	for car_id in network.owners.keys():
		if network.owners[car_id] == id:
			network.owners.erase(car_id)
	var member: Dictionary = network.members[id]
	member.erase("bus")
	member["position"] = at
	member["car_position"] = at
	member["car"] = -1
	member["held"] = false
	member["elevator_target"] = at
	member["elevator_target_until"] = Time.get_ticks_msec() + 600
	send_personal(id, "spawn", {"position": at, "health": sheets[id].health})

func respond_to_mission(id: int,accept: bool) -> void:
	send_personal(id, "mission_offer_close", {})
	if pending_mission < 24 or Time.get_ticks_msec() > mission_offer_deadline or not mission_invites.has(id):
		return
	mission_invites.erase(id)
	if not accept:
		private_notice(mission_offer_from,str(network.members[id].get("name","Um parceiro"))+" recusou o convite.")
	elif (mission_offer_started and world.activities.job == pending_mission) or (not mission_offer_started and world.activities.job < 0 and mission_offer_from in participants()):
		var entrance: Vector3 = world.life.PLACES[5] + Vector3(0, 0.3, 15)
		if pending_mission in [27, 28]:
			entrance = Vector3(294 if pending_mission == 27 else 798, 0.3, -78.5)
		if not mission_offer_started:
			teleport_to_contract(mission_offer_from, entrance + Vector3.LEFT * 1.5)
		var offset := 1.5 if not mission_offer_started else 2.5 + float(id % 3)
		teleport_to_contract(id, entrance + Vector3.RIGHT * offset)
		if not mission_offer_started:
			mission_offer_started = true
			world.activities.start_job(pending_mission, true)
		private_notice(id, "Convite aceito. Você chegou à entrada da missão.")
	if mission_invites.is_empty():
		pending_mission = -1
		mission_offer_deadline = 0

func tick_mission_offer() -> void:
	if pending_mission>=24 and (Time.get_ticks_msec()>mission_offer_deadline or (mission_offer_started and world.activities.job != pending_mission) or (not mission_offer_started and not network.members.has(mission_offer_from))):
		for peer_id in mission_invites:
			if network.members.has(peer_id):
				send_personal(peer_id, "mission_offer_close", {})
		if not mission_offer_started and network.members.has(mission_offer_from):
			private_notice(mission_offer_from,"Convite encerrado sem aceitação.")
		pending_mission=-1
		mission_offer_deadline=0
		mission_invites.clear()

func action(id: int, kind: String, data: Dictionary) -> void:
	if not multiplayer.is_server() or not sheets.has(id) or is_dead(id):
		return
	if int(sheets[id].get("prison_stage", -1)) >= 0:
		if kind == "prison_step":
			world.prison_interact(id, position_of(id))
		return
	if world.vehicle_falls.has(id) or (bus_riders.has(id) and kind not in ["bus_exit", "mission_response"]):
		return
	# Reliable keypad events can arrive in the same frame. The active hack
	# already limits input through its reveal phase, attempts and lockout.
	if kind not in ["digit", "mission_digit"]:
		var key := str(id) + kind
		var now := Time.get_ticks_msec()
		if now - int(last_actions.get(key, 0)) < (50 if kind == "fire" else 150):
			return
		last_actions[key] = now
	match kind:
		"supply_scene_complete":
			if id == world.activities.supply_owner and world.activities.supply_stage == 2:
				world.activities.complete_supply_scene()
		"hover_mode":
			var car_id: int = network.members.get(id, {}).get("car", -1)
			var car: Node = world.car_by_id(car_id)
			if car != null and car.tier == car.Catalog.SUPERCAR and car.hp > 0 and network.owners.get(car_id, 0) == id:
				car.set_hover_mode(not car.hovering)
		"bus_board": board_bus(id, int(data.get("car", -1)))
		"bus_exit": leave_bus(id)
		"fire": fire_peer(id,data)
		"punch": punch_peer(id,float(data.get("yaw",0)))
		"reload": with_actor(id,world.activities.reload)
		"job":
			var requested_job:=clampi(int(data.get("index",0)),0,world.activities.JOBS.size()-1)
			if requested_job >= 24 and requested_job < 29:
				propose_mission(id,requested_job)
			elif world.activities.job>=0:
				private_notice(id,"Conclua o contrato atual da sala primeiro.")
			else:
				world.activities.start_job(requested_job)
		"mission_response": respond_to_mission(id,bool(data.get("accept",false)))
		"mission_digit": enter_mission_digit(id,clampi(int(data.get("digit",0)),1,4))
		"mission_cancel":
			if id==mission_hacking_peer:
				mission_hacking_peer=0
		"buy":
			with_actor(id,func():
				var menu: String=str(data.get("menu",""))
				if world.activities.nearby_place() != ("garage" if menu == "garage_cars" else menu):
					return
				world.activities.menu=menu
				world.activities.car_page=clampi(int(data.get("page",0)),0,maxi(0,ceili(world.activities.purchased_cars.size()/3.0)-1) if menu == "owned_cars" else 2)
				world.activities.buy(int(data.get("choice",-1)))
			)
			if str(data.get("menu","")) in ["guns","heavy_guns"]:
				network.personal.rpc_id(id,"equip",{"weapon":sheets[id].inventory.weapon})
		"ram_officer":
			var car: Node=world.car_by_id(int(network.members[id].get("car",-1)))
			var index := int(data.get("index",-1))
			if car!=null and index>=0 and index<world.activities.officers.size():
				var officer: Node=world.activities.officers[index]
				if car.position.distance_to(officer.position)<5:
					officer.take_hit(absf(car.speed)*5)
		"interact":
			var floor_number: int = world.life.home_floor_at(position_of(id))
			if floor_number >= 0:
				with_actor(id,func(): buy_home(id,floor_number))
				return
			with_actor(id,func():
				if world.activities.interact_campaign() or world.activities.interact_hill_errand() or world.activities.interact_supply():
					return
				if world.life.interact():
					return
				if world.activities.bank.interact():
					bank_owner=id
			)
		"refuel":
			var car_id: int = int(network.members.get(id, {}).get("car", -1))
			var car: Node = world.car_by_id(car_id)
			if car != null and not bus_riders.has(id) and network.owners.get(car_id, 0) == id and car.hp > 0 and car.fuel < 1.0 and absf(car.speed) <= 0.25 and world.near_fuel_station(car.position):
				car.refuel_time = 5.0
				car.refuel_peer = id
				private_notice(id, "Abastecendo...")
		"vehicle_entry":
			var car_id = data.get("car")
			if car_id is int and int(network.members[id].get("car",-1)) < 0 and world.life.elevator_rider_position(id) == null:
				world.request_vehicle_entry(id,world.car_by_id(car_id),position_of(id))
		"building_contact":
			var contact = data.get("contact")
			if contact is int and int(network.members[id].get("car",-1)) < 0:
				var at := position_of(id)
				with_actor(id,func(): world.life.apply_building_choice(id,at,contact))
		"elevator":
			var destination = data.get("to")
			if destination is int and int(network.members[id].get("car",-1)) < 0:
				world.life.request_elevator(position_of(id),destination)
		"digit":
			if id == bank_owner and world.activities.bank.hacking and world.activities.bank.reveal_time <= 0.0:
				with_actor(id,func(): world.activities.bank.enter_digit(clampi(int(data.get("digit",0)),1,4)))
		"cancel_hack":
			if id==bank_owner:
				world.activities.bank.hacking=false
		"crime": world.raise_heat(clampf(float(data.get("amount",0)),0,80), id)
		"collision":
			var car: Node=world.car_by_id(int(network.members[id].get("car",-1)))
			if car!=null:
				damage_peer(id,minf(35,absf(car.speed)*0.48),0)
		"ram":
			var car: Node=world.car_by_id(int(network.members[id].get("car",-1)))
			var target := int(data.get("target",0))
			if car!=null and target!=id and sheets.has(target) and position_of(target).distance_to(car.position)<5:
				damage_peer(target,absf(car.speed)*4,id)

func hurt_local(amount: float) -> void:
	if network.is_client():
		send_action("collision",{})
	else:
		damage_peer(context_peer if context_peer>0 else local_id(),amount,attacker)

func board_bus(id: int, car_id: int) -> void:
	var member: Dictionary = network.members.get(id, {})
	var car: Node3D = world.car_by_id(car_id)
	if member.is_empty() or int(member.get("car", -1)) >= 0 or car == null or car.tier != car.Catalog.BUS or car.hp <= 0:
		return
	var driver: int = network.owners.get(car_id, 0)
	if driver == 0 or driver == id or position_of(id).distance_to(car.position) >= 4.5:
		return
	if absf(car.speed) > 3.0:
		private_notice(id, "Espere o ônibus parar para embarcar.")
		return
	if bus_riders.values().count(car_id) >= car.Catalog.BUS_CAPACITY - 1:
		private_notice(id, "O ônibus está lotado.")
		return
	bus_riders[id] = car_id
	member["bus"] = car_id
	member["held"] = false
	if id == local_id():
		receive_event("bus_board", {"car": car_id})
	else:
		network.personal.rpc_id(id, "bus_board", {"car": car_id})

func leave_bus(id: int, forced := false) -> void:
	if not bus_riders.has(id):
		return
	var car: Node3D = world.car_by_id(bus_riders[id])
	var offset: Vector3 = world.vehicle_exit_offset(car) if is_instance_valid(car) else Vector3.ZERO
	if not forced and (offset == Vector3.ZERO or absf(car.speed) > 3.0):
		private_notice(id, "Espere o ônibus parar em um local livre para desembarcar.")
		return
	var at := car.to_global(offset) if offset != Vector3.ZERO else next_spawn()
	bus_riders.erase(id)
	network.members[id].erase("bus")
	network.members[id]["position"] = at
	network.members[id]["car_position"] = at
	if id == local_id():
		receive_event("bus_exit", {"position": at})
	else:
		network.personal.rpc_id(id, "bus_exit", {"position": at})

func damage_peer(id: int, amount: float, killer := 0, by_police := false) -> void:
	if not multiplayer.is_server() or not sheets.has(id) or is_dead(id) or not is_finite(amount):
		return
	if killer>0 and Time.get_ticks_msec()<sheets[id].protected_until:
		return
	var old: float=world.health if id==local_id() and context_peer in [0,local_id()] else float(sheets[id].health)
	sheets[id].health=maxf(0,old-clampf(amount,0,200))
	if (id==local_id() and context_peer in [0,local_id()]) or id==context_peer:
		world.health=sheets[id].health
	if sheets[id].health<=0:
		if by_police or int(sheets[id].get("prison_stage", -1)) >= 0:
			sheets[id]["prison_stage"] = 0
		sheets[id].dead_until=Time.get_ticks_msec()+3000
		sheets[id]["wanted_reset"] = true
		if wanted_participants().is_empty():
			world.heat = 0.0
			world.crime_grace = 0.0
			world.response_delay = 0.0
		leave_bus(id, true)
		for car_id in network.owners.keys():
			if network.owners[car_id]==id:
				network.owners.erase(car_id)
		if killer>0 and killer!=id and sheets.has(killer):
			award(killer,1500)
			private_notice(killer,"Jogador eliminado / +$1500")
			world.raise_heat(35, killer)
		private_notice(id, "Você foi preso. Acordará na cadeia." if int(sheets[id].get("prison_stage", -1)) >= 0 else "Você foi calado. Renascendo em 3 segundos...")

func receive_event(kind: String, data: Dictionary) -> void:
	match kind:
		"prison_escape":
			if sheets.has(local_id()): sheets[local_id()]["prison_stage"] = -1
			world.life.apply_elevator_arrival(Vector3(1035, 0.3, 79))
			world.notify("Você fugiu da cadeia!")
		"supply_scene":
			world.activities.menu = "cutscene"
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			world.cutscene.play("EMBOSCADA NO BECO", "")
		"passenger_boarding":
			world.activities.show_passenger_boarding(data.start, int(data.car))
		"vehicle_fall":
			world.play_vehicle_fall(data)
		"vehicle_enter":
			world.finish_vehicle_entry(world.car_by_id(int(data.car)))
		"bus_board":
			var bus: Node3D = world.car_by_id(int(data.car))
			if bus == null:
				return
			if world.active_car != null and world.active_car != bus:
				world.active_car.driving = false
			world.active_car = bus
			world.bus_passenger = true
			world.car_transition = false
			world.player.visible = false
			world.player.model.process_mode = Node.PROCESS_MODE_DISABLED
			world.player.collision_layer = 0
			world.player.velocity = Vector3.ZERO
			world.camera_yaw = bus.heading
		"bus_exit":
			world.bus_passenger = false
			world.active_car = null
			world.player.position = data.position
			world.player.velocity = Vector3.ZERO
			world.player.visible = true
			world.player.model.process_mode = Node.PROCESS_MODE_INHERIT
			world.player.model.position = Vector3.ZERO
			world.player.collision_layer = 2
		"equip": world.activities.weapon=clampi(int(data.get("weapon",1)),0,7)
		"notice": world.notify(str(data.get("text","")))
		"menu": world.activities.set_menu(str(data.get("value","")))
		"mission_offer": network.show_mission_offer(int(data.get("index",24)),str(data.get("host","Host")))
		"mission_offer_close": network.hide_mission_offer()
		"elevator":
			world.life.apply_elevator_arrival(data.get("position",Vector3.ZERO))
		"cutscene": world.play_cutscene(str(data.get("title","Contrato")),str(data.get("subtitle","")))
		"sound": world.extra.play(str(data.get("name","cash")))
		"spawn":
			if world.active_car!=null and not world.bus_passenger:
				world.active_car.driving=false
			world.bus_passenger=false
			world.active_car=null
			world.car_transition=false
			world.player.position=data.position
			world.player.velocity=Vector3.ZERO
			world.player.visible=true
			world.player.collision_layer=2
			world.player.model.visible=true
			world.player.model.process_mode=Node.PROCESS_MODE_INHERIT
			world.player.model.position=Vector3.ZERO
			world.player.model.rotation=Vector3.ZERO
			world.player.roll_time=0
			world.finished=false
			world.health=float(data.get("health",100))
			world.camera.position=data.position+Vector3(0,4,7)
			world.camera_check_timer=0
			world.extra.death_filter.hide()
			Engine.time_scale=1

func fire_local() -> void:
	if Time.get_ticks_msec()-shot_send<60 or world.activities.menu!="":
		return
	shot_send=Time.get_ticks_msec()
	send_action("fire",{"origin":world.camera.global_position,"direction":-world.camera.global_basis.z,"weapon":world.activities.weapon})

func fire_peer(id: int,data: Dictionary) -> void:
	if not data.get("origin") is Vector3 or not data.get("direction") is Vector3:
		return
	var origin: Vector3=data.origin
	var direction: Vector3=data.direction
	if not origin.is_finite() or not direction.is_finite() or direction.length()<0.1 or origin.distance_to(position_of(id))>14:
		return
	with_actor(id,func():
		var a: Node=world.activities
		var selected := clampi(int(data.get("weapon",1)),0,7)
		if selected==0:
			a.weapon=0
			punch_peer(id,atan2(-direction.x,-direction.z))
			return
		if not a.owns_weapon(selected):
			return
		a.weapon=selected
		if world.active_car!=null or a.fire_cooldown>0 or a.reload_time>0 or (a.bank.hacking and bank_owner==id):
			return
		if a.clips[selected]<=0:
			a.reload()
			return
		a.clips[selected]-=1
		a.fire_cooldown=a.FIRE_INTERVAL[selected]
		a.mission_noise()
		if not a.mission_shot_is_quiet(): world.raise_heat(3)
		var end := origin+direction.normalized()*(600 if selected==6 else 180)
		var query := PhysicsRayQueryParameters3D.create(origin,end,7)
		query.exclude=[world.player.get_rid()]
		var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			end=hit.position
		var muzzle: Vector3 = world.player.position+Vector3(0,1.35,0)
		query=PhysicsRayQueryParameters3D.create(muzzle,end,7)
		query.exclude=[world.player.get_rid()]
		var cover := world.get_world_3d().direct_space_state.intersect_ray(query)
		if not cover.is_empty():
			hit=cover
			end=cover.position
		attacker=id
		a.weapon_impact(hit,end,selected)
		attacker=0
		network.shot_effect.rpc(muzzle,end,selected)
	)

func punch_peer(id: int, yaw: float) -> void:
	if not is_finite(yaw) or int(network.members.get(id,{}).get("car",-1))>=0 or id==mission_hacking_peer or (id==bank_owner and world.activities.bank.hacking):
		return
	var key := str(id)+"punch_hit"
	if Time.get_ticks_msec()-int(last_actions.get(key,0))<450:
		return
	last_actions[key]=Time.get_ticks_msec()
	var origin := position_of(id)+Vector3(0,1,0)
	var targets: Array=[]
	for other in participants():
		if other!=id:
			targets.append(local_body if other==local_id() else network.avatars.get(other,{}).get("node"))
	targets.append_array(world.life.people)
	targets.append_array(world.activities.officers)
	targets.append_array(world.cars)
	for target in targets:
		if target==null:
			continue
		var offset: Vector3=target.position+Vector3(0,1,0)-origin
		if offset.length()<2.7 and offset.normalized().dot(Vector3.FORWARD.rotated(Vector3.UP,yaw))>0.3:
			if world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin,origin+offset,1)).is_empty():
				attacker=id
				target.take_hit(25)
				attacker=0
				world.raise_heat(6, id)
				break

func tick_inventory(id: int, delta: float) -> void:
	var inv = world.activities if id == local_id() else sheets[id].inventory
	inv.fire_cooldown = maxf(0, inv.fire_cooldown - delta)
	if inv.reload_time > 0:
		inv.reload_time = maxf(0, inv.reload_time - delta)
		if inv.reload_time <= 0:
			var weapon: int = inv.reload_weapon
			var count := clampi(world.activities.CAPACITIES[weapon] - inv.clips[weapon], 0, inv.reserves[weapon])
			inv.clips[weapon] += count
			inv.reserves[weapon] -= count

func choose_actor(destination: Vector3, holding := false, require_car := false, require_foot := false) -> int:
	var best := 0
	var distance := INF
	for id in participants():
		if bus_riders.has(id):
			continue
		if holding and not held(id):
			continue
		if require_foot and int(network.members[id].get("car",-1))>=0:
			continue
		if require_car and int(network.members[id].get("car",-1))<0:
			continue
		var current := destination.distance_squared_to(position_of(id))
		if current<distance:
			distance=current
			best=id
	return best

func physics(delta: float) -> void:
	tick_mission_offer()
	if network.is_client():
		if Input.is_action_pressed("shoot") and world.activities.menu=="" and not is_dead(local_id()):
			fire_local()
		return
	for car in world.cars:
		if int(network.owners.get(car.net_id, 0)) > 0:
			car.fuel = maxf(0.0, car.fuel - absf(car.speed) * delta / 6000.0)
			if car.fuel <= 0.0:
				car.speed = 0.0
				car.velocity.x = 0.0
				car.velocity.z = 0.0
				car.hovering = false
		if car.refuel_time > 0.0:
			var peer_id: int = car.refuel_peer
			if not network.members.has(peer_id) or int(network.members[peer_id].get("car", -1)) != car.net_id or absf(car.speed) > 0.25 or not world.near_fuel_station(car.position):
				car.refuel_time = 0.0
				car.refuel_peer = 0
				private_notice(peer_id, "Abastecimento cancelado.")
			else:
				car.refuel_time = maxf(0.0, car.refuel_time - delta)
				if car.refuel_time <= 0.0:
					car.fuel = 1.0
					car.refuel_peer = 0
					private_notice(peer_id, "Tanque cheio.")
	for id in bus_riders.keys():
		var bus: Node = world.car_by_id(bus_riders[id])
		if bus == null or bus.hp <= 0:
			leave_bus(id, true)
	for id in sheets.keys():
		if not network.members.has(id):
			sheets.erase(id)
			continue
		if is_dead(id):
			world.life.building_job_for(id).clear()
			if Time.get_ticks_msec()>=sheets[id].dead_until:
				sheets[id].health=100.0
				sheets[id].life+=1
				sheets[id].protected_until=Time.get_ticks_msec()+5000
				var home_floor: int = int(sheets[id].get("home", -1))
				var at: Vector3 = world.life.HOME_BUILDING + Vector3(0,(home_floor+1)*6+0.3,5) if home_floor >= 0 else next_spawn()
				if int(sheets[id].get("prison_stage", -1)) >= 0:
					at = world.PRISON_SPAWN
				network.members[id].position=at
				network.members[id].car_position=at
				network.members[id].car=-1
				if id==local_id():
					receive_event("spawn",{"position":at})
				else:
					network.personal.rpc_id(id,"spawn",{"position":at})
			continue
		if int(sheets[id].get("prison_stage", -1)) >= 0:
			world.tick_prison(id, position_of(id), held(id), delta)
		if world.life.tick_building_job(id,delta):
			private_notice(id,"O tempo da entrega acabou.")
		var inv: Dictionary=sheets[id].inventory
		var timers_active: bool=(world.activities.fire_cooldown>0 or world.activities.reload_time>0) if id==local_id() else (float(inv.fire_cooldown)>0 or float(inv.reload_time)>0)
		if timers_active:
			tick_inventory(id, delta)
	tick_mission_hack(delta)
	if Input.is_action_pressed("shoot") and world.activities.menu=="" and not is_dead(local_id()):
		fire_local()
	var a: Node=world.activities
	a.tick_supply()
	for i in a.robbery_cooldowns.size():
		a.robbery_cooldowns[i]=maxf(0,a.robbery_cooldowns[i]-delta)
	if a.bank.phase==4:
		bank_owner=choose_actor(a.bank.to_global(a.bank.ENTRY))
	if sheets.has(bank_owner) and not is_dead(bank_owner):
		if a.bank.hacking or a.bank.phase in [4, 5]:
			with_actor(bank_owner,func(): a.bank.tick(delta))
		else:
			a.bank.tick(delta)
	else:
		a.bank.hacking=false
		bank_owner=1
	var worker := choose_actor(a.destination(),true)
	if worker != robbery_worker:
		robbery_worker = worker
		a.robbery_index = -1
		a.robbery_progress = 0
		a.clear_pedestrian_robbery()
	if worker>0:
		with_actor(worker,func(): world.life.tick_tasks(delta); a.tick_robbery(delta); a.tick_pedestrian_robbery(delta))
	else:
		world.life.task_progress=0
	if a.job>=0:
		var actor := choose_actor(a.destination(),false,a.job in [0,2,3,8] or a.action_requires_car(),a.job>=24 or a.action_requires_foot())
		if actor==0 and not is_dead(1) and not bus_riders.has(1) and a.job<24:
			actor=1
		if a.passenger_car >= 0:
			for id in participants():
				if int(network.members[id].get("car",-1)) == a.passenger_car: actor = id
		if a.job==2 or (a.ACTION_JOBS.has(a.job) and a.ACTION_JOBS[a.job].kind in ["drive","getaway"]):
			for id in participants():
				if a.target_car!=null and int(network.members[id].get("car",-1))==a.target_car.net_id:
					actor=id
		if actor>0:
			with_actor(actor,func(): a.tick_mission(delta))
	world.update_dispatch(delta)
	a.tick_police(delta)
	police_sight_clock-=delta
	if police_sight_clock<=0:
		police_sight_clock=0.2
		visible_police.clear()
		for observer in world.cops+a.officers:
			if is_instance_valid(observer) and observer.hp>0 and world.police_can_see(observer):
				visible_police.append(observer)
	var seen := false
	var pressured := {}
	var arresting := {}
	for observer in visible_police:
		if not is_instance_valid(observer) or observer.is_queued_for_deletion() or observer.hp <= 0:
			continue
		var target: Array=police_target_actor(observer.position)
		if not network.members.has(target[0]) or is_dead(target[0]):
			continue
		if wanted_heat(target[0]) <= 0 and not observer.has_meta("mission_contract"):
			continue
		seen = true
		var distance:float=observer.position.distance_to(target[1])
		if target_crouched(target[1]) and distance>8:
			continue
		if distance<8:
			var cover := PhysicsRayQueryParameters3D.create(observer.position + Vector3.UP * 1.5, target[1] + Vector3.UP, 1)
			cover.hit_from_inside = true
			if not world.get_world_3d().direct_space_state.intersect_ray(cover).is_empty():
				continue
			if not pressured.has(target[0]):
				pressured[target[0]]=true
				damage_peer(target[0],delta*(2.25 if distance>4 else 7.5),0,true)
			var in_car:bool=int(network.members[target[0]].get("car",-1))>=0
			if distance<3.5 and (not in_car or absf(float(network.members[target[0]].get("speed",0)))<2):
				arresting[target[0]]=true
	for id in network.members:
		if arresting.has(id) and not is_dead(id):
			network.members[id]["arrest_progress"]=float(network.members[id].get("arrest_progress",0.0))+delta
			if float(network.members[id]["arrest_progress"])>=5.0:
				network.members[id]["arrest_progress"]=0.0
				damage_peer(id,200.0,0,true)
				award(id,-500)
				private_notice(id,"Preso pela policia / multa de $500")
		elif not arresting.has(id) or is_dead(id):
			network.members[id]["arrest_progress"]=0.0
	if not seen and world.crime_grace<=0:
		world.heat=maxf(0,world.heat-delta*world.HEAT_DECAY_RATE)
	update_marker()

func update_marker() -> void:
	var a: Node=world.activities
	world.marker.visible=a.job>=0 and not (a.job in [1,4,5] and a.stage>0) and a.job!=6
	if world.marker.visible:
		world.marker.position=a.destination()

func export_state() -> Dictionary:
	if sheets.has(1):
		sheets[1].cash=world.cash
		sheets[1].health=world.health
		sheets[1].inventory=inventory()
	var a: Node=world.activities
	var bank: Node=a.bank
	return {"elevators":world.life.elevators,"shipment_integrity":a.shipment_integrity,"passenger_car":a.passenger_car,"hill_errand_stage":a.hill_errand_stage,"hill_errand_owner":a.hill_errand_owner,"supply_stage":a.supply_stage,"supply_owner":a.supply_owner,"sheets":sheets,"heat":world.heat,"job":a.job,"stage":a.stage,"clock":a.clock,"progress":a.progress,"completed":a.completed,"robbery_cooldowns":a.robbery_cooldowns,"target_car":a.target_car.net_id if is_instance_valid(a.target_car) else -1,"targets":a.targets.map(func(car): return car.net_id),"bank_owner":bank_owner,"mission_hacking_peer":mission_hacking_peer,"mission_pattern":mission_pattern,"mission_entered":mission_entered,"mission_round":mission_round,"mission_mistakes":mission_mistakes,"mission_reveal_time":mission_reveal_time,"mission_round_time":mission_round_time,"bank":{"phase":bank.phase,"taken":bank.taken,"hacking":bank.hacking,"pattern":bank.pattern,"entered":bank.entered,"round_index":bank.round_index,"reveal_time":bank.reveal_time,"round_time":bank.round_time,"mistakes":bank.mistakes,"cooldown":bank.cooldown,"lockout":bank.lockout},"task_progress":world.life.task_progress}

func apply_state(data: Dictionary) -> void:
	sheets=data.get("sheets",{})
	world.life.apply_elevator_snapshot(data.elevators)
	world.heat=float(data.get("heat",0))
	var a: Node=world.activities
	for key in ["shipment_integrity","passenger_car","hill_errand_stage","hill_errand_owner","supply_stage","supply_owner","job","stage","clock","progress","completed","robbery_cooldowns"]:
		a.set(key,data[key])
	a.target_car=world.car_by_id(int(data.target_car))
	a.targets.clear()
	for id in data.targets:
		var car: Node=world.car_by_id(int(id))
		if car!=null:
			a.targets.append(car)
	bank_owner=int(data.bank_owner)
	mission_hacking_peer=int(data.get("mission_hacking_peer",0))
	mission_pattern.assign(data.get("mission_pattern",[]))
	mission_entered=int(data.get("mission_entered",0))
	mission_round=int(data.get("mission_round",0))
	mission_mistakes=int(data.get("mission_mistakes",0))
	mission_reveal_time=float(data.get("mission_reveal_time",0))
	mission_round_time=float(data.get("mission_round_time",0))
	for key in data.bank:
		a.bank.set(key,data.bank[key])
	for i in a.bank.bag_models.size():
		a.bank.bag_models[i].visible=not a.bank.taken[i]
	a.bank.door.rotation.y=PI/2 if a.bank.phase>=3 else 0
	a.bank.security_light.material_override=world.material(Color("6acbaa") if a.bank.phase>0 else Color("ef9d6b"),true)
	a.bank.screen.material_override=world.material(Color("66cba3") if a.bank.phase>=2 else Color("66bbcc"),true)
	world.life.task_progress=float(data.task_progress)
	if sheets.has(local_id()):
		var sheet: Dictionary=sheets[local_id()]
		world.cash=sheet.cash
		world.health=sheet.health
		for key in INVENTORY:
			if key!="weapon":
				a.set(key,sheet.inventory[key])
		world.player.collision_layer=0 if is_dead(local_id()) or world.active_car!=null else 2
	update_marker()
