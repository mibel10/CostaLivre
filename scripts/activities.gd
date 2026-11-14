extends Node

const Officer = preload("res://scripts/officer.gd")
const Bank = preload("res://scripts/bank.gd")
const Catalog = preload("res://scripts/vehicle_catalog.gd")
const CAMPAIGN_LENGTH := 25
const SECRET_DATA_JOB := 29
const DATA_VENT := Vector3(147, 0.8, 49)
const DATA_TERMINAL := Vector3(147, 0, 63)
const DATA_EXTRACTION_SECONDS := 30.0
const FAVELA_CENTER_X := 1218.0

const ACTION_JOBS := {
	7: {"name":"Fuga de teste","kind":"drive","story":"Teste o Aurora X no circuito e devolva-o inteiro a oficina.","reward":3000,"model":3,"spawn":Vector3(-105,0.3,-5),"points":[Vector3(-126,0,-84),Vector3(84,0,-84),Vector3(84,0,84),Vector3(-21,0,63)],"time":120.0,"min_hp":80},
	9: {"name":"Evacuação em cadeia","kind":"clinic_evacuation","story":"Leve a ambulância da Clínica Costa, recolha três pacientes espalhados pela cidade e volte antes que a perseguição alcance o veículo.","reward":5600,"model":8,"spawn":Vector3(63,0.3,38),"points":[Vector3(-126,0,84),Vector3(84,0,-84),Vector3(714,0,126)],"drop":Vector3(63,0,38),"time":210.0,"min_hp":65},
	10: {"name":"Interceptação na praia","kind":"intercept","story":"Pare o carro do mensageiro sem destrui-lo, recolha a maleta a pe e fuja ate o mercado.","reward":3800,"model":1,"spawn":Vector3(-126,0.3,-84),"track":[Vector3(-126,0.3,-84),Vector3(84,0.3,-84),Vector3(84,0.3,84),Vector3(-126,0.3,84)],"drop":Vector3(105,0,-49),"time":220.0},
	11: {"name":"Sinal pirata","kind":"precision","story":"Derrube os tres transmissores nos andares 3, 5 e 7 do estudio. Saia e despiste o alarme.","reward":4200,"points":[Vector3(143,13.4,67),Vector3(151,25.4,64),Vector3(147,37.4,57)],"exit":Vector3(147,0,84),"time":220.0},
	12: {"name":"Cerco no décimo","kind":"escape_file","story":"Pegue o arquivo no decimo andar, sobreviva a invasao e desca para despistar a policia.","reward":4800,"pickup":Vector3(-67,54,67),"exit":Vector3(-63,0,80),"time":240.0},
	13: {"name":"Corrida pela vida","kind":"rescue","story":"Pegue o carro de atendimento da clinica, resgate o morador no morro e volte com o veiculo inteiro.","reward":4000,"model":8,"spawn":Vector3(63,0.3,38),"pickup":Vector3(714,9.9,4.5),"drop":Vector3(63,0,38),"min_hp":80,"time":210.0},
	14: {"name":"Invasão ao estúdio","kind":"assault","story":"Entre no Estúdio Solar a pé, elimine os guardas, recupere os arquivos e saia do prédio.","reward":4000,"point":Vector3(147,0,58),"exit":Vector3(147,0,80),"guards":[Vector3(140,0.2,59),Vector3(154,0.2,59),Vector3(147,0.2,55)],"time":210.0},
	15: {"name":"Último refúgio","kind":"defend","story":"Ative o encontro no oitavo andar, resista por 60 segundos e elimine quatro ondas de invasores.","reward":4800,"point":Vector3(-67,42,67),"guards":[Vector3(-69,42.2,63),Vector3(-57,42.2,63),Vector3(-63,42.2,56)],"duration":60.0,"waves":4,"time":160.0},
	16: {"name":"Retomada do café","kind":"assault","story":"O Café Maré foi tomado por criminosos. Entre a pé, elimine os invasores, recupere o caixa e saia em segurança.","reward":3800,"point":Vector3(-70,0,14),"exit":Vector3(-63,0,37),"guards":[Vector3(-69,0.2,19),Vector3(-57,0.2,17),Vector3(-64,0.2,13)],"time":240.0},
	17: {"name":"Roubo de suprimentos","kind":"cargo","story":"Recolha tres caixas no supermercado, consiga um carro e leve a carga a oficina depois de despistar a policia.","reward":4200,"points":[Vector3(298,0,-88),Vector3(298,0,-99),Vector3(298,0,-110)],"drop":Vector3(-21,0,63),"time":220.0},
	18: {"name":"Carga instável","kind":"drive","story":"Transporte a carga fragil entre os mercados. Colisoes e trancos destroem a mercadoria.","reward":4600,"model":8,"spawn":Vector3(798,0.3,-78.5),"points":[Vector3(882,0,-84),Vector3(882,0,84),Vector3(294,0,-78.5)],"fragile":true,"time":210.0},
	19: {"name":"Comboio sob fogo","kind":"escort","story":"Aproxime-se do comboio e use F para partir. Siga o veiculo e proteja-o dos atiradores ate o destino.","reward":5200,"model":8,"spawn":Vector3(210,0.3,84),"track":[Vector3(210,0.3,84),Vector3(462,0.3,84),Vector3(462,0.3,126),Vector3(630,0.3,126)],"drop":Vector3(630,0,126),"guards":[Vector3(462,0.2,70),Vector3(462,0.2,110),Vector3(588,0.2,116)],"time":190.0},
	20: {"name":"Passagem dos becos","kind":"foot_race","story":"Comece no acostamento. Entre nas vielas, agache sob a cobertura baixa e desça a escadaria até o próximo patamar.","reward":3600,"points":[Vector3(1196,9.9,7.1),Vector3(1202.5,9.9,7.1),Vector3(1202.5,9.9,13.45),Vector3(1210,9.9,14.0),Vector3(1217,9.9,13.45),Vector3(1225,9.9,13.45),Vector3(1231.5,9.9,13.0),Vector3(1241,9.9,13.45),Vector3(1241,9.9,18),Vector3(1241,7.7,24),Vector3(1245,7.7,26.1)],"race_time":45.0,"time":240.0},
	21: {"name":"Carga quente","kind":"drive","story":"Leve a carga entre os mercados sob perseguicao. Passe pelos pontos e despiste antes da entrega final.","reward":5200,"model":8,"spawn":Vector3(294,0.3,-78.5),"points":[Vector3(294,0,126),Vector3(798,0,126),Vector3(798,0,-78.5)],"escape":true,"start_heat":80,"time":240.0},
	22: {"name":"Cofres do leste","kind":"breach","story":"Atire nas fechaduras dos tres cofres, recolha os documentos e entregue-os na APEX depois de despistar.","reward":5400,"points":[Vector3(441,1.1,112),Vector3(483,1.1,112),Vector3(525,1.1,112)],"drop":Vector3(21,0,42),"time":200.0},
	23: {"name":"Última fuga","kind":"getaway","story":"Roube a maleta no escritorio, entre no Aurora X e escolha uma das duas rotas de fuga. Entregue na garagem depois de despistar.","reward":9000,"model":3,"spawn":Vector3(567,0.3,126),"pickup":Vector3(567,0,112),"points":[Vector3(798,0,-126),Vector3(546,0,126),Vector3(-21,0,63)],"alternate_points":[Vector3(798,0,126),Vector3(294,0,126),Vector3(-21,0,63)],"guards":[Vector3(559,0.2,120),Vector3(575,0.2,120),Vector3(567,0.2,123)],"time":300.0},
	29: {"name":"Operação Tubulação","kind":"infiltration","story":"Agache e abra a tubulação do Data Center. Elimine dois policiais sem alertar a equipe, conecte o pendrive, extraia os dados e fuja pelo mesmo caminho.","reward":11000,"time":360.0},
	30: {"name":"Corrida da costa a pé","kind":"foot_race","story":"Encontre o ponto de partida e corra pela avenida passando por todos os pontos antes do tempo acabar.","reward":2400,"points":[Vector3(-126,0,84),Vector3(-84,0,84),Vector3(-42,0,84),Vector3(0,0,84),Vector3(42,0,84)],"race_time":45.0,"time":180.0},
	31: {"name":"Defesa da clínica","kind":"defend","story":"Defenda a Clínica Costa a pé. Enfrente os invasores e mantenha a posição até a área ficar segura.","reward":3600,"point":Vector3(63,0,26),"guards":[Vector3(55,0.2,34),Vector3(71,0.2,34),Vector3(63,0.2,39)],"duration":20.0,"time":160.0},
	32: {"name":"Corrupção policial","kind":"assault","story":"Um policial corrupto vende informações da cidade. Invada a delegacia central, recupere as provas e saia antes que a equipe de cobertura chegue.","reward":6800,"point":Vector3(105,0.3,21),"exit":Vector3(105,0,42),"guards":[Vector3(96,0.2,21),Vector3(114,0.2,21),Vector3(105,0.2,14)],"time":210.0},
	33: {"name":"Corrida cooperativa","kind":"coop_race","story":"Convide um parceiro e atravessem juntos os pontos de controle antes que o cronômetro termine.","reward":5200,"points":[Vector3(-126,0,84),Vector3(-84,0,84),Vector3(-42,0,42),Vector3(0,0,0),Vector3(42,0,-42),Vector3(84,0,-84)],"race_time":90.0,"time":150.0}
}

var JOBS := ["Correio da costa", "Caixa rápido", "Encomenda de luxo", "Volta da ilha", "Acerto de contas", "Golpe no banco", "Procurado", "Oficina em servico", "Resgate na favela", "Plantao na clinica", "Inventario da praia", "Conexao no estudio", "Arquivo do decimo andar", "Emergencia medica", "Inspecao residencial", "Apartamento seguro", "Turno do cafe"]
var REWARDS := [2400, 800, 3200, 2200, 2800, 2000, 1800, 1800, 2200, 2600, 3000, 3400, 3800, 2300, 1700, 2600, 1900]
const HILL_RESIDENT := Vector3(714,9.9,23)
const HILL_MEDICINE := Vector3(63,0,27)
var hill_errand_stage := 0
var hill_errand_owner := 0
const SUPPLY_PICKUP := Vector3(1202.4,9.9,14.2)
const SUPPLY_ALLEY := Vector3(1244.65,7.7,26.1)
var supply_stage := 0
var supply_owner := 0
var supply_scene_until := 0
const HEAVY_SHOP := Vector3(1197.4, 9.9, 14.5)
const CAPACITIES := [0,12,30,8,32,1,5,20]
const DAMAGE := [0,34,24,58,18,220,180,100]
const FIRE_INTERVAL := [0.0,0.32,0.11,0.65,0.075,1.8,1.2,0.5]
const WEAPON_NAMES := ["Punhos","Pistola","Fuzil","Escopeta","SMG","Bazuca","Sniper","Canhão de pulso"]
const GUN_SHOP := Vector3(-21, 0, 34)
const DEALER := Vector3(21, 0, 34)
const CAR_SPAWNERS := [[Vector3(-7,0,19),Vector3(-7,0.3,24),0.0],[Vector3(846,0,-94),Vector3(846,0.3,-99),0.0],[Vector3(294,0,-78.5),Vector3(304,0.3,-78.5),PI/2],[Vector3(798,0,-78.5),Vector3(808,0.3,-78.5),PI/2]]
var purchased_cars: Array = []
const GARAGE := Vector3(-21, 0, 63)
const ROBBERIES := [Vector3(-63, 0, -8), Vector3(63, 0, -50), Vector3(21, 0, -89), Vector3(264.8, 0, -111.0), Vector3(264.8, 0, -105.5), Vector3(264.8, 0, -100.0), Vector3(264.8, 0, -94.5), Vector3(264.8, 0, -89.0), Vector3(768.8, 0, -111.0), Vector3(768.8, 0, -105.5), Vector3(768.8, 0, -100.0), Vector3(768.8, 0, -94.5), Vector3(768.8, 0, -89.0)]
const RACE := [Vector3(-126, 0, 84), Vector3(-126, 0, -84), Vector3(84, 0, -84), Vector3(84, 0, 84), Vector3(0, 0, 84)]
const CAR_PRICES := [2200,4800,8500,9500,12000,15000,1200,1800,3200,30000,75000]
const CAR_COLORS := [Color("30c9bf"),Color("e04959"),Color("b894ed"),Color("e9c24c"),Color("385b9d"),Color("dd6336"),Color("7b9c87"),Color("b4bdc7"),Color("bb3945"),Color("278e80"),Color("7048ab")]
var STORY_BEATS := ["O primeiro serviço vai colocar você no mapa.","O caixa da praia pode resolver uma dívida urgente.","Um carro raro espera na rua. Leve-o até a garagem.","Cruze a cidade antes que o tempo acabe.","Dois veículos rivais estão atrapalhando o plano.","O Banco Costa esconde um cofre atrás da segurança.","A polícia fechou o cerco. Sobreviva e despiste a busca.","Um cliente precisa de uma rota rápida pela costa.","Busque o informante de carro na favela, despiste a policia e leve-o ao esconderijo.","Atravesse a avenida leste no limite.","Uma rota noturna exige precisão.","A carga urgente não pode esperar.","Complete o circuito costeiro para fechar o contrato.","A clínica precisa de ajuda para atender a vizinhança.","Uma reunião importante depende de você.","Proteja um contato no apartamento seguro.","O café precisa de uma última mão antes do amanhecer."]
var world: Node3D
var menu := ""
var officers: Array[CharacterBody3D] = []
var dispatch_time := 0.0
var job := -1
var stage := 0
var completed := 0
var clock := 0.0
var progress := 0.0
const INFORMANT_PICKUP := Vector3(FAVELA_CENTER_X, 9.9, 4.5)
const INFORMANT_SAFEHOUSE := Vector3(189,0,126)
var passenger_car := -1
var shipment_integrity := 100.0
var previous_mission_speed := 0.0
var coop_race_participants: Array[int] = []
var target_car: CharacterBody3D
var targets: Array[CharacterBody3D] = []
var robbery_cooldowns := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var robbery_index := -1
var robbery_progress := 0.0
var weapon := 1
var rifle_owned := false
var shotgun_owned := false
var smg_owned := false
var heavy_owned := [false,false,false]
var clips := [0, 12, 30, 8, 32, 0, 0, 0]
var reserves := [0, 36, 0, 24, 96, 0, 0, 0]
var fire_cooldown := 0.0
const RELOAD_DURATIONS := [0.0, 1.2, 1.8, 2.0, 2.0, 2.0, 2.0, 2.0]
var reload_time := 0.0
var reload_weapon := 0
var hit_flash := 0.0
var shot_audio: AudioStreamPlayer
var bank: Node3D
var job_page := 0
var car_page := 0
var pedestrian_target: CharacterBody3D
var pedestrian_robbery_progress := 0.0
var game_mode := "sandbox"
var campaign_index := 0
var campaign_path := "user://campaign.cfg"
var campaign_save_path := "user://campaign_save.cfg"
var hack_pointer := false
var prop_state := Vector4i(-2, -1, -1, -1)
var phone_contract_clock := 45.0

func _ready() -> void:
	if JOBS.size()==17:
		JOBS.append_array(["Estoque da costa", "Entrega ao mercado", "Serviço na avenida", "Inspeção do bairro", "Abastecimento urgente", "Documentos do leste", "Última entrega"])
		REWARDS.append_array([2400, 2600, 2800, 3000, 3200, 3400, 4000])
		STORY_BEATS.append_array(["Organize o estoque do supermercado.", "Faça a entrega no supermercado do leste.", "Ajude nos serviços da avenida.", "Inspecione os prédios do bairro novo.", "Prepare o abastecimento do mercado.", "Reúna os documentos nos escritórios.", "Conclua a última entrega na cidade nova."])
		JOBS.append_array(["Invasao ao Data Center [COOP]","Protocolo Fantasma [COOP]","Arquivo Zero [COOP]"])
		JOBS.append_array(["Sincronização do estoque [COOP]", "Bloqueio do mercado [COOP]"])
		REWARDS.append_array([6200,7400,8600,9000,10000])
		STORY_BEATS.append_array(["Desligue as cameras, invada o servidor, baixe os arquivos e escape da policia.","Cruze os andares sem ser visto, hackeie o controle central e saia com a chave-mestra.","Apague os rastros no mainframe e fuja do predio antes da equipe tatica.","Dois parceiros devem ativar os dois controles ao mesmo tempo.","Dois parceiros devem operar os terminais simultaneamente."])
	if JOBS.size() == 29:
		JOBS.append("Operação Tubulação")
		REWARDS.append(11000)
		STORY_BEATS.append(ACTION_JOBS[SECRET_DATA_JOB].story)
	if JOBS.size() == 30:
		for id in [30, 31]:
			JOBS.append(ACTION_JOBS[id].name)
			REWARDS.append(ACTION_JOBS[id].reward)
			STORY_BEATS.append(ACTION_JOBS[id].story)
	if JOBS.size() == 32:
		for id in [32, 33]:
			JOBS.append(ACTION_JOBS[id].name)
			REWARDS.append(ACTION_JOBS[id].reward)
			STORY_BEATS.append(ACTION_JOBS[id].story)
	bank = Bank.new()
	bank.world = world
	world.add_child(bank)
	for i in 3:
		world.spawn_car(Vector3(24 + i * 35, 0.2, -126), CAR_COLORS[i], false, i + 1)
	for index in ACTION_JOBS:
		JOBS[index] = ACTION_JOBS[index].name
		STORY_BEATS[index] = ACTION_JOBS[index].story
		REWARDS[index] = int(ACTION_JOBS[index].reward)
	setup_shot_audio()
	world.toast = "M: missões  •  TAB: mapa e lojas  •  ESC: controles"
	world.toast_time = 5

func job_count() -> int:
	return JOBS.size() if world.network!=null and world.network.active() else CAMPAIGN_LENGTH + 2

func job_id_at(slot: int) -> int:
	return slot if world.network != null and world.network.active() else (campaign_job_id(slot) if slot < CAMPAIGN_LENGTH else 30 + slot - CAMPAIGN_LENGTH)

func set_menu(value: String) -> void:
	menu = value
	if menu in ["cars", "garage_cars", "owned_cars"]:
		car_page = clampi(car_page, 0, menu_page_count() - 1)
	if world.network!=null and world.network.rules.context_peer>1:
		world.network.personal.rpc_id(world.network.rules.context_peer,"menu",{"value":value})
		menu=value
		return
	world.get_tree().paused = value != "" and not (world.network!=null and world.network.active())
	world.engine_audio.stream_paused = value != ""
	world.restore_pointer()
	world.hud.queue_redraw()
	if world.pause_menu != null:
		world.pause_menu.open_for(value)

func menu_page_count() -> int:
	if menu == "jobs":
		return maxi(1, ceili(job_count() / 7.0))
	var count := purchased_cars.size() if menu == "owned_cars" else CAR_PRICES.size()
	return maxi(1, ceili(count / 3.0))

func turn_menu_page(step: int) -> void:
	if menu == "jobs":
		job_page = posmod(job_page + step, menu_page_count())
	else:
		car_page = posmod(car_page + step, menu_page_count())
	world.hud.queue_redraw()

func pointer_select(point: Vector2) -> bool:
	var hud: Control = world.hud
	var at := point / hud.get_viewport_rect().size * Vector2(1280, 720)
	var online: bool = world.network != null and world.network.active()
	var mission_hack: bool = online and world.network.rules.local_mission_hacking()
	if mission_hack or (bank.local_hacking() and OS.has_feature("android")):
		if hud.HACK_CLOSE.has_point(at):
			if online:
				world.network.rules.send_action("mission_cancel" if mission_hack else "cancel_hack")
			else:
				bank.hacking = false
		else:
			for index in 4:
				if hud.hack_key_rect(index).has_point(at):
					if online:
						world.network.rules.send_action("mission_digit" if mission_hack else "digit", {"digit": index + 1})
					else:
						bank.enter_digit(index + 1)
					break
		return true
	if menu not in hud.CHOICE_MENUS:
		return false
	if hud.MENU_CLOSE.has_point(at):
		set_menu("")
	elif menu in hud.PAGE_MENUS and hud.MENU_PREVIOUS.has_point(at):
		turn_menu_page(-1)
	elif menu in hud.PAGE_MENUS and hud.MENU_NEXT.has_point(at):
		turn_menu_page(1)
	elif menu != "credits":
		var count := 7 if menu == "jobs" else (5 if menu in ["guns", "garage"] else (4 if menu == "heavy_guns" else 3))
		for choice in count:
			if not hud.choice_rect(choice).has_point(at):
				continue
			if menu == "jobs":
				var index := choice + job_page * 7
				if index < job_count():
					set_menu("")
					start_job(job_id_at(index))
			elif menu == "owned_cars" and choice + car_page * 3 >= purchased_cars.size():
				break
			else:
				buy(choice)
			break
	return true

func handle_input(event: InputEvent) -> bool:
	if menu == "network" and event.is_action_pressed("pause"):
		world.network.close_menu()
		return true
	if event is InputEventMouseButton and event.device == InputEvent.DEVICE_ID_EMULATION:
		var touch_ui: bool = menu in world.hud.CHOICE_MENUS or bank.local_hacking()
		if world.network != null and world.network.active():
			touch_ui = touch_ui or world.network.rules.local_mission_hacking()
		if touch_ui:
			return true
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and pointer_select(event.position):
		return true
	if world.network!=null and world.network.active() and world.network.rules.local_mission_hacking():
		if event.is_action_pressed("pause"):
			world.network.rules.send_action("mission_cancel",{})
		elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode>=KEY_1 and event.physical_keycode<=KEY_4:
			world.network.rules.send_action("mission_digit",{"digit":event.physical_keycode-KEY_1+1})
		return true
	if bank.local_hacking() and not world.finished:
		if world.network!=null and world.network.active():
			if event.is_action_pressed("pause"):
				world.network.rules.send_action("cancel_hack",{})
			elif event is InputEventKey and event.pressed and event.physical_keycode>=KEY_1 and event.physical_keycode<=KEY_4:
				world.network.rules.send_action("digit",{"digit":event.physical_keycode-KEY_1+1})
			return true
		return bank.handle_input(event)
	if menu in ["pause", "map"] and world.pause_menu != null:
		return world.pause_menu.handle_input(event)
	if menu in ["mode", "campaign_complete", "cutscene"]:
		return true
	if event.is_action_pressed("credits"):
		set_menu("" if menu == "credits" else "credits")
		return true
	if menu != "":
		if menu in world.hud.PAGE_MENUS and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_RIGHT, KEY_LEFT]:
			turn_menu_page(1 if event.physical_keycode == KEY_RIGHT else -1)
			return true
		if event.is_action_pressed("pause") or event.is_action_pressed("jobs") or event.is_action_pressed("map"):
			set_menu("")
		return true
	if world.get_tree().paused or world.finished:
		return false
	if world.prison_stage_for() >= 0:
		if event.is_action_pressed("activity"):
			if world.network != null and world.network.active():
				world.network.rules.send_action("prison_step", {})
			else:
				world.prison_interact(1, world.player.position)
			return true
		if event.is_action_pressed("jobs"):
			return true
	if event.is_action_pressed("jobs"):
		if game_mode == "campaign":
			world.notify("Complete o capítulo atual para liberar a próxima missão.")
		else:
			set_menu("jobs")
		return true
	if event.is_action_pressed("map"):
		set_menu("map")
		return true
	if event.is_action_pressed("activity"):
		if world.network != null and world.network.rules.golden_arrow_prompt() != "":
			if world.network.active():
				world.network.rules.send_action("pickup_arrow")
			else:
				world.network.rules.collect_golden_arrow(world.network.rules.local_id())
			return true
		if world.active_car != null and world.active_car.tier == Catalog.SUPERCAR and nearby_place() != "garage":
			if world.network != null and world.network.active():
				world.network.rules.send_action("hover_mode")
			else:
				world.active_car.set_hover_mode(not world.active_car.hovering)
			return true
		if world.network!=null and world.network.active():
			if world.life.interact_building():
				return true
			var place := nearby_place()
			if place in ["guns","heavy_guns","cars","garage","owned_cars"]:
				set_menu(place)
			elif world.life.prompt().to_lower().contains("elevador"):
				world.life.interact()
			else:
				world.network.rules.send_action("interact",{})
			return true
		if interact_campaign() or interact_hill_errand() or interact_supply():
			return true
		if world.life != null and (world.life.interact_building() or world.life.interact()):
			return true
		if bank.interact():
			return true
		var nearby := nearby_place()
		if nearby in ["guns", "heavy_guns", "cars", "owned_cars"]:
			set_menu(nearby)
		elif nearby == "garage":
			set_menu("garage")
		return true
	if event.is_action_pressed("reload"):
		if world.network!=null and world.network.active():
			world.network.rules.send_action("reload",{})
		else:
			reload()
		return true
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5]:
			var selected: int = [1, 2, 0, 3, 4][event.physical_keycode - KEY_1]
			if owns_weapon(selected):
				weapon = selected
				reload_time = 0
			return true
	return false

func spend(amount: int) -> bool:
	if world.cash < amount:
		world.notify("Dinheiro insuficiente. Faça missões ou assaltos.")
		return false
	world.cash -= amount
	return true

func buy(choice: int) -> void:
	if world.network!=null and world.network.is_client():
		world.network.rules.send_action("buy",{"menu":menu,"choice":choice,"page":car_page})
		return
	if choice < 0 or choice > (4 if menu in ["guns","garage"] else (3 if menu == "heavy_guns" else 2)):
		return
	if menu == "owned_cars":
		recall_car(choice+car_page*3)
		return
	if menu == "garage":
		if choice == 4:
			set_menu("garage_cars")
			return
		if world.active_car == null:
			world.notify("Entre em um carro para usar este servico.")
			return
		if choice != 0 and world.active_car.hp <= 0:
			world.notify("Repare o veículo antes de personalizar.")
			return
		var price: int = [250,300,500,800][choice]
		if choice == 3 and world.active_car.suspension_height >= 0.6:
			world.notify("Suspensao ja esta na altura maxima.")
			return
		if choice == 2 and world.active_car.engine_upgrade >= 10:
			world.notify("Motor já está no nível máximo.")
			return
		if not spend(price):
			return
		if choice == 0:
			world.active_car.repair()
			world.health = 100
		elif choice == 1:
			var colors := [Color("e04959"),Color("30c9bf"),Color("b894ed"),Color("e4b84c"),Color("ececec"),Color("343b49"),Color("111925"),Color("c45c31"),Color("4a8759"),Color("e6e1c8")]
			var current: int = colors.find(world.active_car.paint)
			world.active_car.repaint(colors[(current+1)%colors.size()])
		elif choice == 3:
			world.active_car.set_suspension(world.active_car.suspension_height+0.15)
		else:
			world.active_car.engine_upgrade = minf(10.0,world.active_car.engine_upgrade+2.5)
		remember_car(world.active_car)
		world.notify("Serviço da oficina concluído.")
	elif menu == "heavy_guns":
		if world.active_car != null:
			world.notify("Saia do carro para comprar armas.")
			return
		if not spend([6500,5000,25000,1200][choice]):
			return
		if choice < 3:
			heavy_owned[choice] = true
			weapon = choice + 5
			clips[weapon] = CAPACITIES[weapon]
			reserves[weapon] += [4,15,60][choice]
		else:
			for i in 3:
				if heavy_owned[i]:
					reserves[i+5] += [4,15,60][i]
		world.notify("Compra concluída na favela.")
		if game_mode == "campaign":
			save_campaign()
	elif menu == "guns":
		var prices := [400, 1800, 2400, 2100, 150]
		if not spend(prices[choice]):
			return
		if choice == 0:
			weapon = 1
			clips[1] = 12
			reserves[1] += 48
		elif choice == 1:
			rifle_owned = true
			weapon = 2
			clips[2] = 30
			reserves[2] += 90
		elif choice == 2:
			shotgun_owned = true
			weapon = 3
			clips[3] = 8
			reserves[3] += 32
		elif choice == 3:
			smg_owned = true
			weapon = 4
			clips[4] = 32
			reserves[4] += 96
		else:
			reserves[1] += 48
			if rifle_owned:
				reserves[2] += 90
			if shotgun_owned:
				reserves[3] += 24
			if smg_owned:
				reserves[4] += 96
		world.notify("Compra concluída.")
	elif menu in ["cars","garage_cars"]:
		choice += car_page*3
		if choice >= CAR_PRICES.size():
			return
		var at := Vector3(-21,0.3,78.5) if menu == "garage_cars" else Vector3(18, 0.3, 44)
		for car in world.cars:
			if car.position.distance_to(at) < 5:
				world.notify("Libere a saída da concessionária antes de comprar.")
				return
		if not spend(CAR_PRICES[choice]):
			return
		var car: CharacterBody3D = world.spawn_car(at, CAR_COLORS[choice], false, choice + 1)
		car.owned = true
		purchased_cars.append({"tier":car.tier,"paint":car.paint,"engine":car.engine_upgrade,"suspension":car.suspension_height,"net_id":car.net_id})
		if game_mode == "campaign": save_campaign()
		world.notify("%s comprado! Seu carro está na saída da APEX." % car.model_name)
	else:
		return
	set_menu("")

func nearby_place() -> String:
	var pos: Vector3 = world.subject_position()
	if car_spawner_at(pos) >= 0: return "owned_cars"
	if pos.distance_to(HEAVY_SHOP) < 3:
		return "heavy_guns"
	if pos.distance_to(GUN_SHOP) < 5:
		return "guns"
	if pos.distance_to(DEALER) < 5:
		return "cars"
	if pos.distance_to(GARAGE) < 5:
		return "garage"
	for i in ROBBERIES.size():
		if i == 2: # The bank uses its own vault flow.
			continue
		if pos.distance_to(ROBBERIES[i]) < (5 if i < 3 else 2.3):
			return "robbery"
	return ""

func prompt() -> String:
	if world.prison_stage_for() >= 0:
		return world.prison_prompt()
	if world.network != null:
		var arrow_prompt: String = world.network.rules.golden_arrow_prompt()
		if arrow_prompt != "":
			return arrow_prompt
	if world.active_car != null and not world.bus_passenger and world.near_fuel_station(world.active_car.position):
		if world.active_car.refuel_time > 0.0:
			return "Abastecendo…"
		if world.active_car.hp > 0 and world.active_car.fuel < 1.0:
			return ("USAR" if OS.has_feature("android") else "F") + " · Abastecer grátis"
	var contract := action_prompt()
	if contract != "": return contract
	if job == 8 and stage == 0 and world.subject_position().distance_to(INFORMANT_PICKUP) < 5:
		return "F / Embarcar informante" if world.active_car != null else "Traga um carro para resgatar o informante"
	var errand := hill_errand_prompt()
	if errand != "": return errand
	var supply := supply_prompt()
	if supply != "": return supply
	if world.life != null:
		var indoor: String = world.life.prompt()
		if indoor != "":
			return indoor
	var civilian := nearest_robbery_target()
	if civilian != null:
		return "Segure F  ·  Roubar dinheiro do pedestre"
	if job in [7,9,10,11,12,13,14,15,16] and world.life != null and world.active_car == null and world.player.position.distance_to(world.life.mission_position()) < 2.5:
		return "F · Interagir com o objetivo"
	var bank_prompt: String = bank.prompt()
	if bank_prompt != "":
		return bank_prompt
	match nearby_place():
		"owned_cars": return "F / Retirar veiculo comprado"
		"heavy_guns": return "F · Arsenal da favela"
		"guns": return "F  ·  Loja de armas"
		"cars": return "F  ·  Concessionária APEX"
		"garage": return "F  ·  Oficina: reparo e personalização"
		"robbery": return "Segure F a pé com uma arma  ·  Assaltar"
	if world.active_car == null and world.nearest_car() != null:
		return "E  ·  Entrar no carro"
	return ""

func start_job(index: int, coop_accepted := false, actor := 0) -> void:
	if world.network!=null and world.network.is_client():
		world.network.rules.send_action("job",{"index":index})
		return
	if index >= 24 and index < 29 or index == 33:
		if world.network == null or not world.network.active():
			world.notify("Esta operação é exclusiva do multiplayer.")
			return
		if not coop_accepted:
			world.network.rules.propose_mission(multiplayer.get_unique_id(), index)
			return
	if index < 0 or index >= JOBS.size():
		return
	if index == 33:
		coop_race_participants.clear()
	# Replacing a contract cannot leave unbounded parked mission vehicles behind.
	for guard in officers.duplicate():
		if guard.has_meta("mission_contract"):
			officers.erase(guard)
			guard.queue_free()
	for loan in world.cars.duplicate():
		if loan != world.active_car and bool(loan.get_meta("mission_loan",false)): remove_car(loan)
	if is_instance_valid(target_car) and target_car != world.active_car:
		remove_car(target_car)
	for car in targets:
		if is_instance_valid(car) and car != world.active_car:
			remove_car(car)
	target_car = null
	targets.clear()
	job = index
	passenger_car = -1
	stage = 0
	clock = (360.0 if job >= 24 else ((180.0 if job == 8 else 100.0) if job >= 7 else (95.0 if job == 3 else 0.0)))
	progress = 0
	if ACTION_JOBS.has(job) and not setup_action_job(actor): return
	if job == 2:
		target_car = world.spawn_car(Vector3(-84, 0.2, 42), CAR_COLORS[1], false, 2)
	elif job == 4:
		for z in [-42, 0]:
			var car: CharacterBody3D = world.spawn_car(Vector3(88, 0.2, z + 12), Color("8c526b"), false, 1)
			car.hp = 60
			targets.append(car)
	elif job == 6:
		world.raise_heat(80, actor)
	elif job in range(24,29):
		world.raise_heat(42, actor)
	world.notify("Contrato: %s. Recompensa $%d." % [JOBS[job], REWARDS[job]])
	if world.cutscene != null:
		var chapter := CAMPAIGN_LENGTH if index == SECRET_DATA_JOB else (campaign_index + 1 if game_mode == "campaign" and campaign_job_id(campaign_index) == index else index + 1)
		world.play_cutscene("CAPÍTULO %02d  ·  %s" % [chapter, JOBS[index].to_upper()], ("Entre no predio e realize os tres servicos marcados. Nos andares altos, use F no elevador." if index in [7,9,10,11,12,13,14,15,16] and not ACTION_JOBS.has(index) else STORY_BEATS[index]))

func campaign_job_id(index: int) -> int:
	return SECRET_DATA_JOB if index == CAMPAIGN_LENGTH - 1 else index

func begin_campaign() -> void:
	load_campaign()
	if world.prison_stage >= 0:
		job = -1
		world.marker.hide()
		world.player.position = world.PRISON_SPAWN
		world.notify("Você está preso. " + world.PRISON_TEXT[world.prison_stage])
		return
	if campaign_index >= CAMPAIGN_LENGTH:
		world.pause_menu.show_campaign_complete()
		return
	save_campaign()
	start_job(campaign_job_id(campaign_index))

func save_campaign() -> bool:
	var save := ConfigFile.new()
	save.set_value("story", "next_mission", campaign_index)
	save.set_value("story", "prison_stage", world.prison_stage)
	save.set_value("story", "cash", world.cash)
	save.set_value("story", "home_floor", world.life.owned_home)
	save.set_value("story", "homes", world.life.owned_homes)
	save.set_value("story", "health", world.health)
	save.set_value("story", "completed", completed)
	save.set_value("story", "weapon", weapon)
	save.set_value("story", "clips", clips)
	save.set_value("story", "reserves", reserves)
	save.set_value("story", "rifle_owned", rifle_owned)
	save.set_value("story", "shotgun_owned", shotgun_owned)
	save.set_value("story", "smg_owned", smg_owned)
	save.set_value("story", "heavy_owned", heavy_owned)
	save.set_value("story", "supply_stage", supply_stage)
	save.set_value("story", "hill_errand_stage", hill_errand_stage)
	save.set_value("story", "purchased_cars", purchased_cars)
	var error := save.save(campaign_save_path)
	if error != OK:
		world.notify("Falha ao salvar a campanha (%s)." % error_string(error))
		return false
	var progress_save := ConfigFile.new()
	progress_save.set_value("story", "next_mission", campaign_index)
	progress_save.save(campaign_path)
	return true

func load_campaign() -> void:
	world.life.owned_home = -1
	world.life.owned_homes.clear()
	var save := ConfigFile.new()
	if save.load(campaign_save_path) != OK:
		var legacy := ConfigFile.new()
		campaign_index = clampi(legacy.get_value("story", "next_mission", 0) if legacy.load(campaign_path) == OK else 0, 0, CAMPAIGN_LENGTH)
		return
	campaign_index = clampi(save.get_value("story", "next_mission", 0), 0, CAMPAIGN_LENGTH)
	world.prison_stage = clampi(int(save.get_value("story", "prison_stage", -1)), -1, world.PRISON_POINTS.size() - 1)
	world.cash = int(save.get_value("story", "cash", world.cash))
	world.life.owned_home = clampi(int(save.get_value("story", "home_floor", -1)), -1, 11)
	world.life.owned_homes.clear()
	if world.life.owned_home >= 0: world.life.owned_homes.append(world.life.owned_home)
	world.health = float(save.get_value("story", "health", world.health))
	completed = int(save.get_value("story", "completed", campaign_index))
	weapon = clampi(save.get_value("story", "weapon", 1), 0, 7)
	clips = save.get_value("story", "clips", clips).duplicate()
	reserves = save.get_value("story", "reserves", reserves).duplicate()
	rifle_owned = save.get_value("story", "rifle_owned", false)
	shotgun_owned = save.get_value("story", "shotgun_owned", false)
	smg_owned = save.get_value("story", "smg_owned", false)
	purchased_cars = save.get_value("story", "purchased_cars", []).duplicate(true)
	for car in purchased_cars: car["net_id"] = -1
	hill_errand_stage = int(save.get_value("story", "hill_errand_stage", 0))
	hill_errand_owner = 0
	supply_stage = int(save.get_value("story", "supply_stage", 0))
	if supply_stage in [2,3]: supply_stage = 1
	heavy_owned = save.get_value("story", "heavy_owned", [false,false,false]).duplicate()
	clips.resize(8)
	reserves.resize(8)
	for i in 8:
		if clips[i] == null: clips[i] = 0
		if reserves[i] == null: reserves[i] = 0

func save_campaign_now() -> void:
	if game_mode != "campaign":
		world.notify("Salvar manualmente só está disponível na campanha.")
		return
	if save_campaign():
		world.notify("Campanha salva neste dispositivo.")

func has_campaign_save() -> bool:
	return FileAccess.file_exists(campaign_save_path)

func new_campaign() -> void:
	world.prison_stage = -1
	world.prison_progress = 0.0
	world.life.owned_home = -1
	world.life.owned_homes.clear()
	campaign_index = 0
	supply_stage = 0
	hill_errand_stage = 0
	hill_errand_owner = 0
	purchased_cars.clear()
	completed = 0
	world.cash = 900
	world.health = 100
	weapon = 1
	clips = [0, 12, 30, 8, 32, 0, 0, 0]
	reserves = [0, 36, 0, 0, 0, 0, 0, 0]
	rifle_owned = false
	shotgun_owned = false
	smg_owned = false
	heavy_owned = [false,false,false]
	start_job(0)
	save_campaign()

func advance_campaign() -> void:
	if campaign_index >= CAMPAIGN_LENGTH:
		world.play_cutscene("COSTA LIVRE", "Você concluiu os 25 capítulos e mudou o destino da cidade.", func(): world.pause_menu.show_campaign_complete())
	else:
		start_job(campaign_job_id(campaign_index))

func fail_job(message: String) -> void:
	var failed_index := job
	job = -1
	progress = 0
	world.notify(message)
	if game_mode == "campaign":
		world.play_cutscene("MISSÃO FALHOU", "%s  ·  Vamos tentar de novo." % JOBS[failed_index], func(): start_job(campaign_job_id(campaign_index)))

func remove_car(car: CharacterBody3D) -> void:
	if not is_instance_valid(car): return
	world.cars.erase(car)
	car.queue_free()

func destination() -> Vector3:
	if ACTION_JOBS.has(job): return action_destination()
	if job in [27,28]: return Vector3(294 if job == 27 else 798,0,-99)
	if job>=24:
		return world.life.mission_position()
	if job in [7,9,10,11,12,13,14,15,16] or world.life.NEW_TASKS.has(job):
		return world.life.mission_position()
	if bank.inside() and bank.phase < 5:
		return bank.next_position()
	match job:
		8: return INFORMANT_PICKUP if stage == 0 else INFORMANT_SAFEHOUSE
		0: return world.STOPS[mini(stage, 2)]
		1: return ROBBERIES[0]
		2:
			if world.active_car == target_car:
				return GARAGE
			return target_car.position if is_instance_valid(target_car) else Vector3(-84, 0, 42)
		3: return RACE[mini(stage, RACE.size() - 1)]
		4:
			for car in targets:
				if car.hp > 0:
					return car.position
		5: return bank.next_position()
	return world.subject_position()

func objective() -> String:
	if ACTION_JOBS.has(job): return action_objective()
	if job in [27,28]: return "Dois jogadores: segurem F a 4m nos lados leste e oeste / %d%%" % roundi(progress / 8.0 * 100)
	if job>=24:
		return "%s  /  %d:%02d" % [world.life.task_label(),int(clock)/60,int(clock)%60]
	if job in [7,9,10,11,12,13,14,15,16] or world.life.NEW_TASKS.has(job):
		return world.life.task_label()
	if bank.inside() or (bank.phase == 4):
		return bank.objective()
	match job:
		8:
			if stage == 0: return "Resgate: chegue de carro ao informante e aperte F / %ds" % ceili(clock)
			return ("Despiste a policia com o informante a bordo" if world.heat > 0 else "Leve o informante ao esconderijo marcado") + " / %ds" % ceili(clock)
		0: return "Entrega %d/3 · pare no marcador" % (stage + 1)
		1: return "Despiste a polícia" if stage > 0 else "Assalte o mercado marcado e fuja"
		2: return "Entregue o Tempestade na garagem" if world.active_car == target_car else "Roube o Tempestade marcado"
		3: return "Corrida %d/5 · %ds" % [stage + 1, ceili(clock)]
		4: return "Destrua os dois carros marcados" if stage == 0 else "Despiste a polícia"
		5: return bank.objective() if stage == 0 else "Despiste a polícia"
		6: return "Sobreviva e zere o nível de busca"
	return "M · escolher missão   /   TAB · mapa"

func complete_job() -> void:
	if job < 0:
		return
	var finished_index := job
	if world.network!=null and world.network.active():
		world.network.rules.award_all(REWARDS[job])
	else:
		world.cash += REWARDS[job]
	world.health = minf(100, world.health + 20)
	world.extra.play("cash")
	world.notify("%s concluído! +$%d. M para outro contrato." % [JOBS[job], REWARDS[job]])
	completed += 1
	if world.network!=null and world.network.active():
		world.network.rules.notice_all("Contrato cooperativo concluido / +$%d para cada jogador" % REWARDS[finished_index])
	job = -1
	progress = 0
	world.marker.visible = false
	if game_mode == "campaign":
		if finished_index == campaign_job_id(campaign_index): campaign_index += 1
		save_campaign()
		world.play_cutscene("CAPÍTULO CONCLUÍDO", "%s  ·  +$%d" % [JOBS[finished_index], REWARDS[finished_index]], advance_campaign)
	else:
		world.play_cutscene("CONTRATO CONCLUÍDO", "%s  ·  +$%d" % [JOBS[finished_index], REWARDS[finished_index]])

func tick(delta: float) -> void:
	fire_cooldown = maxf(0, fire_cooldown - delta)
	hit_flash = maxf(0, hit_flash - delta)
	if reload_time > 0:
		reload_time -= delta
		if reload_time <= 0:
			var capacity: int = CAPACITIES[reload_weapon]
			var count := mini(capacity - clips[reload_weapon], reserves[reload_weapon])
			clips[reload_weapon] += count
			reserves[reload_weapon] -= count
	if Input.is_action_pressed("shoot") and not world.hud.phone_panel.visible:
		shoot()
	for i in robbery_cooldowns.size():
		robbery_cooldowns[i] = maxf(0, robbery_cooldowns[i] - delta)
	tick_robbery(delta)
	tick_pedestrian_robbery(delta)
	bank.tick(delta)
	tick_supply()
	if world.life != null:
		if world.life.tick_building_job(1,delta):
			world.notify("O tempo da entrega acabou.")
		world.life.tick_tasks(delta)
	tick_police(delta)
	world.marker.visible = job >= 0 and not (job in [1, 4, 5] and stage > 0) and job != 6
	if bank.inside() and bank.phase < 5:
		world.marker.visible = true
	if world.marker.visible:
		world.marker.position = destination()
		world.marker.rotation.y += delta * 0.5
	tick_mission(delta)

func tick_mission(delta: float) -> void:
	var rescue_point := Vector3.INF
	if job == 8 and stage == 0:
		rescue_point = INFORMANT_PICKUP + Vector3(0, 0, 2)
	elif ACTION_JOBS.has(job):
		var spec: Dictionary = ACTION_JOBS[job]
		if spec.kind == "clinic_evacuation" and stage < spec.points.size():
			rescue_point = spec.points[stage] + Vector3(0, 0, 2)
		elif spec.kind == "rescue" and stage == 0:
			rescue_point = spec.pickup + Vector3(0, 0, 2)
	if rescue_point != Vector3.INF:
		for car in world.cars:
			if not is_instance_valid(car):
				continue
			var player_driving: bool = int(world.network.owners.get(car.net_id, 0)) > 0 if world.network != null and world.network.active() else car.driving
			if not player_driving or car.hp <= 0 or absf(car.speed) <= 3.0:
				continue
			var offset: Vector3 = car.to_local(rescue_point)
			var size: Vector3 = preload("res://scripts/vehicle_catalog.gd").SIZES[car.tier]
			if absf(offset.x) < size.x * 0.5 + 0.4 and absf(offset.z) < size.z * 0.5 + 0.4 and absf(offset.y) < 1.8:
				fail_job("A pessoa que você precisava resgatar foi atropelada.")
				return
	if ACTION_JOBS.has(job):
		tick_action_job(delta)
		return
	if job < 0:
		return
	var distance: float = world.subject_position().distance_to(destination())
	var stopped: bool = world.active_car != null and absf(world.active_car.speed) < 3
	match job:
		8:
			clock -= delta
			var rescue_car: Node = world.car_by_id(passenger_car)
			if clock <= 0:
				fail_job("O tempo do resgate acabou.")
			elif stage > 0 and (rescue_car == null or rescue_car.hp <= 0):
				fail_job("O carro com o informante foi destruido.")
			elif stage > 0 and world.active_car == rescue_car and world.heat <= 0 and distance < 7 and stopped:
				complete_job()
		0:
			progress = progress + delta if distance < 7 and stopped else 0.0
			if progress > 1.5:
				stage += 1
				progress = 0
				world.notify("Entrega feita. Próximo destino marcado.")
				if stage >= 3:
					complete_job()
		1, 5:
			if stage > 0 and world.heat <= 0:
				complete_job()
		2:
			if is_instance_valid(target_car) and target_car.hp <= 0:
				fail_job("O carro do contrato foi destruído.")
			elif world.active_car == target_car and distance < 7 and stopped:
				complete_job()
		3:
			clock -= delta
			if clock <= 0:
				fail_job("Tempo esgotado na corrida.")
			elif world.active_car != null and distance < 10:
				stage += 1
				if stage >= RACE.size():
					complete_job()
		4:
			if stage == 0 and targets.all(func(car): return car.hp <= 0):
				stage = 1
				world.raise_heat(60)
			elif stage == 1 and world.heat <= 0:
				complete_job()
		6:
			if world.heat <= 0:
				complete_job()
		27,28:
			clock -= delta
			if clock <= 0:
				fail_job("Tempo esgotado na operação cooperativa.")
				return
			var left := 0
			var right := 0
			var center := destination()
			for id in world.network.rules.participants():
				if not world.network.rules.held(id) or int(world.network.members[id].get("car", -1)) >= 0: continue
				var at: Vector3 = world.network.rules.position_of(id)
				if at.distance_to(center + Vector3(-4,0,0)) < 1.8: left = id
				if at.distance_to(center + Vector3(4,0,0)) < 1.8: right = id
			progress = progress + delta if left > 0 and right > 0 and left != right else 0.0
			if progress >= 8.0:
				world.life.task_progress = 0
				complete_job()
		24,25,26:
			clock-=delta
			if clock<=0:
				fail_job("A janela da operacao fechou. Os dados foram perdidos.")

func tick_robbery(delta: float) -> void:
	if world.active_car != null or weapon == 0 or not world.activity_held():
		robbery_progress = 0
		robbery_index = -1
		return
	var nearby := -1
	var at: Vector3 = world.subject_position()
	for i in ROBBERIES.size():
		if i != 2 and at.distance_to(ROBBERIES[i]) < (5 if i < 3 else 2.3):
			nearby = i
	if nearby < 0:
		robbery_progress = 0
		robbery_index = -1
		return
	if robbery_cooldowns[nearby] > 0:
		world.notify("Caixa vazio. Volte em %ds." % ceili(robbery_cooldowns[nearby]))
		return
	if robbery_index != nearby:
		robbery_progress = 0
		robbery_index = nearby
		world.raise_heat(30)
	robbery_progress += delta
	if robbery_progress >= 5:
		var payout := 1200
		world.cash += payout
		robbery_cooldowns[nearby] = 100
		robbery_progress = 0
		if job == 1 and nearby == 0:
			stage = 1
		world.notify("+$%d do caixa. Fuja da polícia!" % payout)

func nearest_robbery_target() -> CharacterBody3D:
	if world.life == null or world.active_car != null:
		return null
	var closest: CharacterBody3D
	var distance := 2.5 * 2.5
	var at: Vector3 = world.player.position
	for person in world.life.people:
		if person.stationary or person.robbed or person.hp <= 0:
			continue
		var current: float = at.distance_squared_to(person.position)
		if current < distance:
			distance = current
			closest = person
	return closest

func clear_pedestrian_robbery() -> void:
	if is_instance_valid(pedestrian_target):
		pedestrian_target.scared = false
	pedestrian_target = null
	pedestrian_robbery_progress = 0

func tick_pedestrian_robbery(delta: float) -> void:
	var target := nearest_robbery_target() if world.activity_held() else null
	if target == null:
		clear_pedestrian_robbery()
		return
	if target != pedestrian_target:
		clear_pedestrian_robbery()
		pedestrian_target = target
		target.scared = true
		world.raise_heat(8)
		world.notify("Segure F perto do pedestre para pegar o dinheiro.")
	pedestrian_robbery_progress += delta
	if pedestrian_robbery_progress >= 2.0:
		var payout: int = world.rng.randi_range(40, 180)
		world.cash += payout
		pedestrian_target.robbed = true
		clear_pedestrian_robbery()
		world.notify("+$%d. A policia foi alertada!" % payout)

func reload() -> void:
	if weapon <= 0 or reload_time > 0 or reserves[weapon] <= 0:
		return
	var capacity: int = CAPACITIES[weapon]
	if clips[weapon] >= capacity:
		return
	reload_weapon = weapon
	reload_time = RELOAD_DURATIONS[weapon]

func shoot() -> void:
	if world.vehicle_falls.has(world.vehicle_local_id()):
		return
	if world.network!=null and world.network.active():
		world.network.rules.fire_local()
		return
	if world.player.roll_time > 0 or world.car_transition:
		return
	if weapon == 0:
		world.extra.punch()
		return
	if weapon <= 0 or fire_cooldown > 0 or reload_time > 0 or world.bus_passenger or bank.hacking:
		return
	if clips[weapon] <= 0:
		reload()
		return
	clips[weapon] -= 1
	fire_cooldown = FIRE_INTERVAL[weapon]
	mission_noise()
	if not mission_shot_is_quiet(): world.raise_heat(3)
	var camera: Camera3D = world.camera
	var origin := camera.global_position
	var end := origin - camera.global_basis.z * (600 if weapon == 6 else 180)
	var query := PhysicsRayQueryParameters3D.create(origin, end, 7)
	query.exclude = [world.player.get_rid()] + ([world.active_car.get_rid()] if world.active_car != null else [])
	var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		end = hit.position
	var muzzle: Vector3 = world.player.position + Vector3(0, 1.35, 0)
	if world.active_car != null:
		var size: Vector3 = Catalog.SIZES[world.active_car.tier]
		muzzle = world.active_car.to_global(Vector3(-size.x * 0.36, size.y * 0.72, 0))
	var muzzle_query := PhysicsRayQueryParameters3D.create(muzzle, end, 7)
	muzzle_query.exclude = [world.player.get_rid()] + ([world.active_car.get_rid()] if world.active_car != null else [])
	var obstruction := world.get_world_3d().direct_space_state.intersect_ray(muzzle_query)
	if not obstruction.is_empty():
		hit = obstruction
		end = obstruction.position
	weapon_impact(hit, end, weapon)
	world.player.model.kick_weapon(weapon)
	shot_effect(muzzle, end, weapon)

func owns_weapon(index: int) -> bool:
	if index < 0 or index > 7: return false
	if index >= 5: return heavy_owned[index-5]
	return index < 2 or (rifle_owned if index == 2 else (shotgun_owned if index == 3 else smg_owned))

func weapon_impact(hit: Dictionary, at: Vector3, selected: int) -> void:
	if not hit.is_empty() and hit.collider.has_meta("stand_wall"):
		var wall: Node3D = hit.collider.get_meta("stand_wall")
		wall.set_meta("health",float(wall.get_meta("health",world.network.rules.STAND_WALL_HEALTH))-DAMAGE[selected])
		if float(wall.get_meta("health")) <= 0.0:
			world.network.rules.stand_objects.erase(wall)
			wall.queue_free()
		return
	if not hit.is_empty(): campaign_target_hit(hit.collider)
	if selected not in [5,7]:
		if not hit.is_empty() and hit.collider.has_method("take_hit"):
			hit.collider.take_hit(DAMAGE[selected])
			hit_flash = 0.16
		return
	var radius := 6.0 if selected == 5 else 5.5
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	query.shape = sphere
	query.transform.origin = at
	query.collision_mask = 7
	var struck := {}
	for result in world.get_world_3d().direct_space_state.intersect_shape(query,128):
		var victim: Node3D = result.collider
		if struck.has(victim.get_instance_id()) or not victim.has_method("take_hit"): continue
		struck[victim.get_instance_id()] = true
		var ray := PhysicsRayQueryParameters3D.create(at + Vector3.UP*0.12, victim.global_position + Vector3.UP, 1)
		var cover := world.get_world_3d().direct_space_state.intersect_ray(ray)
		if not cover.is_empty() and cover.collider != victim: continue
		victim.take_hit(DAMAGE[selected])

func shot_effect(from: Vector3, to: Vector3, selected: int) -> void:
	world.extra.battle_impact(to,(to-from).normalized())
	for person in world.life.people:
		if person.hp>0 and person.position.distance_to(to)<12:
			person.react_to_threat()
	trace(from, to, Color("65ffff") if selected == 7 else Color("ffe5a0"))
	if selected in [5,7]:
		var blast := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 1.0
		sphere.height = 2.0
		blast.mesh = sphere
		blast.material_override = world.material(Color("65ffff") if selected == 7 else Color("ff9c3b"), true)
		world.add_child(blast)
		blast.global_position = to
		var tween := blast.create_tween()
		tween.tween_property(blast,"scale",Vector3.ONE * (6.0 if selected == 5 else 5.5),0.2)
		tween.tween_property(blast,"scale",Vector3.ZERO,0.15)
		tween.tween_callback(blast.queue_free)
		world.extra.play("explosion", -12)
	shot_audio.pitch_scale = [1.0,0.85,1.2,0.65,1.45,0.5,0.7,1.8][selected]
	shot_audio.play()

func trace(from: Vector3, to: Vector3, color: Color) -> void:
	var distance := from.distance_to(to)
	if distance < 0.1:
		return
	var beam: MeshInstance3D = world.box(world, (from + to) * 0.5, Vector3(0.035, 0.035, distance), color, false, true)
	beam.look_at(to)
	get_tree().create_timer(0.07, false).timeout.connect(beam.queue_free)

func tick_police(delta: float) -> void:
	dispatch_time -= delta
	if job == 12 and stage == 1 and not world.life.stair_chase_started:
		var occupant: int = world.life.apartment_tenth_floor_actor()
		if occupant >= 0:
			world.life.begin_apartment_stair_chase(occupant)
	if world.life.stair_chase_started:
		if job==12 and not world.network.active():
			world.heat=maxf(world.heat,40.0)
		elif job != 12:
			world.life.stair_chase_started=false
	var response_threshold:=12 if world.network!=null and world.network.active() else 20
	if world.heat >= response_threshold and dispatch_time <= 0:
		dispatch_time = 18
		for cop in world.cops:
			var response_target:Vector3=world.police_target(cop) if world.network!=null and world.network.active() else world.subject_position()
			if cop.hp > 0 and cop.position.distance_to(response_target) < 30 and officers.size() < mini(3, ceili(world.heat / 40)):
				for side in [-1,1]:
					var at: Vector3=cop.position+cop.global_basis.x*2.5*side+Vector3(0,0.3,0)
					var query := PhysicsShapeQueryParameters3D.new()
					var capsule := CapsuleShape3D.new()
					capsule.radius=0.35
					capsule.height=1.8
					query.shape=capsule
					query.transform=Transform3D(Basis.IDENTITY,at+Vector3(0,0.9,0))
					query.collision_mask=1
					if not world.get_world_3d().direct_space_state.intersect_shape(query).is_empty():
						continue
					var officer := Officer.new()
					officer.world=world
					world.add_child(officer)
					officer.position=at
					officers.append(officer)
					break
	for i in range(officers.size() - 1, -1, -1):
		var contract: int = int(officers[i].get_meta("mission_contract",-1))
		if contract >= 0:
			if contract != job:
				officers[i].queue_free()
				officers.remove_at(i)
			continue
		var target:Vector3=world.police_target(officers[i]) if world.network!=null and world.network.active() else world.subject_position()
		var mission_stair:bool=bool(officers[i].get_meta("mission_stair",false))
		var prison_guard:bool=bool(officers[i].get_meta("prison_guard",false))
		if (mission_stair and job!=12) or (prison_guard and not world.prisoners_present()) or (not mission_stair and not prison_guard and (world.heat < response_threshold or officers[i].position.distance_to(target) > 70)):
			officers[i].queue_free()
			officers.remove_at(i)

func setup_shot_audio() -> void:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	var data := PackedByteArray()
	data.resize(4400)
	var noise := RandomNumberGenerator.new()
	noise.seed = 16
	for i in 2200:
		var envelope := exp(-float(i) / 300)
		data.encode_s16(i * 2, int((noise.randf_range(-1, 1) * 0.7 + sin(float(i) * 0.06) * 0.3) * envelope * 25000))
	wav.data = data
	shot_audio = AudioStreamPlayer.new()
	shot_audio.stream = wav
	shot_audio.volume_db = -16
	add_child(shot_audio)

func supply_prompt() -> String:
	var pos: Vector3 = world.subject_position()
	if supply_stage == 0 and pos.distance_to(SUPPLY_PICKUP) < 3:
		return "F: aceitar entrega de carga ilegal ao contato no beco da favela (+$4500)"
	if supply_stage in [1,3] and (world.network == null or not world.network.active() or supply_owner == multiplayer.get_unique_id()):
		if supply_stage == 3 and pos.distance_to(SUPPLY_ALLEY) < 3:
			return "F: entregar a carga ao contato"
		if pos.distance_to(HEAVY_SHOP) < 10 or pos.distance_to(SUPPLY_ALLEY) < 12:
			return "Carga ilegal: siga pelo beco que liga as ruas da favela"
	return ""

func interact_supply() -> bool:
	if world.active_car != null: return false
	var actor: int = world.network.rules.context_peer if world.network != null and world.network.active() else 0
	if world.network != null and world.network.active() and actor == 0: actor = multiplayer.get_unique_id()
	var pos: Vector3 = world.network.rules.position_of(actor) if world.network != null and world.network.active() else world.subject_position()
	if supply_stage == 0 and pos.distance_to(SUPPLY_PICKUP) < 3:
		supply_owner = actor
		supply_stage = 1
		world.notify("Carga de drogas recolhida. Leve-a ao contato no beco entre as ruas da favela.")
		if game_mode == "campaign": save_campaign()
		return true
	if supply_stage == 3 and actor == supply_owner and pos.distance_to(SUPPLY_ALLEY) < 3:
		supply_stage = 4
		if world.network != null and world.network.active():
			world.network.rules.award(actor,4500)
		else:
			world.cash += 4500
		world.notify("Entrega concluida. +$4500. Contato: Valeu, a carga esta completa.")
		if game_mode == "campaign": save_campaign()
		return true
	return false

func tick_supply() -> void:
	if hill_errand_stage in [1,2] and world.network != null and world.network.active():
		if not world.network.members.has(hill_errand_owner) or world.network.rules.is_dead(hill_errand_owner):
			hill_errand_stage = 0
			hill_errand_owner = 0
	if supply_stage in [1,2,3] and world.network != null and world.network.active():
		if not world.network.members.has(supply_owner) or world.network.rules.is_dead(supply_owner):
			supply_stage = 0
			supply_owner = 0
			return
	var pos: Vector3 = world.network.rules.position_of(supply_owner) if supply_owner > 0 else world.subject_position()
	if supply_stage == 1 and pos.distance_to(SUPPLY_ALLEY) < 3.5:
		supply_stage = 2
		supply_scene_until = Time.get_ticks_msec() + 30000
		if world.network != null and world.network.active():
			world.network.rules.send_personal(supply_owner, "supply_scene", {})
		else:
			world.play_cutscene("EMBOSCADA NO BECO", "")
	elif supply_stage == 2 and Time.get_ticks_msec() >= supply_scene_until:
		complete_supply_scene()

func complete_supply_scene() -> void:
	if supply_stage != 2:
		return
	supply_stage = 3
	if world.network != null and world.network.active():
		world.network.rules.private_notice(supply_owner, "Contato confirmado. Entregue a carga.")
	else:
		world.notify("Contato confirmado. Entregue a carga.")

func _process(delta: float) -> void:
	if game_mode == "sandbox" and job < 0 and menu == "" and not world.finished and (world.network == null or not world.network.is_client()):
		phone_contract_clock -= delta
		if phone_contract_clock <= 0.0:
			phone_contract_clock = 120.0
			var offer_index := randi_range(0,16)
			if world.network != null and world.network.active():
				world.network.rules.offer_phone_contract(offer_index)
			else:
				world.hud.show_contract_message(offer_index)
	var show_hack_pointer: bool = bank.local_hacking() or (world.network != null and world.network.active() and world.network.rules.local_mission_hacking())
	if hack_pointer != show_hack_pointer:
		hack_pointer = show_hack_pointer
		world.restore_pointer()
	var current_props := Vector4i(job, stage, int(progress >= 1.0), supply_stage)
	if current_props == prop_state:
		return
	prop_state = current_props
	var objects: Node = world.get_node_or_null("ObjetivosCampanha") if world != null else null
	if objects != null:
		for target in objects.get_children():
			var active: bool = job == int(target.get_meta("contract_job",-1)) and stage == int(target.get_meta("contract_stage",-1))
			target.visible = active
			if target.use_collision != active: target.use_collision = active
			var opened: bool = active and progress >= 1 and ACTION_JOBS.has(job) and ACTION_JOBS[job].kind == "breach"
			if not target.has_meta("opened") or bool(target.get_meta("opened")) != opened:
				target.material = world.material(Color("80efac") if opened else Color("ffc45c"),true)
				target.set_meta("opened",opened)
	var usb: Node3D = world.get_node_or_null("Computador29/Pendrive29")
	if usb != null:
		usb.visible = job == SECRET_DATA_JOB and stage == 4
	var informant: Node3D = world.get_node_or_null("InformanteCampanha") if world != null else null
	if informant != null:
		var clinic_patient: bool = ACTION_JOBS.has(job) and ACTION_JOBS[job].kind == "clinic_evacuation" and stage < ACTION_JOBS[job].points.size()
		informant.visible = (stage == 0 and job == 8) or clinic_patient or (stage == 0 and ACTION_JOBS.has(job) and ACTION_JOBS[job].kind == "rescue")
		if informant.visible:
			var patient_at: Vector3 = ACTION_JOBS[job].points[stage] if clinic_patient else (ACTION_JOBS[job].pickup if ACTION_JOBS.has(job) and ACTION_JOBS[job].kind == "rescue" else INFORMANT_PICKUP)
			informant.position = patient_at+Vector3(0,0,2)
	var gun: Node3D = world.get_node_or_null("ContatoBeco/Arma") if world != null else null
	if gun != null:
		gun.rotation.x = PI/2 if supply_stage >= 3 else 0.0

func car_spawner_at(at: Vector3) -> int:
	for i in CAR_SPAWNERS.size():
		if at.distance_to(CAR_SPAWNERS[i][0]) < 3: return i
	return -1

func remember_car(car: Node) -> void:
	for entry in purchased_cars:
		if int(entry.get("net_id",-1)) == car.net_id:
			entry.paint = car.paint
			entry.engine = car.engine_upgrade
			entry.suspension = car.suspension_height
	if game_mode == "campaign": save_campaign()

func recall_car(index: int) -> void:
	var pad := car_spawner_at(world.subject_position())
	if pad < 0 or index < 0 or index >= purchased_cars.size(): return
	if world.active_car != null:
		world.notify("Saia do carro para retirar outro veiculo.")
		return
	var entry: Dictionary = purchased_cars[index]
	var car: Node = world.car_by_id(int(entry.get("net_id",-1)))
	if car != null and world.network != null and world.network.active():
		for member in world.network.members.values():
			if int(member.get("car",-1)) == car.net_id:
				world.notify("Este veiculo esta em uso.")
				return
	var at: Vector3 = CAR_SPAWNERS[pad][1]
	var yaw: float = CAR_SPAWNERS[pad][2]
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := BoxShape3D.new()
	shape.size = Catalog.SIZES[int(entry.tier)] + Vector3(0.4,0.2,0.4)
	query.shape = shape
	query.transform = Transform3D(Basis(Vector3.UP,yaw),at+Vector3.UP*shape.size.y/2)
	query.collision_mask = 7
	if car != null: query.exclude = [car.get_rid()]
	if not world.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():
		world.notify("Libere a vaga de retirada primeiro.")
		return
	if car == null:
		car = world.spawn_car(at,entry.paint,false,int(entry.tier))
		car.engine_upgrade = float(entry.engine)
		car.set_suspension(float(entry.get("suspension",0)))
		entry.net_id = car.net_id
	else:
		remember_car(car)
		if car.hp <= 0: car.repair()
	car.position = at
	car.heading = yaw
	car.rotation.y = yaw
	car.speed = 0
	car.velocity = Vector3.ZERO
	car.traffic = false
	car.owned = true
	if game_mode == "campaign": save_campaign()
	world.notify("Veiculo comprado retirado sem nova cobranca.")
	set_menu("")

func hill_errand_prompt() -> String:
	var pos: Vector3 = world.subject_position()
	if hill_errand_stage == 0 and pos.distance_to(HILL_RESIDENT) < 3:
		return "F / Ajudar morador: buscar remedios na Clinica Costa (+$1800)"
	if world.network != null and world.network.active() and hill_errand_owner != multiplayer.get_unique_id(): return ""
	if hill_errand_stage == 1 and pos.distance_to(HILL_MEDICINE) < 3:
		return "F / Recolher os remedios do morador"
	if hill_errand_stage == 2 and pos.distance_to(HILL_RESIDENT) < 3:
		return "F / Entregar os remedios ao morador"
	return ""

func interact_hill_errand() -> bool:
	if world.active_car != null: return false
	var actor: int = world.network.rules.context_peer if world.network != null and world.network.active() else 0
	if world.network != null and world.network.active() and actor == 0: actor = multiplayer.get_unique_id()
	var pos: Vector3 = world.subject_position()
	if hill_errand_stage == 0 and pos.distance_to(HILL_RESIDENT) < 3:
		hill_errand_owner = actor
		hill_errand_stage = 1
		world.notify("Morador: Busque meu pacote de remedios na Clinica Costa e traga ao morro. Pago $1800.")
	elif hill_errand_stage == 1 and actor == hill_errand_owner and pos.distance_to(HILL_MEDICINE) < 3:
		hill_errand_stage = 2
		world.notify("Remedios recolhidos. Volte ao morador no morro perto dos apartamentos.")
	elif hill_errand_stage == 2 and actor == hill_errand_owner and pos.distance_to(HILL_RESIDENT) < 3:
		hill_errand_stage = 3
		if world.network != null and world.network.active(): world.network.rules.award(actor,1800)
		else: world.cash += 1800
		world.notify("Morador: Muito obrigado! / Entrega concluida: +$1800.")
	else:
		return false
	if game_mode == "campaign": save_campaign()
	return true

func show_passenger_boarding(start: Vector3, car_id: int) -> void:
	var car: Node3D = world.car_by_id(car_id)
	if not is_instance_valid(car):
		return
	var actor := Node3D.new()
	world.add_child(actor)
	actor.global_position = start
	var model := preload("res://scripts/human_visual.gd").new()
	actor.add_child(model)
	var side := 1.0 if car.to_local(start).x >= 0 else -1.0
	var tween := actor.create_tween()
	var car_ref: WeakRef = weakref(car)
	tween.tween_method(func(elapsed: float):
		var current_car: Node3D = car_ref.get_ref()
		if current_car == null:
			actor.queue_free()
		elif is_instance_valid(model):
			model.pose_vehicle_entry(actor, current_car, side, elapsed)
	, 0.0, 2.0, 2.0)
	tween.tween_callback(actor.queue_free)

func start_passenger_boarding(start: Vector3, car: Node3D) -> void:
	var data := {"start": start + Vector3(0, 0, 2), "car": car.net_id}
	if world.network != null and world.network.active():
		for id in world.network.rules.participants():
			world.network.rules.send_personal(id, "passenger_boarding", data)
	else:
		show_passenger_boarding(data.start, data.car)

func interact_campaign() -> bool:
	if ACTION_JOBS.has(job):
		var spec: Dictionary = ACTION_JOBS[job]
		if spec.kind == "clinic_evacuation" and stage < spec.points.size() and is_instance_valid(target_car) and world.active_car == target_car and absf(target_car.speed) < 3 and world.subject_position().distance_to(spec.points[stage]) < 5:
			start_passenger_boarding(spec.points[stage], target_car)
			stage += 1
			world.raise_heat(12 if stage < spec.points.size() else 35)
			world.notify("Paciente embarcado: %d/%d. Volte para a Clínica Costa." % [stage,spec.points.size()] if stage == spec.points.size() else "Paciente embarcado: %d/%d. Siga para a próxima localização." % [stage,spec.points.size()])
			return true
		if spec.kind == "assault" and stage == 1 and world.active_car == null and world.player.position.distance_to(spec.point) < 3:
			stage = 2
			world.notify("Objetivo recuperado. Saia do prédio a pé.")
			return true
		if spec.kind == "infiltration":
			if stage == 1:
				var guard := nearest_sentinel()
				if guard == null or world.active_car != null or world.player.position.distance_to(guard.position) > 2.8: return false
				if not mission_actor_crouched() or not guard.is_behind(world.player.position):
					trigger_infiltration_alarm()
					world.notify("O policial percebeu voce! A equipe tática foi alertada.")
					return true
				guard.silent_takedown()
				world.notify("Policial neutralizado sem ruido. Restantes: %d." % contract_guards_alive())
				return true
			if stage == 2 and world.active_car == null and world.player.position.distance_to(DATA_TERMINAL) < 3:
				stage = 3
				progress = 0
				spawn_infiltration_team()
				world.notify("Pendrive conectado. Extraindo dados por 30 segundos: proteja o computador!")
				return true
			if stage == 4 and world.active_car == null and world.player.position.distance_to(DATA_TERMINAL) < 3:
				stage = 5
				world.notify("Dados copiados. Pendrive recuperado; volte agachado pela tubulacao.")
				return true
			if stage == 5 and world.active_car == null and world.player.is_crouching and world.player.position.distance_to(DATA_VENT) < 3:
				complete_job()
				return true
		if spec.kind == "rescue" and stage == 0 and world.active_car != null and (target_car == null or world.active_car == target_car) and absf(world.active_car.speed) < 3 and world.subject_position().distance_to(spec.pickup) < 5:
			start_passenger_boarding(spec.pickup, world.active_car)
			passenger_car = world.active_car.net_id
			stage = 1
			world.notify("Passageiro a bordo. Chegue ao destino antes do tempo acabar.")
			return true
		if spec.kind == "escape_file" and stage == 0 and world.active_car == null and world.player.position.distance_to(spec.pickup) < 3:
			world.player.model.play_pickup_animation()
			stage = 1
			world.life.begin_apartment_stair_chase()
			world.notify("Arquivo recolhido! A policia entrou pelas escadas. Saia do predio e despiste a busca.")
			return true
		if spec.kind == "intercept" and stage == 1 and is_instance_valid(target_car) and world.active_car == null and world.player.position.distance_to(target_car.position) < 4:
			world.player.model.play_pickup_animation()
			stage = 2
			world.raise_heat(40)
			world.notify("Maleta recolhida! Despiste a policia e entregue no destino marcado.")
			return true
		if spec.kind == "defend" and stage == 0 and world.active_car == null and world.player.position.distance_to(spec.point) < 3:
			stage = 1
			spawn_action_guards()
			world.raise_heat(40)
			world.notify("Invasores chegando! Fique no local e elimine os atacantes.")
			return true
		if spec.kind == "cargo" and stage < spec.points.size() and world.active_car == null and world.player.position.distance_to(spec.points[stage]) < 3:
			world.player.model.play_pickup_animation()
			stage += 1
			world.raise_heat(15)
			world.notify("Caixa recolhida. Busque a proxima." if stage < spec.points.size() else "Carga reunida! Consiga um carro, despiste e leve a carga a oficina.")
			return true
		if spec.kind == "escort" and stage == 0 and is_instance_valid(target_car) and world.subject_position().distance_to(target_car.position) < 10:
			stage = 1
			target_car.route.assign(spec.track)
			target_car.traffic = true
			spawn_action_guards()
			world.raise_heat(45)
			world.notify("Comboio em movimento. Fique perto e proteja o veiculo dos atiradores!")
			return true
		if spec.kind == "foot_race" and stage == 0 and world.active_car == null and world.player.position.distance_to(spec.points[0]) < 3:
			stage = 1
			clock = float(spec.race_time)
			world.notify("Percurso iniciado! Corra pelos pontos e agache sob o cano na viela.")
			return true
		if spec.kind == "coop_race" and stage == 0 and world.active_car == null and not world.bus_passenger and world.player.position.distance_to(spec.points[0]) < 4:
			coop_race_participants.clear()
			for peer_id in world.network.rules.participants():
				var member: Dictionary = world.network.members[peer_id]
				if int(member.get("car", -1)) < 0 and not member.has("bus") and world.network.rules.position_of(peer_id).distance_to(spec.points[0]) <= 8.0:
					coop_race_participants.append(peer_id)
			if coop_race_participants.size() < 2:
				world.notify("A corrida precisa de pelo menos dois jogadores no ponto de partida.")
				coop_race_participants.clear()
				return true
			stage = 1
			clock = float(spec.race_time)
			world.notify("Corrida cooperativa iniciada! Alcancem cada ponto juntos.")
			return true
		if spec.kind == "breach" and stage < spec.points.size() and progress >= 1 and world.active_car == null and world.player.position.distance_to(spec.points[stage]) < 3:
			world.player.model.play_pickup_animation()
			stage += 1
			progress = 0
			world.raise_heat(12)
			world.notify("Documentos recolhidos. Abra o proximo cofre." if stage < spec.points.size() else "Documentos reunidos! Despiste e leve-os a APEX.")
			return true
		if spec.kind == "getaway" and stage == 0 and world.active_car == null and world.player.position.distance_to(spec.pickup) < 3:
			world.player.model.play_pickup_animation()
			stage = 1
			spawn_action_guards()
			world.raise_heat(100)
			world.notify("Maleta em maos! Pegue o Aurora X e escolha uma das duas rotas antes de voltar a garagem.")
			return true
		return false
	if job == 8 and stage == 0 and world.active_car != null and absf(world.active_car.speed) < 3 and world.subject_position().distance_to(INFORMANT_PICKUP) < 5:
		start_passenger_boarding(INFORMANT_PICKUP, world.active_car)
		passenger_car = world.active_car.net_id
		stage = 1
		world.raise_heat(60)
		world.notify("Informante a bordo! Despiste a policia antes de leva-lo ao esconderijo.")
		return true
	return false

func setup_action_job(actor := 0) -> bool:
	var spec: Dictionary = ACTION_JOBS[job]
	clock = float(spec.time)
	shipment_integrity = 100.0
	previous_mission_speed = 0.0
	if ACTION_JOBS[job].kind == "assault":
		spawn_action_guards()
	if ACTION_JOBS[job].kind == "infiltration":
		world.network.rules.clear_wanted()
		world.response_delay = 0
		world.crime_grace = 0
		spawn_infiltration_sentinels()
	if float(spec.get("start_heat",0)) > 0: world.raise_heat(float(spec.start_heat), actor)
	if spec.has("model"):
		var at := free_mission_car_spawn(spec.spawn,int(spec.model))
		if not at.is_finite():
			fail_job("A vaga do veiculo esta ocupada. Libere o local e tente novamente.")
			return false
		target_car = world.spawn_car(at,Color("fafafa") if spec.kind in ["rescue","clinic_evacuation"] else Color("e5c86a"),false,int(spec.model))
		target_car.owned = spec.kind not in ["intercept","getaway"]
		target_car.set_meta("mission_loan",true)
		if spec.kind == "intercept":
			target_car.traffic = true
			target_car.route.assign(spec.track)
	return true

func action_requires_car() -> bool:
	return ACTION_JOBS.has(job) and (ACTION_JOBS[job].kind in ["drive","rescue","clinic_evacuation"] or (ACTION_JOBS[job].kind == "cargo" and stage >= ACTION_JOBS[job].points.size()) or (ACTION_JOBS[job].kind == "getaway" and stage > 0))

func action_requires_foot() -> bool:
	return ACTION_JOBS.has(job) and ACTION_JOBS[job].kind in ["foot_race","coop_race","infiltration","assault"]

func action_destination() -> Vector3:
	var spec: Dictionary = ACTION_JOBS[job]
	match str(spec.kind):
		"clinic_evacuation": return target_car.position if stage < spec.points.size() and is_instance_valid(target_car) and world.active_car != target_car else (spec.points[stage] if stage < spec.points.size() else spec.drop)
		"assault": return spec.exit if stage == 2 else spec.point
		"infiltration":
			if stage == 1:
				var guard := nearest_sentinel()
				if guard != null: return guard.position
				return DATA_TERMINAL
			return DATA_VENT if stage in [0,5] else DATA_TERMINAL
		"getaway":
			if stage == 0: return spec.pickup
			if is_instance_valid(target_car) and world.active_car != target_car: return target_car.position
			var route_a: Array = spec.points
			var route_b: Array = spec.alternate_points
			if stage == 1 and progress == 0.0:
				return route_a[0] if world.subject_position().distance_squared_to(route_a[0]) < world.subject_position().distance_squared_to(route_b[0]) else route_b[0]
			var route: Array = route_b if int(progress) == 2 else route_a
			return route[mini(stage-1,route.size()-1)]
		"drive":
			return target_car.position if is_instance_valid(target_car) and world.active_car != target_car else spec.points[mini(stage,spec.points.size()-1)]
		"rescue":
			if stage == 0:
				return target_car.position if is_instance_valid(target_car) and world.active_car != target_car else spec.pickup
			var car: Node = world.car_by_id(passenger_car)
			return car.position if car != null and world.active_car != car else spec.drop
		"foot_race": return spec.points[mini(stage,spec.points.size()-1)]
		"coop_race": return spec.points[mini(stage,spec.points.size()-1)]
		"breach": return spec.points[stage] if stage < spec.points.size() else spec.drop
		"cargo": return spec.points[stage] if stage < spec.points.size() else spec.drop
		"escort": return target_car.position if is_instance_valid(target_car) else spec.drop
		"defend": return spec.point
		"precision": return spec.points[stage] if stage < spec.points.size() else spec.exit
		"escape_file": return spec.pickup if stage == 0 else spec.exit
		"intercept": return target_car.position if stage < 2 and is_instance_valid(target_car) else spec.drop
	return Vector3.ZERO

func action_objective() -> String:
	var spec: Dictionary = ACTION_JOBS[job]
	var text := ""
	match str(spec.kind):
		"assault": text = ["Elimine os invasores: %d" % contract_guards_alive(), "F / Recolha o objetivo", "Saia do prédio a pé"][mini(stage,2)]
		"clinic_evacuation": text = "Pegue a ambulância marcada" if world.active_car != target_car else ("Recolha pacientes / %d/%d" % [stage,spec.points.size()] if stage < spec.points.size() else "Volte à Clínica Costa com a ambulância")
		"infiltration":
			text = ["Vista a camiseta roxa do perfil, agache e abra a tubulacao", "Neutralize os dois policiais sem ruido / %d restantes" % contract_guards_alive(), "Entre no computador e conecte o pendrive", "Extraindo dados / %d%% / elimine a equipe tatica" % mini(roundi(progress/DATA_EXTRACTION_SECONDS*100),100), "Dados copiados / F para recuperar o pendrive", "Agache e fuja pela mesma tubulacao"][mini(stage,5)]
		"getaway":
			text = "F / Roubar a maleta no escritorio" if stage == 0 else ("Pegue o Aurora X marcado" if world.active_car != target_car else ("Escolha a rota norte ou sul e passe pelo primeiro ponto" if stage == 1 and progress == 0.0 else "Fuga %d/%d / leve a maleta a garagem" % [stage,spec.points.size()]))
			if stage == spec.points.size() and world.heat > 0: text = "Despiste as cinco estrelas antes da entrega final"
		"drive": text = "Pegue o veiculo marcado" if world.active_car != target_car else "Circuito %d/%d / preserve o carro" % [stage+1,spec.points.size()]
		"rescue":
			text = "Busque o passageiro de carro / F para embarcar" if stage == 0 else "Leve o passageiro ao destino"
			if stage == 0 and spec.has("model") and world.active_car != target_car: text = "Pegue o carro de atendimento marcado"
		"foot_race": text = "F / Iniciar percurso a pe" if stage == 0 else "Percurso %d/%d" % [stage,spec.points.size()-1]
		"coop_race": text = "F / Iniciar com a equipe" if stage == 0 else "Corrida da equipe %d/%d" % [stage,spec.points.size()-1]
		"breach": text = ("Cofre %d/%d / " % [stage+1,spec.points.size()] + ("F: recolher documentos" if progress >= 1 else "atire na fechadura")) if stage < spec.points.size() else "Despiste e entregue os documentos na APEX"
		"cargo": text = "F / Recolha a caixa %d/%d" % [stage+1,spec.points.size()] if stage < spec.points.size() else "Despiste e entregue a carga de carro na oficina"
		"escort": text = "F / Autorizar saida do comboio" if stage == 0 else "Proteja o comboio / veiculo %d%%" % roundi(target_car.hp/target_car.MAX_HP*100)
		"defend": text = "F / Iniciar defesa" if stage == 0 else "Resista %ds / invasores restantes: %d" % [maxi(0,ceili(float(spec.duration)-progress)),contract_guards_alive()]
		"precision": text = "Atire no transmissor %d/%d / andar %d" % [stage+1,spec.points.size(),floori(spec.points[stage].y/6)+1] if stage < spec.points.size() else "Saia do estudio e despiste o alarme"
		"escape_file": text = ["Pegue o arquivo no decimo andar / F","Desca e saia do predio cercado","Despiste a policia com o arquivo"][mini(stage,2)]
		"intercept": text = ["Danifique o carro do mensageiro sem destrui-lo","Saia do carro e use F para recolher a maleta","Despiste e entregue a maleta"][mini(stage,2)]
	if bool(spec.get("escape",false)) and stage == spec.points.size()-1 and world.heat > 0: text = "Despiste antes de entregar a carga"
	if bool(spec.get("fragile",false)): text += " / carga %d%%" % maxi(0,roundi(shipment_integrity))
	return "%s / %ds" % [text,ceili(clock)]

func tick_action_job(delta: float) -> void:
	var spec: Dictionary = ACTION_JOBS[job]
	clock -= delta
	if clock <= 0:
		fail_job("O tempo da operacao acabou.")
		return
	var stopped: bool = world.active_car != null and absf(world.active_car.speed) < 3
	match str(spec.kind):
		"assault":
			if stage == 0 and contract_guards_alive() == 0:
				stage = 1
				world.notify("Área segura. Recolha o objetivo.")
			elif stage == 2 and world.active_car == null and world.player.position.distance_to(spec.exit) < 5:
				complete_job()
		"clinic_evacuation":
			if not is_instance_valid(target_car) or target_car.hp <= float(spec.min_hp):
				fail_job("A ambulância ficou danificada demais.")
			elif stage == spec.points.size() and world.active_car == target_car and stopped and world.subject_position().distance_to(spec.drop) < 6:
				complete_job()
		"infiltration":
			if stage == 1 and contract_guards_alive() == 0:
				stage = 2
				world.notify("Area segura. Conecte o pendrive no computador.")
			elif stage == 3:
				progress += delta
				if progress >= DATA_EXTRACTION_SECONDS and contract_guards_alive() == 0:
					stage = 4
					world.notify("Extracao concluida. Recupere o pendrive do computador.")
		"getaway":
			if not is_instance_valid(target_car) or target_car.hp <= 0:
				fail_job("O carro da fuga foi destruido.")
			elif stage == 1 and progress == 0.0 and world.active_car == target_car:
				if world.subject_position().distance_to(spec.points[0]) < 8:
					progress = 1.0
					stage = 2
					world.notify("Rota norte escolhida. Siga os pontos até a garagem.")
				elif world.subject_position().distance_to(spec.alternate_points[0]) < 8:
					progress = 2.0
					stage = 2
					world.notify("Rota sul escolhida. Siga os pontos até a garagem.")
			elif stage > 1 and world.active_car == target_car:
				var route: Array = spec.alternate_points if int(progress) == 2 else spec.points
				if world.subject_position().distance_to(route[stage-1]) < 8 and (stage < route.size() or (stopped and world.heat <= 0)):
					stage += 1
					if stage > route.size(): complete_job()
		"drive":
			if bool(spec.get("fragile",false)) and is_instance_valid(target_car):
				var shock: float = absf(target_car.speed-previous_mission_speed)
				if shock > maxf(8.0,delta*45.0): shipment_integrity -= minf(40.0,shock*0.7)
				previous_mission_speed = target_car.speed
				if shipment_integrity <= 0:
					fail_job("A carga fragil foi destruida pelos impactos.")
					return
			if not is_instance_valid(target_car) or target_car.hp <= float(spec.get("min_hp",0)):
				fail_job("O veiculo do contrato ficou danificado demais.")
			elif world.active_car == target_car and world.subject_position().distance_to(spec.points[stage]) < float(spec.get("radius",8)) and (stage < spec.points.size()-1 or stopped) and (stage < spec.points.size()-1 or not bool(spec.get("escape",false)) or world.heat <= 0):
				stage += 1
				if stage >= spec.points.size(): complete_job()
		"rescue":
			var car: Node = world.car_by_id(passenger_car)
			if (spec.has("model") and (not is_instance_valid(target_car) or target_car.hp <= float(spec.get("min_hp",0)))) or (stage > 0 and (car == null or car.hp <= float(spec.get("min_hp",0)))): fail_job("O carro do passageiro ficou danificado demais.")
			elif stage > 0 and world.active_car == car and stopped and world.subject_position().distance_to(spec.drop) < 6: complete_job()
		"foot_race":
			if stage > 0:
				if world.active_car != null:
					fail_job("O percurso deve ser feito a pe.")
				elif world.player.position.distance_to(spec.points[stage]) < 2.5:
					stage += 1
					if stage >= spec.points.size(): complete_job()
		"coop_race":
			if stage > 0 and world.network != null and world.network.active() and not world.network.is_client():
				var together := true
				var active_participants: Array = world.network.rules.participants()
				for peer_id in coop_race_participants:
					if peer_id not in active_participants:
						together = false
						break
					var member: Dictionary = world.network.members[peer_id]
					if int(member.get("car", -1)) >= 0 or member.has("bus") or world.network.rules.position_of(peer_id).distance_to(spec.points[stage]) > 5.0:
						together = false
						break
				if together:
					stage += 1
					if stage >= spec.points.size(): complete_job()
		"breach":
			if stage >= spec.points.size() and world.heat <= 0 and world.subject_position().distance_to(spec.drop) < 7: complete_job()
		"cargo":
			if stage >= spec.points.size() and stopped and world.heat <= 0 and world.subject_position().distance_to(spec.drop) < 7: complete_job()
		"escort":
			if not is_instance_valid(target_car) or target_car.hp <= 0:
				fail_job("O veiculo do comboio foi destruido.")
			elif stage == 1:
				progress = progress+delta if world.subject_position().distance_to(target_car.position) > 80 else 0.0
				if progress > 12: fail_job("Voce abandonou o comboio.")
				elif target_car.position.distance_to(spec.drop) < 7:
					target_car.traffic = false
					target_car.speed = 0
					complete_job()
		"defend":
			if stage == 1:
				var distance: float = world.subject_position().distance_to(spec.point)
				if distance > 30:
					fail_job("Voce abandonou o refugio.")
					return
				if distance < 18:
					var previous_progress := progress
					progress += delta
					var waves := int(spec.get("waves", 1))
					for wave in range(1, waves):
						var wave_time: float = float(spec.duration) * wave / waves
						if previous_progress < wave_time and progress >= wave_time:
							spawn_action_guards()
							world.notify("Onda %d/%d: invasores chegando!" % [wave + 1, waves])
				if progress >= float(spec.duration) and contract_guards_alive() == 0: complete_job()
		"precision":
			if stage >= spec.points.size() and world.heat <= 0 and world.subject_position().distance_to(spec.exit) < 7: complete_job()
		"escape_file":
			if stage == 1 and world.subject_position().y < 2 and world.subject_position().distance_to(spec.exit) < 5:
				stage = 2
				world.life.stair_chase_started = false
			elif stage == 2 and world.heat <= 0: complete_job()
		"intercept":
			if stage < 2 and (not is_instance_valid(target_car) or target_car.hp <= 0):
				fail_job("A maleta foi perdida na explosao do mensageiro.")
			elif stage == 0 and target_car.hp <= 100:
				target_car.traffic = false
				target_car.speed = 0
				stage = 1
			elif stage == 2 and world.heat <= 0 and world.subject_position().distance_to(spec.drop) < 5: complete_job()

func action_prompt() -> String:
	if not ACTION_JOBS.has(job): return ""
	var spec: Dictionary = ACTION_JOBS[job]
	if spec.kind == "assault" and stage == 1 and world.active_car == null and world.player.position.distance_to(spec.point) < 3:
		return "F / Recolher objetivo"
	if spec.kind == "getaway" and stage == 0 and world.active_car == null and world.player.position.distance_to(spec.pickup) < 3:
		return "F / Roubar maleta e iniciar a fuga"
	if spec.kind == "foot_race" and stage == 0 and world.active_car == null and world.player.position.distance_to(spec.points[0]) < 3:
		return "F / Comecar percurso a pe"
	if spec.kind == "breach" and stage < spec.points.size() and world.active_car == null and world.player.position.distance_to(spec.points[stage]) < 3:
		return "F / Recolher documentos" if progress >= 1 else "Atire na fechadura do cofre"
	if spec.kind == "cargo" and stage < spec.points.size() and world.active_car == null and world.player.position.distance_to(spec.points[stage]) < 3:
		return "F / Recolher caixa de suprimentos"
	if spec.kind == "escort" and stage == 0 and is_instance_valid(target_car) and world.subject_position().distance_to(target_car.position) < 10:
		return "F / Iniciar escolta do comboio"
	if spec.kind == "defend" and stage == 0 and world.active_car == null and world.player.position.distance_to(spec.point) < 3:
		return "F / Iniciar defesa do refugio"
	if spec.kind == "drive" and is_instance_valid(target_car) and world.active_car == null and world.player.position.distance_to(target_car.position) < 4:
		return "E / Entrar no veiculo do contrato"
	if spec.kind == "rescue" and stage == 0 and world.subject_position().distance_to(spec.pickup) < 5:
		return "F / Embarcar passageiro" if world.active_car != null else "Traga um carro para buscar o passageiro"
	if spec.kind == "escape_file" and stage == 0 and world.active_car == null and world.player.position.distance_to(spec.pickup) < 3:
		return "F / Recolher o arquivo do decimo andar"
	if spec.kind == "intercept" and stage == 1 and is_instance_valid(target_car) and world.active_car == null and world.player.position.distance_to(target_car.position) < 4:
		return "F / Recolher a maleta"
	if spec.kind == "clinic_evacuation":
		if is_instance_valid(target_car) and world.active_car == null and world.player.position.distance_to(target_car.position) < 4:
			return "E / Entrar na ambulância"
		if stage < spec.points.size() and is_instance_valid(target_car) and world.active_car == target_car and absf(target_car.speed) < 3 and world.subject_position().distance_to(spec.points[stage]) < 5:
			return "F / Embarcar paciente"
	if spec.kind == "infiltration":
		if stage == 1:
			var guard := nearest_sentinel()
			if guard != null and world.active_car == null and world.player.position.distance_to(guard.position) < 2.8:
				return "F / Neutralizar em silencio" if world.player.is_crouching and guard.is_behind(world.player.position) else "Agache e aproxime-se por tras"
		if stage == 2 and world.active_car == null and world.player.position.distance_to(DATA_TERMINAL) < 3:
			return "F / Conectar pendrive"
		if stage == 4 and world.active_car == null and world.player.position.distance_to(DATA_TERMINAL) < 3:
			return "F / Recuperar pendrive"
		if stage == 5 and world.active_car == null and world.player.is_crouching and world.player.position.distance_to(DATA_VENT) < 3:
			return "F / Sair pela tubulacao"
	return ""

func campaign_target_hit(target: Node) -> bool:
	if not ACTION_JOBS.has(job) or int(target.get_meta("contract_job",-1)) != job or int(target.get_meta("contract_stage",-1)) != stage: return false
	var spec: Dictionary = ACTION_JOBS[job]
	if spec.kind == "infiltration" and stage == 0:
		if not mission_actor_crouched():
			trigger_infiltration_alarm()
		stage = 1
		target.visible = false
		target.use_collision = false
		world.notify("Tampa aberta. Entre agachado e neutralize os dois policiais." if world.heat <= 0 else "Tampa aberta, mas a equipe tática ouviu voce!")
		return true
	if spec.kind in ["precision","breach"]: hit_flash = 0.16
	if spec.kind == "breach":
		progress = 1
		world.notify("Fechadura aberta. Aproxime-se e aperte F para recolher os documentos.")
		return true
	if spec.kind == "precision":
		stage += 1
		world.raise_heat(40 if stage >= spec.points.size() else 4)
		world.notify("Transmissor derrubado. Va ao proximo alvo." if stage < spec.points.size() else "Sinal cortado! Saia do estudio e despiste o alarme.")
		return true
	return false

func spawn_action_guards() -> void:
	for at in ACTION_JOBS[job].get("guards",[]):
		var guard := Officer.new()
		guard.world = world
		guard.set_meta("mission_contract",job)
		if ACTION_JOBS[job].kind == "escort": guard.set_meta("mission_vehicle",target_car.net_id)
		world.add_child(guard)
		guard.position = at
		officers.append(guard)

func spawn_infiltration_sentinels() -> void:
	for i in 2:
		var guard := Officer.new()
		guard.world = world
		guard.set_meta("mission_contract",job)
		guard.set_meta("mission_sentinel",true)
		world.add_child(guard)
		guard.position = [Vector3(144,0.2,62),Vector3(150,0.2,62)][i]
		guard.rotation.y = PI
		officers.append(guard)

func spawn_infiltration_team() -> void:
	for at in [Vector3(144,0.2,63),Vector3(150,0.2,63),Vector3(144,0.2,67)]:
		var guard := Officer.new()
		guard.world = world
		guard.hp = 120
		guard.set_meta("mission_contract",job)
		guard.set_meta("mission_heavy",true)
		world.add_child(guard)
		guard.position = at
		officers.append(guard)

func nearest_sentinel() -> Node:
	var nearest: Node
	var distance := 2.8
	for guard in officers:
		if is_instance_valid(guard) and bool(guard.get_meta("mission_sentinel",false)) and guard.hp > 0:
			var current: float = world.player.position.distance_to(guard.position)
			if current < distance:
				nearest = guard
				distance = current
	return nearest

func mission_actor_crouched() -> bool:
	if world.network!=null and world.network.active():
		var actor: int = world.network.rules.context_peer
		return actor > 0 and bool(world.network.members.get(actor,{}).get("crouch",false))
	return world.player.is_crouching

func mission_noise() -> void:
	if job == SECRET_DATA_JOB and stage in [1,2]: trigger_infiltration_alarm()

func mission_shot_is_quiet() -> bool:
	return job == SECRET_DATA_JOB and stage == 0

func trigger_infiltration_alarm() -> void:
	if job != SECRET_DATA_JOB or stage >= 3: return
	world.raise_heat(100)

func mission_sentinel_killed() -> void:
	if job == SECRET_DATA_JOB and stage == 1 and contract_guards_alive() == 0:
		stage = 2
		world.notify("Area segura. Conecte o pendrive no computador.")

func contract_guards_alive() -> int:
	return officers.filter(func(guard): return is_instance_valid(guard) and int(guard.get_meta("mission_contract",-1)) == job and guard.hp > 0).size()

func free_mission_car_spawn(base: Vector3, model: int) -> Vector3:
	var query := PhysicsShapeQueryParameters3D.new()
	var box := BoxShape3D.new()
	box.size = Catalog.SIZES[model]+Vector3(0.2,0,0.2)
	query.shape = box
	query.collision_mask = 7
	for offset in [Vector3.ZERO,Vector3(0,0,6),Vector3(6,0,0),Vector3(-6,0,0),Vector3(0,0,-6)]:
		var at: Vector3 = base+offset
		query.transform = Transform3D(Basis.IDENTITY,at+Vector3.UP*box.size.y/2)
		if world.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): return at
	return Vector3.INF
