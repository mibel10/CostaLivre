extends Node

const Build = preload("res://scripts/build_version.gd")
const Profile = preload("res://scripts/player_profile.gd")
const PORT := 28960
const DISCOVERY := 28961
const SYMBOLS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const CHAT_LIMIT := 140
const CHAT_RATE_MS := 700
const SNAPSHOT_PACKET_LIMIT := 1200
const EMOTES := ["wave","griddy","take_l","dance","torture_dance"]
var world: Node3D
var code := ""
var peer: ENetMultiplayerPeer
var discovery := PacketPeerUDP.new()
var rooms := {}
var members := {}
var last_hit := {}
var last_state_at := {}
var avatars := {}
var owners := {}
var clock := 0.0
var snapshot_tick := 0
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
var chat_panel: PanelContainer
var chat_toggle: Button
var chat_log: RichTextLabel
var chat_input: LineEdit
var chat_history: Array[String] = []
var chat_last_sent := {}
var emote_last_sent := {}

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
	ui_button(offer_buttons, "ACEITAR" if OS.has_feature("android") else "L · ACEITAR", answer_mission_offer.bind(true))
	ui_button(offer_buttons, "RECUSAR" if OS.has_feature("android") else "K · RECUSAR", answer_mission_offer.bind(false))
	if OS.has_feature("android"):
		for button in offer_buttons.get_children():
			button.custom_minimum_size.y = 64
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
	var chat_layer := CanvasLayer.new()
	chat_layer.layer = 120
	add_child(chat_layer)
	chat_toggle = Button.new()
	chat_toggle.text = "CHAT" if OS.has_feature("android") else "Y · CHAT"
	chat_toggle.theme = world.pause_menu.canvas.theme
	chat_toggle.custom_minimum_size = Vector2(128, 44)
	chat_toggle.pressed.connect(toggle_chat)
	chat_layer.add_child(chat_toggle)
	chat_toggle.hide()
	chat_panel = PanelContainer.new()
	chat_panel.theme = world.pause_menu.canvas.theme
	chat_panel.visible = false
	chat_layer.add_child(chat_panel)
	var chat_column := VBoxContainer.new()
	chat_panel.add_child(chat_column)
	chat_log = RichTextLabel.new()
	chat_log.bbcode_enabled = false
	chat_log.scroll_active = true
	chat_log.scroll_following = true
	chat_log.custom_minimum_size = Vector2(300, 126)
	chat_column.add_child(chat_log)
	var chat_row := HBoxContainer.new()
	chat_column.add_child(chat_row)
	chat_input = LineEdit.new()
	chat_input.max_length = CHAT_LIMIT
	chat_input.placeholder_text = "Mensagem para quem está perto... (/local compartilha sua posição)"
	chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_input.text_submitted.connect(func(_text): send_chat())
	chat_row.add_child(chat_input)
	var chat_send := Button.new()
	chat_send.text = "Enviar"
	chat_send.pressed.connect(send_chat)
	chat_row.add_child(chat_send)
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
	close_chat()
	if world.activities.menu!="network":
		return_menu=world.activities.menu
	world.activities.set_menu("network")
	panel.show()
	resize_panel.call_deferred()
	status.text = ("SALA %s / %d DE 12" % [code,members.size()]) if active() else "Escolha Salas locais ou Pela internet."

func show_mission_offer(index: int, host_name: String) -> void:
	var titles: Array=world.activities.JOBS
	offer_text.text="%s convida você para %s.\n\nAo aceitar, você vai para a entrada da missão." % [host_name,titles[index] if index == 33 else titles[clampi(index,24,28)]]
	world.hud.set_phone_invite_available(true)
	offer_panel.show()
	world.restore_pointer()

func open_mission_offer() -> void:
	if offer_panel != null and is_instance_valid(offer_panel) and world.hud.invite_available:
		offer_panel.show()
		world.restore_pointer()

func hide_mission_offer() -> void:
	world.hud.set_phone_invite_available(false)
	if is_instance_valid(offer_panel) and offer_panel.visible:
		offer_panel.hide()
		world.restore_pointer()

func answer_mission_offer(accept: bool) -> void:
	if offer_panel.visible:
		rules.send_action("mission_response", {"accept": accept})
		hide_mission_offer()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if world.activities.menu == "" and event.physical_keycode in [KEY_G,KEY_F6,KEY_F7,KEY_F8,KEY_F9]:
			send_emote({KEY_G:"wave",KEY_F6:"griddy",KEY_F7:"take_l",KEY_F8:"dance",KEY_F9:"torture_dance"}[event.physical_keycode])
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_ESCAPE and chat_panel.visible:
			close_chat()
			get_viewport().set_input_as_handled()
			return
		if event.physical_keycode == KEY_Y and active() and world.activities.menu == "" and not chat_panel.visible:
			open_chat()
			get_viewport().set_input_as_handled()
			return
	if is_instance_valid(offer_panel) and offer_panel.visible and event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_L, KEY_K]:
			get_viewport().set_input_as_handled()
			answer_mission_offer(event.physical_keycode == KEY_L)

func toggle_chat() -> void:
	if chat_panel.visible:
		close_chat()
	else:
		open_chat()

func open_chat() -> void:
	if not active() or world.activities.menu != "":
		return
	chat_panel.show()
	chat_toggle.text = "FECHAR CHAT"
	world.activities.menu = "chat"
	world.engine_audio.stream_paused = true
	world.restore_pointer()
	chat_input.grab_focus()
	world.hud.queue_redraw()

func close_chat() -> void:
	if is_instance_valid(chat_panel):
		chat_panel.hide()
	if is_instance_valid(chat_input):
		chat_input.release_focus()
	if world.activities.menu == "chat":
		world.activities.menu = ""
	world.engine_audio.stream_paused = world.activities.menu != ""
	if is_instance_valid(chat_toggle):
		chat_toggle.text = "CHAT" if OS.has_feature("android") else "Y · CHAT"
	world.restore_pointer()
	world.hud.queue_redraw()

func send_chat() -> void:
	if not active():
		return
	var message := chat_input.text.strip_edges().replace("\n", " ").replace("\r", " ").replace("\t", " ")
	chat_input.clear()
	if message.is_empty():
		chat_input.grab_focus()
		return
	if multiplayer.is_server():
		relay_chat(1, message)
	else:
		submit_chat.rpc_id(1, message)
	chat_input.grab_focus()

func send_emote(name: String) -> void:
	if not name in EMOTES:
		return
	var local_id := multiplayer.get_unique_id() if active() else 1
	var now := Time.get_ticks_msec()
	if now-int(emote_last_sent.get(local_id,0))<800:
		return
	emote_last_sent[local_id]=now
	if not active():
		world.player.model.play_emote(name)
		return
	if multiplayer.is_server():
		apply_emote(local_id,name)
	else:
		world.player.model.play_emote(name)
		request_emote.rpc_id(1,name)

func apply_emote(id: int, name: String) -> void:
	if not members.has(id):
		return
	members[id]["emote"] = name
	members[id]["emote_seq"] = int(members[id].get("emote_seq",0))+1
	if id == multiplayer.get_unique_id():
		world.player.model.play_emote(name)

@rpc("any_peer","call_remote","reliable")
func request_emote(name: String) -> void:
	if not multiplayer.is_server() or name not in EMOTES:
		return
	var id := multiplayer.get_remote_sender_id()
	var now := Time.get_ticks_msec()
	if not members.has(id) or now-int(emote_last_sent.get(id,0))<800:
		return
	emote_last_sent[id]=now
	apply_emote(id,name)

func close_menu() -> void:
	panel.hide()
	world.activities.set_menu("" if active() else return_menu)

func host() -> void:
	if world.restart_after_admin():
		return
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
	if world.restart_after_admin():
		return
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
	last_state_at.erase(id)
	chat_last_sent.erase(id)
	emote_last_sent.erase(id)
	vehicle_grants.erase(id)
	world.vehicle_entries.erase(id)
	world.vehicle_falls.erase(id)
	rules.sheets.erase(id)
	rules.mission_invites.erase(id)
	rules.stand_history.erase(id)
	if rules.mission_hacking_peer == id:
		rules.mission_hacking_peer = 0
	rules.pvp_queue.erase(id)
	rules.pvp_saved.erase(id)
	if rules.pvp.has("teams"):
		rules.pvp.teams.erase(id)
	if multiplayer.is_server():
		rules.refresh_wanted_heat()
	rules.bus_riders.erase(id)
	if avatars.has(id):
		avatars[id].node.queue_free()
		avatars[id].tag.queue_free()
		avatars.erase(id)
	for index in owners.keys():
		if owners[index]==id:
			owners.erase(index)

func disconnect_room() -> void:
	if active() and multiplayer.is_server() and not rules.pvp.is_empty(): rules.finish_pvp(-1)
	rules.sync_stand_walls([])
	rules.pvp.clear()
	rules.pvp_queue.clear()
	rules.pvp_saved.clear()
	rules.stand_history.clear()
	rules.stand_fields.clear()
	close_chat()
	chat_history.clear()
	chat_last_sent.clear()
	if is_instance_valid(chat_log):
		chat_log.clear()
	hide_mission_offer()
	world.life.leave_elevator_session()
	world.vehicle_entries.clear()
	world.vehicle_falls.clear()
	if world.active_car == null and not world.finished:
		world.player.show()
	vehicle_grants.clear()
	if world.bus_passenger:
		var offset: Vector3 = world.vehicle_exit_offset(world.active_car)
		var at: Vector3 = world.active_car.to_global(offset) if offset != Vector3.ZERO else world.SPAWNS[0]
		rules.receive_event("bus_exit", {"position": at})
	if internet!=null:
		internet.stop()
	joined=false
	connecting_since=0
	invitation.text=""
	discovery.close()
	if discovery.bind(0)==OK:
		discovery.set_broadcast_enabled(true)
	if peer != null:
		rules.clear_wanted()
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
	last_state_at.clear()
	rules.sheets.clear()
	rules.bus_riders.clear()
	rules.mission_invites.clear()
	rules.pending_mission = -1
	rules.mission_offer_deadline = 0
	rules.mission_offer_started = false
	rules.mission_hacking_peer = 0
	rules.bank_owner = 1
	rules.bank_lookout = 0
	rules.last_actions.clear()
	rules.visible_police.clear()
	rules.robbery_worker = 0
	world.activities.bank.hacking = false
	world.activities.robbery_index = -1
	world.activities.robbery_progress = 0.0
	world.activities.clear_pedestrian_robbery()
	code = ""

var vehicle_grants := {}

func car_available(car: Node) -> bool:
	return not active() or int(owners.get(car.net_id,0)) in [0,multiplayer.get_unique_id()]

func local_state() -> Dictionary:
	return {"aim_weapon":world.player.aim_weapon,"weapon_pitch":world.player.weapon_pitch,"roll":world.player.roll_time/world.player.ROLL_DURATION,"held":Input.is_action_pressed("activity") and world.activities.menu=="","crouch":world.active_car==null and world.player.is_crouching,"weapon":world.activities.weapon,"name":world.profile.player_name,"outfit":world.profile.appearance_code(),"position":world.player.position,"heading":world.player.model.rotation.y,"car":world.active_car.net_id if world.active_car!=null and not world.bus_passenger else -1,"car_position":world.subject_position(),"car_heading":world.active_car.heading if world.active_car!=null else 0.0,"speed":world.active_car.speed if world.active_car!=null else 0.0}

@rpc("any_peer","call_remote","unreliable_ordered",1)
func report(state: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if members.has(id):
		accept_state(id,state)

func valid_session_position(at: Vector3) -> bool:
	return at.is_finite() and at.x >= -195 and at.x <= world.MAP_EAST + 5.0 and absf(at.z) <= 153 and at.y >= -10 and at.y <= 75

func accept_state(id: int, state: Dictionary) -> void:
	if not state.get("position") is Vector3 or not state.get("car_position") is Vector3:
		return
	var at: Vector3 = state.position
	var car_at: Vector3 = state.car_position
	if not valid_session_position(at) or not valid_session_position(car_at):
		return
	for key in ["heading", "car_heading", "speed", "weapon_pitch", "roll"]:
		var value = state.get(key, 0.0)
		if not (value is float or value is int) or not is_finite(float(value)):
			return
	var car_value = state.get("car", -1)
	if not car_value is int:
		return
	var riding = world.life.elevator_rider_position(id)
	if riding is Vector3:
		state.position = riding
		state.car_position = riding
		state.car = -1
		state.speed = 0.0
		state.held = false
	elif Time.get_ticks_msec()<int(members[id].get("elevator_target_until",0)):
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
	if int(rules.sheets.get(id, {}).get("prison_stage", -1)) >= 0:
		state.position = Vector3(clampf(state.position.x, 1005.5, 1064.5), clampf(state.position.y, 0.0, 5.0), clampf(state.position.z, 35.5, 74.0))
		state.car_position = state.position
		state.car = -1
		state.speed = 0.0
	# This timer is owned by the host; clients do not report arrest progress.
	state["arrest_progress"]=float(members[id].get("arrest_progress",0.0))
	state.erase("bus")
	if rules.bus_riders.has(id):
		var bus: Node3D = world.car_by_id(rules.bus_riders[id])
		if bus != null:
			state["bus"] = bus.net_id
			state["position"] = bus.position
			state["car_position"] = bus.position
			state["car"] = -1
			state["held"] = false
	if world.vehicle_falls.has(id):
		state.position = world.vehicle_falls[id].at
		state.car_position = state.position
		state.car = -1
		state.held = false
	if world.vehicle_entries.has(id):
		var entry: Dictionary = world.vehicle_entries[id]
		state.position = entry.at
		state.car_position = entry.at
		state.car = -1
		state.held = false
	var car_id := int(state.get("car",-1))
	if vehicle_grants.has(id):
		var grant: Array = vehicle_grants[id]
		if car_id == int(grant[0]) or Time.get_ticks_msec() >= int(grant[1]):
			vehicle_grants.erase(id)
		else:
			car_id = int(grant[0])
			state.car = car_id
			var granted_car: Node3D = world.car_by_id(car_id)
			if granted_car != null:
				state.car_position = granted_car.position
				state.speed = granted_car.speed
				state.car_heading = granted_car.heading
	for index in owners.keys():
		if owners[index]==id and index!=car_id:
			owners.erase(index)
	var selected_car: Node=world.car_by_id(car_id)
	if id != 1 and not world.vehicle_falls.has(id) and not world.vehicle_entries.has(id) and not rules.bus_riders.has(id) and world.life.elevator_rider_position(id) == null and Time.get_ticks_msec() >= int(members[id].get("elevator_target_until", 0)):
		var previous: Vector3 = members[id].get("car_position", state.car_position)
		var now := Time.get_ticks_msec()
		var previous_time: int = int(last_state_at.get(id, now))
		var elapsed: float = maxf(0.05, float(now - previous_time) / 1000.0)
		var max_horizontal_speed := 22.0
		if selected_car != null:
			max_horizontal_speed = selected_car.Catalog.SPEEDS[selected_car.tier] + selected_car.engine_upgrade + 5.0
		if selected_car == null and float(rules.sheets.get(id,{}).get("stand_slow",0.0)) > 0.0:
			max_horizontal_speed *= 0.35
		var displacement := Vector2(state.car_position.x - previous.x, state.car_position.z - previous.z).length()
		if displacement > max_horizontal_speed * elapsed + 4.0 or absf(state.car_position.y - previous.y) > 35.0 * elapsed + 4.0:
			return
	last_state_at[id] = Time.get_ticks_msec()
	if selected_car!=null and not selected_car.police and selected_car.hp>0 and int(owners.get(car_id,0)) == id and not rules.is_dead(id):
		owners[car_id]=id
		if selected_car.tumbling or Time.get_ticks_msec() < selected_car.tumble_lock_until:
			state.car_position = selected_car.position
			state.speed = selected_car.speed
		if not selected_car.owned:
			selected_car.owned=true
			world.raise_heat(12, id)
	else:
		state.car=-1
	state["name"]=Profile.clean_name(str(state.get("name","Jogador")))
	state["outfit"]=clampi(int(state.get("outfit",0)),0,47)
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
	var pitch = state.get("weapon_pitch", 0.0)
	state["weapon_pitch"] = clampf(float(pitch), -1.35, 1.35) if (pitch is float or pitch is int) and is_finite(float(pitch)) else 0.0
	state["aim_weapon"] = state.get("aim_weapon") == true and int(state.get("weapon", 0)) > 0 and int(state.car) < 0 and not state.has("bus") and state.roll == 0.0 and not riding is Vector3 and not rules.is_dead(id) and not world.vehicle_entries.has(id) and not world.vehicle_falls.has(id)
	var emote := str(members[id].get("emote", ""))
	var emote_seq := int(members[id].get("emote_seq", 0))
	state.erase("emote")
	state.erase("emote_seq")
	members[id]=state
	if emote_seq > 0:
		members[id]["emote"] = emote
		members[id]["emote_seq"] = emote_seq

func _process(delta: float) -> void:
	if chat_panel.visible and (not active() or world.activities.menu != "chat"):
		close_chat()
	chat_toggle.visible = active() and world.activities.menu in ["", "chat"]
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
		for id in rules.bus_riders:
			var bus: Node3D = world.car_by_id(rules.bus_riders[id])
			if bus != null:
				members[id]["position"] = bus.position
				members[id]["car_position"] = bus.position
		var car_ids: Array = []
		snapshot_tick += 1
		for car in world.cars:
			car_ids.append(car.net_id)
		var officers: Array=[]
		for officer in world.activities.officers:
			officers.append([officer.position,officer.model.rotation.y,officer.hp,int(officer.get_meta("mission_contract",-1))])
		var mission_car_ids := {}
		if is_instance_valid(world.activities.target_car):
			mission_car_ids[world.activities.target_car.net_id] = true
		for target in world.activities.targets:
			mission_car_ids[target.net_id] = true
		var game: Dictionary=rules.export_state()
		for id in members:
			if rules.sheets.has(id):
				members[id]["hp"]=rules.sheets[id].health
		var session_packet: PackedByteArray = var_to_bytes({"members":members,"owners":owners,"entries":world.vehicle_entries,"car_ids":car_ids}).compress(FileAccess.COMPRESSION_DEFLATE)
		var game_packet: PackedByteArray = var_to_bytes({"officers":officers,"game":game}).compress(FileAccess.COMPRESSION_DEFLATE)
		var car_state_cache := {}
		for peer_id in members:
			if int(peer_id) == 1 or members[peer_id].is_empty():
				continue
			var member: Dictionary = members[peer_id]
			var observer: Vector3 = member.get("car_position", member.get("position", world.player.position))
			var relevant_cars: Array = []
			for car in world.cars:
				var car_id: int = car.net_id
				var close: bool = car.position.distance_squared_to(observer) < 10000.0
				var assigned: bool = int(owners.get(car_id, 0)) == int(peer_id) or int(rules.bus_riders.get(int(peer_id), -1)) == car_id
				var mission: bool = mission_car_ids.has(car_id)
				var distant_refresh: bool = posmod(car_id + int(peer_id), 10) == snapshot_tick % 10
				if close or assigned or mission or distant_refresh:
					var car_state: Dictionary = car_state_cache.get(car_id, {})
					if car_state.is_empty():
						car_state = {"id":car_id,"position":car.position,"heading":car.heading,"speed":car.speed,"hp":car.hp,"tier":car.tier,"paint":car.paint,"police":car.police,"phase":car.police_phase,"owned":car.owned,"hovering":car.hovering,"engine":car.engine_upgrade,"suspension":car.suspension_height,"wreck_timer":car.wreck_timer,"exploded":car.exploded,"despawn_timer":car.despawn_timer,"fuel":car.fuel,"refuel_time":car.refuel_time}
						if car.has_meta("rival_name"):
							car_state["rival_name"] = str(car.get_meta("rival_name"))
							car_state["traffic"] = car.traffic
							car_state["route"] = car.route.duplicate()
							car_state["route_index"] = car.route_index
						if car.tumbling:
							car_state["tumble_rotation"] = car.rotation
						car_state_cache[car_id] = car_state
					relevant_cars.append(car_state)
			var people: Array = []
			for person_index in world.life.people.size():
				var person: Node3D = world.life.people[person_index]
				var close: bool = person.position.distance_squared_to(observer) <= 4225.0
				var distant_refresh: bool = posmod(person_index + int(peer_id), 10) == snapshot_tick % 10
				if close or distant_refresh:
					people.append([person_index,person.position,person.model.rotation.y,person.hp,person.robbed])
			packed_snapshot.rpc_id(int(peer_id), session_packet)
			packed_snapshot.rpc_id(int(peer_id), game_packet)
			var entity_count: int = relevant_cars.size() + people.size()
			var chunk_size := 1
			var packets: Array[PackedByteArray] = []
			# Entity-only deltas can be split without duplicating the authoritative session state.
			while entity_count > 0:
				var chunk_count: int = mini(chunk_size, maxi(1, entity_count))
				var oversized := false
				packets.clear()
				for chunk_index in chunk_count:
					var car_chunk: Array = []
					for car_index in relevant_cars.size():
						if car_index % chunk_count == chunk_index:
							car_chunk.append(relevant_cars[car_index])
					var people_chunk: Array = []
					for person_index in people.size():
						if person_index % chunk_count == chunk_index:
							people_chunk.append(people[person_index])
					var payload := {"cars":car_chunk,"people":people_chunk}
					var packet: PackedByteArray = var_to_bytes(payload).compress(FileAccess.COMPRESSION_DEFLATE)
					packets.append(packet)
					oversized = oversized or packet.size() > SNAPSHOT_PACKET_LIMIT
				if not oversized or chunk_count >= entity_count:
					break
				chunk_size *= 2
			for packet in packets:
				packed_snapshot.rpc_id(int(peer_id), packet)
		update_avatars(members)
	else:
		report.rpc_id(1,local_state())

func apply_car(id: int,state: Dictionary) -> void:
	var index := int(state.get("car",-1))
	var car: Node3D=world.car_by_id(index)
	if car!=null and car.hp>0 and owners.get(index,0)==id and not world.vehicle_held_for_entry(index):
		if car.tumbling or Time.get_ticks_msec() < car.tumble_lock_until:
			state.car_position = car.position
			state.speed = car.speed
			return
		var at: Vector3=state.car_position
		var heading_value = state.get("car_heading", 0.0)
		var speed_value = state.get("speed", 0.0)
		if not (heading_value is float or heading_value is int) or not (speed_value is float or speed_value is int):
			return
		if not is_finite(heading_value) or not is_finite(speed_value):
			return
		# Match the vehicle recovery bounds so the favela ramp works for remote drivers.
		if at.is_finite() and at.x>=-195 and at.x<=world.MAP_EAST + 5.0 and absf(at.z)<143 and at.y>=-6.0 and at.y<=20.0:
			var fall_speed: float = (at.y - car.position.y) * 10.0
			world.check_vehicle_entry(car.position, at, id)
			car.position=at
			car.heading=wrapf(float(heading_value), -PI, PI)
			car.rotation.y=car.heading
			car.crush_underneath()
			var limit: float = car.Catalog.SPEEDS[car.tier] if car.tier == car.Catalog.BUS else car.Catalog.SPEEDS[car.tier] + car.engine_upgrade
			if car.tier == car.Catalog.SUPERCAR:
				limit = car.Catalog.HOVER_SPEED if car.hovering else car.Catalog.SPEEDS[car.tier]
			car.speed=0.0 if car.fuel <= 0.0 else clampf(float(speed_value),-20,limit)
			if fall_speed < -3.5 and car.has_tumble_clearance():
				car.begin_tumble(-car.global_basis.z * car.speed + Vector3.UP * maxf(-28.0, fall_speed))

# Newer state replaces missed ticks; all vehicles are refreshed every five ticks.
@rpc("authority","call_remote","unreliable_ordered",2)
func packed_snapshot(packet: PackedByteArray) -> void:
	if packet.size()>65536:
		return
	var decoded = bytes_to_var(packet.decompress_dynamic(262144,FileAccess.COMPRESSION_DEFLATE))
	if decoded is Dictionary:
		snapshot(decoded)

func snapshot(data: Dictionary) -> void:
	if data.has("owners"):
		owners=data.owners
	if data.has("members"):
		members=data.members
	if data.has("entries"):
		world.vehicle_entries=data.entries
	var present := {}
	if data.has("car_ids"):
		for id in data.car_ids:
			present[int(id)] = true
	var local_cars := {}
	if data.has("cars"):
		for car in world.cars:
			local_cars[car.net_id] = car
	for state in data.get("cars", []):
		var id := int(state.id)
		var car: Node3D = local_cars.get(id)
		if car != null and (car.tier != int(state.tier) or car.police != bool(state.police)):
			discard_snapshot_car(car)
			car = null
		if car==null:
			car=world.spawn_car(state.position,state.paint,state.police,int(state.tier))
			car.net_id=id
			world.vehicle_sequence=maxi(world.vehicle_sequence,id+1)
		var tumbling: bool = state.has("tumble_rotation")
		if car!=world.active_car or world.bus_passenger or tumbling or car.tumbling:
			car.position=state.position
			car.heading=state.heading
			car.rotation = state.get("tumble_rotation", Vector3(0, car.heading, 0))
			car.speed=state.speed
			if tumbling or car.tumbling:
				car.velocity = Vector3.ZERO
		elif owners.get(id,multiplayer.get_unique_id())!=multiplayer.get_unique_id():
			rules.receive_event("spawn",{"position":car.position+Vector3(3,0.5,0),"health":world.health})
		car.tumbling = tumbling
		if car.paint!=state.paint:
			car.repaint(state.paint)
		if car.hp<=0 and state.hp>0:
			car.repair()
		car.apply_network_health(float(state.hp))
		car.apply_network_damage(float(state.wreck_timer),bool(state.exploded))
		car.despawn_timer=float(state.get("despawn_timer",car.despawn_timer))
		car.fuel=clampf(float(state.get("fuel",car.fuel)),0.0,1.0)
		car.refuel_time=maxf(0.0,float(state.get("refuel_time",0.0)))
		car.police_phase=state.phase
		car.owned=state.owned
		car.hovering=bool(state.get("hovering", false))
		car.engine_upgrade=state.engine
		car.set_suspension(float(state.get("suspension",0)))
		if state.has("rival_name"):
			world.mark_street_rival(car,str(state.rival_name))
			car.traffic = bool(state.get("traffic",true))
			car.route.assign(state.get("route",[]))
			car.route_index = int(state.get("route_index",0))
		elif car.has_meta("rival_name"):
			car.remove_meta("rival_name")
			var rival_tag := car.get_node_or_null("RivalTag")
			if rival_tag != null:
				rival_tag.queue_free()
	if data.has("car_ids"):
		for car in world.cars.duplicate():
			if not present.has(car.net_id):
				discard_snapshot_car(car)
	if data.has("cars"):
		world.cops.clear()
		for car in world.cars:
			if car.police and car.police_phase in ["exit","pursuit"]:
				world.cops.append(car)
	for state in data.get("people", []):
		var person_index: int = int(state[0])
		if person_index < 0 or person_index >= world.life.people.size():
			continue
		var person: Node3D=world.life.people[person_index]
		if person.visible:
			person.model.animate(1.6 if person.position.distance_squared_to(state[1])>0.0004 and state[3]>0 else 0.0)
		person.position=state[1]
		person.model.rotation.y=state[2]
		person.hp=state[3]
		person.robbed=state[4]
		person.collision_layer=0 if person.hp<=0 else 4
		person.model.rotation.z=PI/2 if person.hp<=0 else 0
	if data.has("officers"):
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
	if data.has("game"):
		rules.apply_state(data.game)
	if data.has("members"):
		update_avatars(members)

func discard_snapshot_car(car: Node3D) -> void:
	if car == world.active_car:
		var offset: Vector3 = world.vehicle_exit_offset(car)
		var at: Vector3 = car.to_global(offset) if offset != Vector3.ZERO else car.position + Vector3.UP * 0.3
		rules.receive_event("bus_exit" if world.bus_passenger else "spawn", {"position": at, "health": world.health})
	world.cars.erase(car)
	world.cops.erase(car)
	car.queue_free()

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
			actor.apply_outfit(clampi(int(states[id].get("outfit",0)),0,47))
			actor.position=states[id].position
			var tag := Profile.create_nametag(world,str(states[id].get("name","Jogador")))
			tag.position=actor.position+Vector3(0,2.5,0)
			avatars[id]={"node":actor,"at":actor.position,"heading":0.0,"outfit":actor.model.outfit_index,"tag":tag,"tag_at":tag.position,"emote_seq":int(states[id].get("emote_seq",0))}
		var state: Dictionary=states[id]
		var on_foot := int(state.car) < 0 and not state.has("bus")
		var avatar: Dictionary=avatars[id]
		var emote_seq := int(state.get("emote_seq",0))
		if emote_seq != int(avatar.get("emote_seq",0)):
			avatar.node.model.play_emote(str(state.get("emote","wave")))
			avatar["emote_seq"] = emote_seq
		var outfit: int=clampi(int(state.get("outfit",0)),0,47)
		if avatar.outfit!=outfit:
			avatar.node.apply_outfit(outfit)
			avatar.outfit=outfit
		var player_name: String=Profile.clean_name(str(state.get("name","Jogador")))
		if avatar.tag.text!=player_name:
			avatar.tag.text=player_name
		avatar.tag_at=(state.car_position if int(state.car)>=0 else state.position)+Vector3(0,3.0 if int(state.car)>=0 else 2.5,0)
		var close: bool = avatar.tag_at.distance_to(world.subject_position())<80
		avatar.node.visible=on_foot and close and not world.vehicle_falls.has(id)
		avatar.node.set_weapon(clampi(int(state.get("weapon", 1)), 0, 7), rules.sheets.get(id, {}).get("inventory", {}))
		avatar.node.set_crouched(bool(state.get("crouch",false)))
		var remaining: float = float(state.get("roll",0))
		avatar.node.aim_weapon = bool(state.get("aim_weapon", false))
		avatar.node.weapon_pitch = float(state.get("weapon_pitch", 0.0))
		avatar.node.can_point_weapon = on_foot and remaining == 0.0 and float(state.get("hp", 100)) > 0.0 and not world.vehicle_entries.has(id)
		avatar.node.model.rotation.x = (1.0-remaining)*TAU if remaining > 0 else 0.0
		var pivot := Vector3(0,0.92,0)
		avatar.node.model.position = pivot-Basis.from_euler(avatar.node.model.rotation)*pivot if remaining > 0 else Vector3.ZERO
		avatar.node.collision_layer=2 if on_foot and float(state.get("hp",100))>0 else 0
		avatar.node.model.rotation.z=PI/2 if float(state.get("hp",100))<=0 else 0
		avatar.tag.visible=close and not state.has("bus") and not world.vehicle_falls.has(id)
		avatar.node.model.process_mode = Node.PROCESS_MODE_INHERIT if avatar.node.visible else Node.PROCESS_MODE_DISABLED
		if avatar.node.visible and float(state.get("hp", 100)) > 0.0:
			avatar.node.animate(3.0 if avatar.at.distance_squared_to(state.position)>0.0064 else 0.0)
		avatar.at=state.position
		if world.vehicle_entries.has(id):
			var entry: Dictionary = world.vehicle_entries[id]
			var car: Node3D = world.car_by_id(entry.car)
			if is_instance_valid(car):
				avatar.node.model.pose_vehicle_entry(avatar.node,car,entry.side,entry.time*world.VEHICLE_ENTRY_TIME/entry.duration)
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
	if car==null or target==null or owners.get(car.net_id,0)!=id or absf(car.speed)<=3.0 or car.position.distance_to(target.position)>5:
		return
	var now := Time.get_ticks_msec()
	var hit_key := "hit:%d:%s:%d" % [id, "vehicle" if vehicle else "pedestrian", index]
	if now - int(rules.last_actions.get(hit_key, 0)) < 400:
		return
	rules.last_actions[hit_key] = now
	for key in rules.last_actions.keys():
		if str(key).begins_with("hit:") and now - int(rules.last_actions[key]) > 2000:
			rules.last_actions.erase(key)
	rules.attacker=id
	target.take_hit(minf(100,absf(car.speed)*5))
	rules.attacker=0

@rpc("any_peer","call_remote","reliable")
func game_action(kind: String, data: Dictionary) -> void:
	if multiplayer.is_server() and members.has(multiplayer.get_remote_sender_id()):
		rules.action(multiplayer.get_remote_sender_id(),kind,data)

func relay_chat(id: int, message: String) -> void:
	if not multiplayer.is_server() or not members.has(id):
		return
	var clean_message := message.strip_edges().replace("\n", " ").replace("\r", " ").replace("\t", " ")
	if clean_message.is_empty() or clean_message.length() > CHAT_LIMIT:
		return
	var share_location: bool = clean_message.to_lower() == "/local"
	if share_location:
		var location: Vector3 = rules.position_of(id)
		clean_message = "📍 Localização compartilhada: X %d · Z %d" % [roundi(location.x), roundi(location.z)]
	var now := Time.get_ticks_msec()
	if now - int(chat_last_sent.get(id, -1000)) < CHAT_RATE_MS:
		return
	chat_last_sent[id] = now
	var player_name := Profile.clean_name(str(members[id].get("name", "Jogador")))
	var speaker_at: Vector3 = rules.position_of(id)
	for peer_id in members:
		if not share_location and rules.position_of(int(peer_id)).distance_to(speaker_at) > 70.0:
			continue
		if int(peer_id) == 1:
			broadcast_chat(id,player_name,clean_message)
		else:
			broadcast_chat.rpc_id(int(peer_id),id,player_name,clean_message)

@rpc("any_peer", "call_remote", "reliable")
func submit_chat(message: String) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if id <= 1 or not members.has(id):
		return
	relay_chat(id, message)

@rpc("authority", "call_local", "reliable")
func broadcast_chat(id: int, player_name: String, message: String) -> void:
	var speaker := "Você" if id == multiplayer.get_unique_id() else Profile.clean_name(player_name)
	chat_history.append("%s: %s" % [speaker, message])
	while chat_history.size() > 8:
		chat_history.pop_front()
	chat_log.clear()
	for line in chat_history:
		chat_log.append_text(line + "\n")

@rpc("authority","call_remote","reliable")
func personal(kind: String, data: Dictionary) -> void:
	rules.receive_event(kind,data)

@rpc("authority","call_local","unreliable",3)
func shot_effect(from: Vector3, to: Vector3, weapon: int, shooter: int, direction: Vector3) -> void:
	world.activities.shot_effect(from, to, weapon)
	if shooter == multiplayer.get_unique_id():
		rules.local_body.model.kick_weapon(weapon)
	elif avatars.has(shooter):
		var avatar: Dictionary = avatars[shooter]
		avatar.heading = atan2(-direction.x, -direction.z)
		avatar.node.weapon_pitch = clampf(asin(clampf(direction.y, -1.0, 1.0)), -1.35, 1.35)
		avatar.node.model.kick_weapon(weapon)

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
	if chat_toggle != null:
		chat_toggle.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		chat_toggle.offset_left = -144
		chat_toggle.offset_right = -16
		chat_toggle.offset_top = 176
		chat_toggle.offset_bottom = 220
	if chat_panel != null:
		var width := minf(360.0, bounds.x - 32.0)
		var height := minf(232.0, bounds.y - 32.0)
		var top := minf(228.0, bounds.y - height - 16.0)
		chat_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		chat_panel.offset_left = -width - 16.0
		chat_panel.offset_right = -16.0
		chat_panel.offset_top = top
		chat_panel.offset_bottom = top + height

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
