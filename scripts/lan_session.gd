extends Node

const Build = preload("res://scripts/build_version.gd")
const Profile = preload("res://scripts/player_profile.gd")
const PORT := 28960
const DISCOVERY := 28961
const SYMBOLS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
var world: Node3D
var code := ""
var peer: ENetMultiplayerPeer
var discovery := PacketPeerUDP.new()
var rooms := {}
var members := {}
var last_hit := {}
var avatars := {}
var owners := {}
var clock := 0.0
var advertise_clock := 0.0
var panel: PanelContainer
var status: Label
var field: LineEdit
var address_field: LineEdit
var invitation: LineEdit
var internet: Node
var joined := false
var connecting_since := 0
var room_list: ItemList
var tabs: TabContainer
var search_until := 0
var list_signature := ""
var return_menu := ""
var advanced_help: Label
var rules: Node
var announced_version := Build.TOKEN
var refusal_reason := ""
var offer_panel: PanelContainer
var offer_text: Label

func active() -> bool:
	return peer != null and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED and (multiplayer.is_server() or joined)

func is_client() -> bool:
	return active() and not multiplayer.is_server()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rules=preload("res://scripts/session_rules.gd").new()
	rules.name="GameRules"
	rules.world=world
	rules.network=self
	add_child(rules)
	multiplayer.auth_callback=authenticate
	multiplayer.auth_timeout=8
	multiplayer.peer_authenticating.connect(authenticating)
	multiplayer.peer_authentication_failed.connect(authentication_failed)
	var layer := CanvasLayer.new()
	layer.layer = 45
	add_child(layer)
	offer_panel=PanelContainer.new()
	offer_panel.set_anchors_preset(Control.PRESET_CENTER)
	offer_panel.position=Vector2(-240,-110)
	offer_panel.size=Vector2(480,220)
	offer_panel.theme=world.pause_menu.canvas.theme
	var offer_column:=VBoxContainer.new()
	offer_panel.add_child(offer_column)
	offer_text=Label.new()
	offer_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	offer_column.add_child(offer_text)
	var offer_buttons:=HBoxContainer.new()
	offer_column.add_child(offer_buttons)
	ui_button(offer_buttons,"ACEITAR",func(): rules.send_action("mission_response",{"accept":true}); hide_mission_offer())
	ui_button(offer_buttons,"RECUSAR",func(): rules.send_action("mission_response",{"accept":false}); hide_mission_offer())
	layer.add_child(offer_panel)
	offer_panel.hide()
	panel = PanelContainer.new()
	panel.theme=world.pause_menu.canvas.theme
	var background := StyleBoxFlat.new()
	background.bg_color=Color(0.035,0.08,0.12,0.98)
	background.set_corner_radius_all(12)
	background.set_border_width_all(1)
	background.border_color=Color("43616b")
	panel.add_theme_stylebox_override("panel",background)
	layer.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_"+side,16)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",10)
	margin.add_child(column)
	var title := Label.new()
	title.text="MULTIPLAYER / v"+Build.VERSION+" / PC + ANDROID"
	title.add_theme_font_size_override("font_size",24)
	column.add_child(title)
	status=Label.new()
	status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.y=48
	column.add_child(status)
	tabs=TabContainer.new()
	tabs.size_flags_vertical=Control.SIZE_EXPAND_FILL
	column.add_child(tabs)
	var local_scroll := ScrollContainer.new()
	local_scroll.name="Salas locais"
	local_scroll.custom_minimum_size.y=340
	local_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(local_scroll)
	var local := VBoxContainer.new()
	local.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	local_scroll.add_child(local)
	local.add_theme_constant_override("separation",8)
	add_help(local,"No mesmo Wi-Fi: procure, selecione a sala e entre.")
	ui_button(local,"PROCURAR SALAS LOCAIS",search_rooms)
	room_list=ItemList.new()
	room_list.custom_minimum_size.y=130
	room_list.size_flags_vertical=Control.SIZE_EXPAND_FILL
	local.add_child(room_list)
	room_list.item_activated.connect(func(_index): join_selected_room())
	ui_button(local,"ENTRAR NA SALA SELECIONADA",join_selected_room)
	ui_button(local,"CRIAR SALA LOCAL",host)
	var online_scroll := ScrollContainer.new()
	online_scroll.name="Pela internet"
	online_scroll.custom_minimum_size.y=340
	online_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(online_scroll)
	var online := VBoxContainer.new()
	online.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	online_scroll.add_child(online)
	online.add_theme_constant_override("separation",8)
	add_help(online,"Quem cria: copie o codigo e envie para os amigos.")
	ui_button(online,"CRIAR SALA INTERNET",host_internet)
	invitation=LineEdit.new()
	invitation.editable=false
	invitation.placeholder_text="Seu codigo de internet aparece aqui"
	online.add_child(invitation)
	ui_button(online,"COPIAR MEU CODIGO",copy_invite)
	add_help(online,"Quem entra: cole o codigo recebido abaixo.")
	address_field=LineEdit.new()
	address_field.max_length=240
	address_field.placeholder_text="Cole convite ou IP publico:28960"
	online.add_child(address_field)
	ui_button(online,"GERAR CONVITE MANUAL",generate_manual_invite)
	add_help(online,"Se UPnP falhar, encaminhe UDP 28960 para este aparelho e informe o IP publico. Redes moveis/CGNAT podem bloquear hospedagem direta.")
	ui_button(online,"ENTRAR COM ESTE CODIGO",join_room)
	var advanced := CheckButton.new()
	advanced.text="Opcoes avancadas / entrada manual"
	online.add_child(advanced)
	field=LineEdit.new()
	field.max_length=5
	field.placeholder_text="Codigo curto (apenas para convite antigo por IP)"
	online.add_child(field)
	field.hide()
	advanced_help=Label.new()
	advanced_help.text="Entrada manual: IP:porta no campo acima e codigo curto abaixo."
	advanced_help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	online.add_child(advanced_help)
	advanced_help.hide()
	advanced.toggled.connect(func(value): field.visible=value; advanced_help.visible=value)
	var footer := HBoxContainer.new()
	column.add_child(footer)
	ui_button(footer,"DESCONECTAR",func(): disconnect_room(); status.text="Desconectado.")
	ui_button(footer,"VOLTAR AO JOGO",close_menu)
	internet=preload("res://scripts/internet_access.gd").new()
	add_child(internet)
	internet.prepared.connect(internet_prepared)
	get_viewport().size_changed.connect(resize_panel)
	resize_panel()
	panel.hide()
	multiplayer.peer_connected.connect(peer_joined)
	multiplayer.peer_disconnected.connect(peer_left)
	multiplayer.connected_to_server.connect(connected)
	multiplayer.connection_failed.connect(connection_failed)
	multiplayer.server_disconnected.connect(server_left)
	var result := discovery.bind(0)
	if result == OK:
		discovery.set_broadcast_enabled(true)

func open_menu() -> void:
	if world.activities.menu!="network":
		return_menu=world.activities.menu
	world.activities.set_menu("network")
	panel.show()
	resize_panel.call_deferred()
	status.text = ("SALA %s / %d DE 12" % [code,members.size()]) if active() else "Escolha Salas locais ou Pela internet."

func show_mission_offer(index: int, host_name: String) -> void:
	var titles: Array=world.activities.JOBS
	offer_text.text="%s convida voce para: %s\n\nOperacao cooperativa dentro de um predio. Aceitar inicia a missao para a sala." % [host_name,titles[clampi(index,24,titles.size()-1)]]
	offer_panel.show()

func hide_mission_offer() -> void:
	if is_instance_valid(offer_panel):
		offer_panel.hide()

func close_menu() -> void:
	panel.hide()
	world.activities.set_menu("" if active() else return_menu)

func host() -> void:
	disconnect_room()
	peer = ENetMultiplayerPeer.new()
	var error := peer.create_server(PORT,11)
	if error != OK:
		peer = null
		status.text = "Nao foi possivel hospedar: " + error_string(error)
		return
	code = ""
	for i in 5:
		code += SYMBOLS[randi()%SYMBOLS.length()]
	discovery.close()
	var bound := discovery.bind(DISCOVERY)
	if bound != OK:
		disconnect_room()
		status.text = "Porta de descoberta ocupada."
		return
	discovery.set_broadcast_enabled(true)
	multiplayer.multiplayer_peer = peer
	var at: Vector3=rules.add_peer(1)
	world.player.set_meta("peer_id",1)
	rules.receive_event("spawn",{"position":at})
	world.start_mode("sandbox")
	panel.hide()
	world.notify("Sala: %s / compartilhe o codigo / ate 12 jogadores" % code)

func join_room() -> void:
	var requested := field.text.strip_edges().to_upper()
	var target := parse_target(address_field.text,requested)
	if not address_field.text.strip_edges().is_empty() and target.is_empty():
		status.text="Codigo invalido. Cole o codigo inteiro, incluindo CL1-."
		return
	if target.is_empty():
		if requested.length()!=5 or not rooms.has(requested):
			status.text="Sala local nao encontrada. Para internet, cole o convite completo."
			return
		target={"address":rooms[requested].ip,"port":PORT,"code":requested}
	connect_target(target)

func connect_target(target: Dictionary) -> void:
	disconnect_room()
	code=target.code
	refusal_reason=""
	peer=ENetMultiplayerPeer.new()
	var error := peer.create_client(target.address,target.port)
	if error!=OK:
		peer=null
		status.text="Nao foi possivel conectar: "+error_string(error)
		return
	multiplayer.multiplayer_peer=peer
	connecting_since=Time.get_ticks_msec()
	status.text="Conectando ao anfitriao..."

static func parse_target(text: String, room_code: String) -> Dictionary:
	var value := text.strip_edges()
	if value.to_upper().begins_with("CL1-"):
		return decode_internet_code(value)
	if value.is_empty() or value.length()>240:
		return {}
	if value.to_lower().begins_with("cl://"):
		value=value.substr(5)
	elif value.contains("://"):
		return {}
	var path := value.split("/",true)
	if path.size()>2 or path.is_empty():
		return {}
	var selected := (path[1] if path.size()==2 else room_code).strip_edges().to_upper()
	if selected.length()!=5:
		return {}
	for symbol in selected:
		if not symbol in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789":
			return {}
	var endpoint := path[0].split(":",true)
	if endpoint.is_empty() or endpoint.size()>2:
		return {}
	var port := PORT
	if endpoint.size()==2:
		if not endpoint[1].is_valid_int():
			return {}
		port=endpoint[1].to_int()
	if port<1 or port>65535 or endpoint[0].is_empty():
		return {}
	for symbol in endpoint[0]:
		if not symbol.to_lower() in "abcdefghijklmnopqrstuvwxyz0123456789.-":
			return {}
	return {"address":endpoint[0],"port":port,"code":selected}

func host_internet() -> void:
	host()
	if not active():
		return
	return_menu=""
	tabs.current_tab=1
	world.activities.set_menu("network")
	panel.show()
	status.text="SALA %s / preparando acesso pela internet..." % code
	internet.start()

func internet_prepared(address: String, mapped: bool, message: String) -> void:
	if not active() or not multiplayer.is_server():
		return
	if not address.is_empty():
		invitation.text=make_internet_code(address,PORT,code)
	status.text="Codigo pronto! Copie e envie aos amigos." if mapped and not invitation.text.is_empty() else ("Convite criado, mas a porta nao foi confirmada. Configure UDP 28960 antes de testar." if not invitation.text.is_empty() else "UPnP indisponivel. Encaminhe UDP 28960 no roteador e use GERAR CONVITE MANUAL.")
	advanced_help.text=message+" Entrada manual: IP:porta acima e codigo curto abaixo."

func generate_manual_invite() -> void:
	if not active() or not multiplayer.is_server():
		status.text="Crie uma sala antes de gerar o convite."
		return
	var target:=parse_target(address_field.text,code)
	if target.is_empty():
		status.text="Digite o IP publico e a porta do anfitriao, por exemplo IP:28960."
		return
	invitation.text=make_internet_code(target.address,target.port,code)
	status.text="Convite pronto. So conectara com UDP 28960 encaminhada e sem bloqueio de CGNAT."

func copy_invite() -> void:
	if not active() or not multiplayer.is_server():
		status.text="Crie uma sala para gerar o convite."
		return
	var target := parse_target(address_field.text,code)
	if not target.is_empty():
		invitation.text=make_internet_code(target.address,target.port,code)
	if invitation.text.is_empty():
		status.text="A sala ainda nao gerou um codigo. Aguarde ou veja Opcoes avancadas."
		return
	DisplayServer.clipboard_set(invitation.text)
	status.text="Codigo copiado! No outro dispositivo, cole na aba Pela internet."

func connected() -> void:
	introduce.rpc_id(1,code)

func peer_joined(_id: int) -> void:
	pass # Membership is accepted only after the room code handshake.

@rpc("any_peer","call_remote","reliable")
func introduce(requested: String) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if requested!=code or members.size()>=12:
		peer.disconnect_peer(id)
		return
	var at: Vector3=rules.add_peer(id)
	update_avatars(members)
	accepted.rpc_id(id,at)

@rpc("authority","call_remote","reliable")
func accepted(at: Vector3) -> void:
	world.player.set_meta("peer_id",multiplayer.get_unique_id())
	rules.receive_event("spawn",{"position":at})
	joined=true
	connecting_since=0
	world.start_mode("sandbox")
	panel.hide()
	world.notify("Conectado a sala " + code)

func connection_failed() -> void:
	disconnect_room()
	status.text = "Falha: confira convite, porta UDP 28960 e firewall do anfitriao."
	world.activities.set_menu("network")
	panel.show()

func server_left() -> void:
	var was_joined := joined
	disconnect_room()
	if was_joined:
		world.activities.set_menu("pause")
		world.notify("O anfitriao encerrou a sala.")
	else:
		world.activities.set_menu("network")
		panel.show()
		status.text="Entrada recusada: confira o codigo e o limite de jogadores."

func peer_left(id: int) -> void:
	members.erase(id)
	rules.sheets.erase(id)
	if avatars.has(id):
		avatars[id].node.queue_free()
		avatars[id].tag.queue_free()
		avatars.erase(id)
	for index in owners.keys():
		if owners[index]==id:
			owners.erase(index)

func disconnect_room() -> void:
	hide_mission_offer()
	if internet!=null:
		internet.stop()
	joined=false
	connecting_since=0
	invitation.text=""
	discovery.close()
	if discovery.bind(0)==OK:
		discovery.set_broadcast_enabled(true)
	if peer != null:
		peer.close()
	peer = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	for avatar in avatars.values():
		avatar.node.queue_free()
		avatar.tag.queue_free()
	avatars.clear()
	members.clear()
	owners.clear()
	last_hit.clear()
	rules.sheets.clear()
	code = ""

func car_available(car: Node) -> bool:
	return not active() or int(owners.get(car.net_id,0)) in [0,multiplayer.get_unique_id()]

func local_state() -> Dictionary:
	return {"roll":world.player.roll_time/world.player.ROLL_DURATION,"held":Input.is_action_pressed("activity") and world.activities.menu=="","crouch":world.active_car==null and world.player.is_crouching,"weapon":world.activities.weapon,"name":world.profile.player_name,"outfit":world.profile.outfit,"position":world.player.position,"heading":world.player.model.rotation.y,"car":world.active_car.net_id if world.active_car!=null else -1,"car_position":world.subject_position(),"car_heading":world.active_car.heading if world.active_car!=null else 0.0,"speed":world.active_car.speed if world.active_car!=null else 0.0}

@rpc("any_peer","call_remote","unreliable_ordered",1)
func report(state: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if members.has(id):
		accept_state(id,state)

func accept_state(id: int, state: Dictionary) -> void:
	if not state.get("position") is Vector3 or not state.get("car_position") is Vector3:
		return
	var at: Vector3 = state.position
	if not at.is_finite() or at.x < -195 or at.x > 945 or absf(at.z)>153 or at.y < -10 or at.y>75:
		return
	if Time.get_ticks_msec()<int(members[id].get("elevator_target_until",0)):
		var arrival: Vector3=members[id].get("elevator_target",at)
		state.position=arrival
		state.car_position=arrival
		state.car=-1
		state.speed=0.0
		state["elevator_target"]=arrival
		state["elevator_target_until"]=members[id]["elevator_target_until"]
	else:
		members[id].erase("elevator_target")
		members[id].erase("elevator_target_until")
	# This timer is owned by the host; clients do not report arrest progress.
	state["arrest_progress"]=float(members[id].get("arrest_progress",0.0))
	var car_id := int(state.get("car",-1))
	for index in owners.keys():
		if owners[index]==id and index!=car_id:
			owners.erase(index)
	var selected_car: Node=world.car_by_id(car_id)
	if selected_car!=null and not selected_car.police and selected_car.hp>0 and int(owners.get(car_id,0)) in [0,id] and not rules.is_dead(id):
		owners[car_id]=id
		if not selected_car.owned:
			selected_car.owned=true
			world.raise_heat(12)
	else:
		state.car=-1
	state["name"]=Profile.clean_name(str(state.get("name","Jogador")))
	state["outfit"]=clampi(int(state.get("outfit",0)),0,5)
	if rules.sheets.has(id):
		var inv: Dictionary=rules.sheets[id].inventory
		var wanted := clampi(int(state.get("weapon",1)),0,7)
		if wanted in [0,1] or (wanted==2 and inv.rifle_owned) or (wanted==3 and inv.shotgun_owned) or (wanted==4 and inv.smg_owned) or (wanted>=5 and inv.heavy_owned[wanted-5]):
			inv.weapon=wanted
		state["weapon"]=inv.weapon
		state["hp"]=rules.sheets[id].health
		if rules.is_dead(id):
			state.position=members[id].get("position",state.position)
			state.car_position=state.position
			state.car=-1
			state.held=false
	var reported_roll = state.get("roll",0)
	var roll: float = float(reported_roll) if reported_roll is float or reported_roll is int else 0.0
	state["roll"] = clampf(roll,0,1) if is_finite(roll) and int(state.car)<0 and not rules.is_dead(id) else 0.0
	members[id]=state

func _process(delta: float) -> void:
	if connecting_since>0 and Time.get_ticks_msec()-connecting_since>15000:
		connection_failed()
	while discovery.get_available_packet_count()>0:
		var data = bytes_to_var(discovery.get_packet())
		var ip := discovery.get_packet_ip()
		var port := discovery.get_packet_port()
		if data is Dictionary and data.get("game")=="costa_query" and active() and multiplayer.is_server():
			discovery.set_dest_address(ip,port)
			discovery.put_packet(var_to_bytes({"game":"costa_livre_1","code":code,"players":members.size(),"version":announced_version}))
		if data is Dictionary and data.get("game")=="costa_livre_1" and str(data.get("code","")).length()==5:
			rooms[data.code]={"ip":ip,"time":Time.get_ticks_msec(),"players":clampi(int(data.get("players",1)),1,12),"version":str(data.get("version","antiga"))}
	for key in rooms.keys():
		if Time.get_ticks_msec()-rooms[key].time>4000:
			rooms.erase(key)
	if world.activities.menu=="network":
		refresh_room_list()
	if search_until>0 and Time.get_ticks_msec()>=search_until:
		search_until=0
		status.text="Nenhuma sala encontrada. Confira se os aparelhos estao no mesmo Wi-Fi." if rooms.is_empty() else "Selecione uma sala na lista e toque em Entrar."
	advertise_clock+=delta
	if not active():
		if world.activities.menu=="network" and advertise_clock>=0.8:
			advertise_clock=0
			discovery.set_dest_address("255.255.255.255",DISCOVERY)
			discovery.put_packet(var_to_bytes({"game":"costa_query"}))
		return
	for avatar in avatars.values():
		avatar.node.position=avatar.node.position.lerp(avatar.at,1-exp(-delta*14))
		avatar.tag.position=avatar.tag.position.lerp(avatar.tag_at,1-exp(-delta*14))
		avatar.node.rotation.y=lerp_angle(avatar.node.rotation.y,avatar.heading,1-exp(-delta*14))
	clock+=delta
	if clock<0.1:
		return
	clock=0
	if multiplayer.is_server():
		accept_state(1,local_state())
		if members.size()<=1:
			return
		for id in members:
			if id!=1 and not members[id].is_empty():
				apply_car(id,members[id])
		var cars: Array = []
		for car in world.cars:
			cars.append({"id":car.net_id,"position":car.position,"heading":car.heading,"speed":car.speed,"hp":car.hp,"tier":car.tier,"paint":car.paint,"police":car.police,"phase":car.police_phase,"owned":car.owned,"engine":car.engine_upgrade,"suspension":car.suspension_height,"wreck_timer":car.wreck_timer,"exploded":car.exploded,"despawn_timer":car.despawn_timer})
		var people: Array = []
		for person in world.life.people:
			people.append([person.position,person.model.rotation.y,person.hp,person.robbed])
		var officers: Array=[]
		for officer in world.activities.officers:
			officers.append([officer.position,officer.model.rotation.y,officer.hp,int(officer.get_meta("mission_contract",-1))])
		var game: Dictionary=rules.export_state()
		for id in members:
			if rules.sheets.has(id):
				members[id]["hp"]=rules.sheets[id].health
		packed_snapshot.rpc(var_to_bytes({"members":members,"owners":owners,"cars":cars,"people":people,"officers":officers,"game":game}).compress(FileAccess.COMPRESSION_DEFLATE))
		update_avatars(members)
	else:
		report.rpc_id(1,local_state())

func apply_car(id: int,state: Dictionary) -> void:
	var index := int(state.get("car",-1))
	var car: Node3D=world.car_by_id(index)
	if car!=null and car.hp>0 and owners.get(index,0)==id:
		var at: Vector3=state.car_position
		if at.is_finite() and absf(at.x)<185 and absf(at.z)<143 and at.y>=-2 and at.y<4:
			car.position=at
			car.heading=float(state.car_heading)
			car.rotation.y=car.heading
			car.speed=clampf(float(state.speed),-20,110)

@rpc("authority","call_remote","reliable",2)
func packed_snapshot(packet: PackedByteArray) -> void:
	if packet.size()>65536:
		return
	var decoded = bytes_to_var(packet.decompress_dynamic(262144,FileAccess.COMPRESSION_DEFLATE))
	if decoded is Dictionary:
		snapshot(decoded)

func snapshot(data: Dictionary) -> void:
	owners=data.owners
	members=data.members
	var present := {}
	for state in data.cars:
		var id := int(state.id)
		present[id]=true
		var car: Node3D=world.car_by_id(id)
		if car==null:
			car=world.spawn_car(state.position,state.paint,state.police,int(state.tier))
			car.net_id=id
			world.vehicle_sequence=maxi(world.vehicle_sequence,id+1)
		if car!=world.active_car:
			car.position=state.position
			car.heading=state.heading
			car.rotation.y=car.heading
			car.speed=state.speed
		elif owners.get(id,multiplayer.get_unique_id())!=multiplayer.get_unique_id():
			rules.receive_event("spawn",{"position":car.position+Vector3(3,0.5,0),"health":world.health})
		if car.paint!=state.paint:
			car.repaint(state.paint)
		if car.hp<=0 and state.hp>0:
			car.repair()
		car.apply_network_health(float(state.hp))
		car.apply_network_damage(float(state.wreck_timer),bool(state.exploded))
		car.despawn_timer=float(state.get("despawn_timer",car.despawn_timer))
		car.police_phase=state.phase
		car.owned=state.owned
		car.engine_upgrade=state.engine
		car.set_suspension(float(state.get("suspension",0)))
	for car in world.cars.duplicate():
		if not present.has(car.net_id):
			world.cars.erase(car)
			world.cops.erase(car)
			car.queue_free()
	world.cops.clear()
	for car in world.cars:
		if car.police and car.police_phase in ["exit","pursuit"]:
			world.cops.append(car)
	for i in mini(data.people.size(),world.life.people.size()):
		var person: Node3D=world.life.people[i]
		var state: Array=data.people[i]
		if person.visible:
			person.model.animate(1.6 if person.position.distance_squared_to(state[0])>0.0004 and state[2]>0 else 0.0)
		person.position=state[0]
		person.model.rotation.y=state[1]
		person.hp=state[2]
		person.robbed=state[3]
		person.collision_layer=0 if person.hp<=0 else 4
		person.model.rotation.z=PI/2 if person.hp<=0 else 0
	while world.activities.officers.size()>data.officers.size():
		world.activities.officers.pop_back().queue_free()
	while world.activities.officers.size()<data.officers.size():
		var officer := preload("res://scripts/officer.gd").new()
		officer.world=world
		world.add_child(officer)
		world.activities.officers.append(officer)
	for i in data.officers.size():
		var officer: Node3D=world.activities.officers[i]
		officer.model.animate(3.0 if officer.position.distance_to(data.officers[i][0])>0.03 else 0.0)
		officer.position=data.officers[i][0]
		officer.model.rotation.y=data.officers[i][1]
		officer.hp=data.officers[i][2]
		var contract: int = int(data.officers[i][3])
		if contract >= 0: officer.set_meta("mission_contract",contract)
		elif officer.has_meta("mission_contract"): officer.remove_meta("mission_contract")
		officer.model.rotation.z=PI/2 if officer.hp<=0 else 0
		officer.collision_layer=0 if officer.hp<=0 else 4
	rules.apply_state(data.game)
	update_avatars(members)

func update_avatars(states: Dictionary) -> void:
	for id in avatars.keys():
		if not states.has(id):
			peer_left(id)
	for id in states:
		if id==multiplayer.get_unique_id() or states[id].is_empty():
			continue
		if not avatars.has(id):
			var actor := preload("res://scripts/remote_player.gd").new()
			actor.world=world
			actor.peer_id=int(id)
			world.add_child(actor)
			actor.apply_outfit(clampi(int(states[id].get("outfit",0)),0,5))
			actor.position=states[id].position
			var tag := Profile.create_nametag(world,str(states[id].get("name","Jogador")))
			tag.position=actor.position+Vector3(0,2.5,0)
			avatars[id]={"node":actor,"at":actor.position,"heading":0.0,"outfit":actor.model.outfit_index,"tag":tag,"tag_at":tag.position}
		var state: Dictionary=states[id]
		var avatar: Dictionary=avatars[id]
		var outfit: int=clampi(int(state.get("outfit",0)),0,5)
		if avatar.outfit!=outfit:
			avatar.node.apply_outfit(outfit)
			avatar.outfit=outfit
		var player_name: String=Profile.clean_name(str(state.get("name","Jogador")))
		if avatar.tag.text!=player_name:
			avatar.tag.text=player_name
		avatar.tag_at=(state.car_position if int(state.car)>=0 else state.position)+Vector3(0,3.0 if int(state.car)>=0 else 2.5,0)
		var close: bool = avatar.tag_at.distance_to(world.subject_position())<80
		avatar.node.visible=int(state.car)<0 and close
		avatar.node.set_weapon(int(state.get("weapon",1)))
		avatar.node.set_crouched(bool(state.get("crouch",false)))
		var remaining: float = float(state.get("roll",0))
		avatar.node.model.rotation.x = (1.0-remaining)*TAU if remaining > 0 else 0.0
		var pivot := Vector3(0,0.92,0)
		avatar.node.model.position = pivot-Basis.from_euler(avatar.node.model.rotation)*pivot if remaining > 0 else Vector3(0,-0.28,0) if avatar.node.is_crouching else Vector3.ZERO
		avatar.node.collision_layer=2 if int(state.car)<0 and float(state.get("hp",100))>0 else 0
		avatar.node.model.rotation.z=PI/2 if float(state.get("hp",100))<=0 else 0
		avatar.tag.visible=close
		avatar.node.model.process_mode=Node.PROCESS_MODE_INHERIT if close else Node.PROCESS_MODE_DISABLED
		if close and int(state.car)<0:
			avatar.node.animate(3.0 if avatar.at.distance_squared_to(state.position)>0.0064 else 0.0)
		avatar.at=state.position
		if multiplayer.is_server():
			avatar.node.position=avatar.at
		avatar.heading=float(state.heading)

@rpc("any_peer","call_remote","reliable")
func request_hit(index: int, amount: float, vehicle := false) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if not members.has(id) or not is_finite(amount):
		return
	var car: Node=world.car_by_id(int(members[id].get("car",-1)))
	var target: Node=world.car_by_id(index) if vehicle else (world.life.people[index] if index>=0 and index<world.life.people.size() else null)
	if car==null or target==null or car.position.distance_to(target.position)>5:
		return
	rules.attacker=id
	target.take_hit(minf(100,absf(car.speed)*5))
	rules.attacker=0

@rpc("any_peer","call_remote","reliable")
func game_action(kind: String, data: Dictionary) -> void:
	if multiplayer.is_server() and members.has(multiplayer.get_remote_sender_id()):
		rules.action(multiplayer.get_remote_sender_id(),kind,data)

@rpc("authority","call_remote","reliable")
func personal(kind: String, data: Dictionary) -> void:
	rules.receive_event(kind,data)

@rpc("authority","call_local","unreliable",3)
func shot_effect(from: Vector3,to: Vector3,weapon: int) -> void:
	world.activities.shot_effect(from,to,weapon)

func authenticating(id: int) -> void:
	multiplayer.send_auth(id,var_to_bytes({"version":announced_version,"code":code,"platform":OS.get_name()}))

func authenticate(id: int,packet: PackedByteArray) -> void:
	if packet.size()>512:
		multiplayer.disconnect_peer.call_deferred(id)
		return
	var info = bytes_to_var(packet)
	if not info is Dictionary:
		multiplayer.disconnect_peer.call_deferred(id)
		return
	if info.get("version","")!=announced_version:
		refusal_reason="Versoes diferentes. Todos precisam usar a versao "+Build.VERSION+"."
	elif info.get("code","")!=code:
		refusal_reason="Codigo de sala incorreto."
	else:
		multiplayer.complete_auth(id)
		return
	multiplayer.disconnect_peer.call_deferred(id)
	if not multiplayer.is_server():
		authentication_failed.call_deferred(id)

func authentication_failed(_id: int) -> void:
	if peer!=null and not multiplayer.is_server():
		var reason := refusal_reason if not refusal_reason.is_empty() else "Conexao recusada. Confira a versao e o codigo da sala."
		disconnect_room()
		world.activities.set_menu("network")
		panel.show()
		status.text=reason


func _exit_tree() -> void:
	if peer!=null:
		peer.close()
	discovery.close()

func resize_panel() -> void:
	var bounds := get_viewport().get_visible_rect().size
	panel.size=Vector2(minf(740,bounds.x-32),minf(680,bounds.y-24))
	panel.position=(bounds-panel.size)/2

func ui_button(parent: Node, text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text=text
	button.custom_minimum_size.y=40
	button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	parent.add_child(button)

func add_help(parent: Node,text: String) -> void:
	var help := Label.new()
	help.text=text
	help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(help)

func search_rooms() -> void:
	if active():
		status.text="Desconecte da sala atual antes de procurar outra."
		return
	rooms.clear()
	list_signature=""
	room_list.clear()
	search_until=Time.get_ticks_msec()+3500
	advertise_clock=1
	status.text="Procurando salas no Wi-Fi..."

func refresh_room_list() -> void:
	var keys := rooms.keys()
	keys.sort()
	var signature := ""
	for key in keys:
		signature+=str(key)+str(rooms[key].get("players",1))+str(rooms[key].get("version",""))
	if signature==list_signature:
		return
	var selected := ""
	if not room_list.get_selected_items().is_empty():
		selected=room_list.get_item_metadata(room_list.get_selected_items()[0])
	list_signature=signature
	room_list.clear()
	for key in keys:
		var index := room_list.add_item("Sala %s     |     %d/12 jogadores" % [key,rooms[key].get("players",1)])
		room_list.set_item_metadata(index,key)
		if rooms[key].get("version","")!=announced_version:
			room_list.set_item_text(index,room_list.get_item_text(index)+" / versao diferente")
			room_list.set_item_disabled(index,true)
		if key==selected:
			room_list.select(index)

func join_selected_room() -> void:
	var selection := room_list.get_selected_items()
	if selection.is_empty():
		status.text="Primeiro procure e selecione uma sala na lista."
		return
	var selected: String=room_list.get_item_metadata(selection[0])
	if not rooms.has(selected):
		status.text="A sala saiu da lista. Procure novamente."
		return
	connect_target({"address":rooms[selected].ip,"port":PORT,"code":selected})

static func make_internet_code(address: String, port: int, selected: String) -> String:
	if not address.is_valid_ip_address() or address.contains(":") or port<1 or port>65535 or selected.length()!=5:
		return ""
	var data := PackedByteArray()
	for part in address.split("."):
		data.append(part.to_int())
	data.resize(6)
	data.encode_u16(4,port)
	data.append_array(selected.to_upper().to_utf8_buffer())
	data.append_array(data.hex_encode().sha256_buffer().slice(0,2))
	var result := ""
	var accumulator := 0
	var bits := 0
	for byte in data:
		accumulator=(accumulator<<8)|byte
		bits+=8
		while bits>=5:
			bits-=5
			result+=SYMBOLS[(accumulator>>bits)&31]
		accumulator &= (1<<bits)-1
	if bits>0:
		result+=SYMBOLS[(accumulator<<(5-bits))&31]
	return "CL1-"+result.substr(0,7)+"-"+result.substr(7,7)+"-"+result.substr(14)

static func decode_internet_code(text: String) -> Dictionary:
	var value := text.strip_edges().to_upper().substr(4).replace("-","").replace(" ","")
	if value.length()!=21:
		return {}
	var data := PackedByteArray()
	var accumulator := 0
	var bits := 0
	for symbol in value:
		var digit := SYMBOLS.find(symbol)
		if digit<0:
			return {}
		accumulator=(accumulator<<5)|digit
		bits+=5
		if bits>=8:
			bits-=8
			data.append((accumulator>>bits)&255)
		accumulator &= (1<<bits)-1
	if data.size()!=13 or accumulator!=0:
		return {}
	var payload := data.slice(0,11)
	if payload.hex_encode().sha256_buffer().slice(0,2)!=data.slice(11):
		return {}
	var address := "%d.%d.%d.%d" % [data[0],data[1],data[2],data[3]]
	return parse_target("CL://%s:%d/%s" % [address,data.decode_u16(4),data.slice(6,11).get_string_from_utf8()],"")
