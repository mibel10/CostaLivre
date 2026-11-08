extends Node

const Officer = preload("res://scripts/officer.gd")
const Bank = preload("res://scripts/bank.gd")
const Catalog = preload("res://scripts/vehicle_catalog.gd")
const CAMPAIGN_LENGTH := 24

var JOBS := ["Correio da costa", "Caixa rápido", "Encomenda de luxo", "Volta da ilha", "Acerto de contas", "Golpe no banco", "Procurado", "Oficina em servico", "Correio a pe", "Plantao na clinica", "Inventario da praia", "Conexao no estudio", "Arquivo do decimo andar", "Emergencia medica", "Inspecao residencial", "Apartamento seguro", "Turno do cafe"]
var REWARDS := [2400, 800, 3200, 2200, 2800, 2000, 1800, 1800, 2200, 2600, 3000, 3400, 3800, 2300, 1700, 2600, 1900]
const GUN_SHOP := Vector3(-21, 0, 34)
const DEALER := Vector3(21, 0, 34)
const GARAGE := Vector3(-21, 0, 76)
const ROBBERIES := [Vector3(-63, 0, -8), Vector3(63, 0, -50), Vector3(21, 0, -89)]
const RACE := [Vector3(-126, 0, 84), Vector3(-126, 0, -84), Vector3(84, 0, -84), Vector3(84, 0, 84), Vector3(0, 0, 84)]
const CAR_PRICES := [2200,4800,8500,9500,12000,15000,1200,1800,3200]
const CAR_COLORS := [Color("30c9bf"),Color("e04959"),Color("b894ed"),Color("e9c24c"),Color("385b9d"),Color("dd6336"),Color("7b9c87"),Color("b4bdc7"),Color("bb3945")]
var STORY_BEATS := ["O primeiro serviço vai colocar você no mapa.","O caixa da praia pode resolver uma dívida urgente.","Um carro raro espera na rua. Leve-o até a garagem.","Cruze a cidade antes que o tempo acabe.","Dois veículos rivais estão atrapalhando o plano.","O Banco Costa esconde um cofre atrás da segurança.","A polícia fechou o cerco. Sobreviva e despiste a busca.","Um cliente precisa de uma rota rápida pela costa.","Faça a entrega a pé sem perder tempo.","Atravesse a avenida leste no limite.","Uma rota noturna exige precisão.","A carga urgente não pode esperar.","Complete o circuito costeiro para fechar o contrato.","A clínica precisa de ajuda para atender a vizinhança.","Uma reunião importante depende de você.","Proteja um contato no apartamento seguro.","O café precisa de uma última mão antes do amanhecer."]
var world: Node3D
var menu := ""
var officers: Array[CharacterBody3D] = []
var dispatch_time := 0.0
var job := -1
var stage := 0
var completed := 0
var clock := 0.0
var progress := 0.0
var target_car: CharacterBody3D
var targets: Array[CharacterBody3D] = []
var robbery_cooldowns := [0.0, 0.0, 0.0]
var robbery_index := -1
var robbery_progress := 0.0
var weapon := 1
var rifle_owned := false
var shotgun_owned := false
var smg_owned := false
var clips := [0, 12, 30, 8, 32]
var reserves := [0, 36, 0, 24, 96]
var fire_cooldown := 0.0
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

func _ready() -> void:
	if JOBS.size()==17:
		JOBS.append_array(["Estoque da costa", "Entrega ao mercado", "Serviço na avenida", "Inspeção do bairro", "Abastecimento urgente", "Documentos do leste", "Última entrega"])
		REWARDS.append_array([2400, 2600, 2800, 3000, 3200, 3400, 4000])
		STORY_BEATS.append_array(["Organize o estoque do supermercado.", "Faça a entrega no supermercado do leste.", "Ajude nos serviços da avenida.", "Inspecione os prédios do bairro novo.", "Prepare o abastecimento do mercado.", "Reúna os documentos nos escritórios.", "Conclua a última entrega na cidade nova."])
		JOBS.append_array(["Invasao ao Data Center [COOP]","Protocolo Fantasma [COOP]","Arquivo Zero [COOP]"])
		JOBS.append_array(["Sincronização do estoque [COOP]", "Bloqueio do mercado [COOP]"])
		REWARDS.append_array([6200,7400,8600,9000,10000])
		STORY_BEATS.append_array(["Desligue as cameras, invada o servidor, baixe os arquivos e escape da policia.","Cruze os andares sem ser visto, hackeie o controle central e saia com a chave-mestra.","Apague os rastros no mainframe e fuja do predio antes da equipe tatica.","Dois parceiros devem ativar os dois controles ao mesmo tempo.","Dois parceiros devem operar os terminais simultaneamente."])
	bank = Bank.new()
	bank.world = world
	world.add_child(bank)
	for i in 3:
		world.spawn_car(Vector3(24 + i * 35, 0.2, -126), CAR_COLORS[i], false, i + 1)
	setup_shot_audio()
	world.toast = "M: missões  •  TAB: mapa e lojas  •  ESC: controles"
	world.toast_time = 5

func job_count() -> int:
	return JOBS.size() if world.network!=null and world.network.active() else CAMPAIGN_LENGTH

func set_menu(value: String) -> void:
	menu = value
	if world.network!=null and world.network.rules.context_peer>1:
		world.network.personal.rpc_id(world.network.rules.context_peer,"menu",{"value":value})
		menu=value
		return
	world.get_tree().paused = value != "" and not (world.network!=null and world.network.active())
	world.engine_audio.stream_paused = value != ""
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if value != "" else Input.MOUSE_MODE_CAPTURED
	world.hud.queue_redraw()
	if world.pause_menu != null:
		world.pause_menu.open_for(value)

func handle_input(event: InputEvent) -> bool:
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
		if menu == "cars" and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_RIGHT,KEY_LEFT]:
			car_page = posmod(car_page+(1 if event.physical_keycode == KEY_RIGHT else -1),ceili(CAR_PRICES.size()/3.0))
			world.hud.queue_redraw()
			return true
		if menu == "jobs" and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_RIGHT, KEY_LEFT]:
			var pages := ceili(job_count()/7.0)
			job_page = posmod(job_page + (1 if event.physical_keycode == KEY_RIGHT else -1),pages)
			world.hud.queue_redraw()
			return true
		if event.is_action_pressed("pause") or event.is_action_pressed("jobs") or event.is_action_pressed("map"):
			set_menu("")
		elif event is InputEventKey and event.pressed and not event.echo:
			var choice: int = event.physical_keycode - KEY_1
			if menu == "jobs" and choice >= 0 and choice < 7 and choice + job_page * 7 < job_count():
				set_menu("")
				start_job(choice + job_page * 7)
			elif choice >= 0 and choice < (5 if menu == "guns" else 3):
				buy(choice)
		return true
	if world.get_tree().paused or world.finished:
		return false
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
		if world.network!=null and world.network.active():
			var place := nearby_place()
			if place in ["guns","cars","garage"]:
				set_menu(place)
			elif world.life.prompt().to_lower().contains("elevador"):
				world.life.interact()
			else:
				world.network.rules.send_action("interact",{})
			return true
		if world.life != null and world.life.interact():
			return true
		if bank.interact():
			return true
		var nearby := nearby_place()
		if nearby in ["guns", "cars"]:
			set_menu(nearby)
		elif nearby == "garage":
			if world.active_car != null:
				set_menu("garage")
			else:
				world.notify("Entre em um carro para usar a oficina.")
		return true
	if event.is_action_pressed("reload"):
		if world.network!=null and world.network.active():
			world.network.rules.send_action("reload",{})
		else:
			reload()
		return true
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5]:
			var selected: int = event.physical_keycode - KEY_1 + 1
			if selected == 3:
				weapon = 0
			elif selected == 1 or (selected == 2 and rifle_owned) or (selected == 4 and shotgun_owned) or (selected == 5 and smg_owned):
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
	if choice < 0 or choice > (4 if menu == "guns" else 2):
		return
	if menu == "garage":
		if world.active_car == null:
			return
		if choice != 0 and world.active_car.hp <= 0:
			world.notify("Repare o veículo antes de personalizar.")
			return
		var price: int = [250,300,500][choice]
		if choice == 2 and world.active_car.engine_upgrade >= 10:
			world.notify("Motor já está no nível máximo.")
			return
		if not spend(price):
			return
		if choice == 0:
			world.active_car.repair()
			world.health = 100
		elif choice == 1:
			var colors := [Color("e04959"),Color("30c9bf"),Color("b894ed"),Color("e4b84c"),Color("ececec"),Color("343b49")]
			var current: int = colors.find(world.active_car.paint)
			world.active_car.repaint(colors[(current+1)%colors.size()])
		else:
			world.active_car.engine_upgrade = minf(10.0,world.active_car.engine_upgrade+2.5)
		world.notify("Serviço da oficina concluído.")
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
	elif menu == "cars":
		choice += car_page*3
		if choice >= CAR_PRICES.size():
			return
		var at := Vector3(18, 0.3, 44)
		for car in world.cars:
			if car.position.distance_to(at) < 5:
				world.notify("Libere a saída da concessionária antes de comprar.")
				return
		if not spend(CAR_PRICES[choice]):
			return
		var car: CharacterBody3D = world.spawn_car(at, CAR_COLORS[choice], false, choice + 1)
		car.owned = true
		world.notify("%s comprado! Seu carro está na saída da APEX." % car.model_name)
	else:
		return
	set_menu("")

func nearby_place() -> String:
	var pos: Vector3 = world.subject_position()
	if pos.distance_to(GUN_SHOP) < 5:
		return "guns"
	if pos.distance_to(DEALER) < 5:
		return "cars"
	if pos.distance_to(GARAGE) < 5:
		return "garage"
	for i in 2:
		if pos.distance_to(ROBBERIES[i]) < 5:
			return "robbery"
	return ""

func prompt() -> String:
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
		"guns": return "F  ·  Loja de armas"
		"cars": return "F  ·  Concessionária APEX"
		"garage": return "F  ·  Oficina: reparo e personalização"
		"robbery": return "Segure F a pé com uma arma  ·  Assaltar"
	if world.active_car == null and world.nearest_car() != null:
		return "E  ·  Entrar no carro"
	return ""

func start_job(index: int) -> void:
	if world.network!=null and world.network.is_client():
		world.network.rules.send_action("job",{"index":index})
		return
	if index>=24 and (world.network==null or not world.network.active()):
		world.notify("Esta operacao e exclusiva do multiplayer.")
		return
	if index in [27,28] and world.network.rules.participants().size() < 2:
		world.notify("Esta missão exige dois jogadores ativos.")
		return
	if index < 0 or index >= JOBS.size():
		return
	# Replacing a contract cannot leave unbounded parked mission vehicles behind.
	if target_car != null and target_car != world.active_car:
		remove_car(target_car)
	for car in targets:
		if is_instance_valid(car) and car != world.active_car:
			remove_car(car)
	target_car = null
	targets.clear()
	job = index
	stage = 0
	clock = (360.0 if job >= 24 else ((160.0 if job == 8 else 100.0) if job >= 7 else (95.0 if job == 3 else 0.0)))
	progress = 0
	if job == 2:
		target_car = world.spawn_car(Vector3(-84, 0.2, 42), CAR_COLORS[1], false, 2)
	elif job == 4:
		for z in [-42, 0]:
			var car: CharacterBody3D = world.spawn_car(Vector3(88, 0.2, z + 12), Color("8c526b"), false, 1)
			car.hp = 60
			targets.append(car)
	elif job == 6:
		world.raise_heat(80)
	elif job>=24:
		world.raise_heat(42)
	world.notify("Contrato: %s. Recompensa $%d." % [JOBS[job], REWARDS[job]])
	if world.cutscene != null:
		world.play_cutscene("CAPÍTULO %02d  ·  %s" % [index + 1, JOBS[index].to_upper()], ("Entre no predio e realize os tres servicos marcados. Nos andares altos, use F no elevador." if index in [7,9,10,11,12,13,14,15,16] else STORY_BEATS[index]))

func begin_campaign() -> void:
	load_campaign()
	if campaign_index >= CAMPAIGN_LENGTH:
		world.pause_menu.show_campaign_complete()
		return
	save_campaign()
	start_job(campaign_index)

func save_campaign() -> bool:
	var save := ConfigFile.new()
	save.set_value("story", "next_mission", campaign_index)
	save.set_value("story", "cash", world.cash)
	save.set_value("story", "health", world.health)
	save.set_value("story", "completed", completed)
	save.set_value("story", "weapon", weapon)
	save.set_value("story", "clips", clips)
	save.set_value("story", "reserves", reserves)
	save.set_value("story", "rifle_owned", rifle_owned)
	save.set_value("story", "shotgun_owned", shotgun_owned)
	save.set_value("story", "smg_owned", smg_owned)
	var error := save.save(campaign_save_path)
	if error != OK:
		world.notify("Falha ao salvar a campanha (%s)." % error_string(error))
		return false
	var progress_save := ConfigFile.new()
	progress_save.set_value("story", "next_mission", campaign_index)
	progress_save.save(campaign_path)
	return true

func load_campaign() -> void:
	var save := ConfigFile.new()
	if save.load(campaign_save_path) != OK:
		var legacy := ConfigFile.new()
		campaign_index = clampi(legacy.get_value("story", "next_mission", 0) if legacy.load(campaign_path) == OK else 0, 0, CAMPAIGN_LENGTH)
		return
	campaign_index = clampi(save.get_value("story", "next_mission", 0), 0, CAMPAIGN_LENGTH)
	world.cash = int(save.get_value("story", "cash", world.cash))
	world.health = float(save.get_value("story", "health", world.health))
	completed = int(save.get_value("story", "completed", campaign_index))
	weapon = clampi(save.get_value("story", "weapon", 1), 0, 4)
	clips = save.get_value("story", "clips", clips).duplicate()
	reserves = save.get_value("story", "reserves", reserves).duplicate()
	rifle_owned = save.get_value("story", "rifle_owned", false)
	shotgun_owned = save.get_value("story", "shotgun_owned", false)
	smg_owned = save.get_value("story", "smg_owned", false)

func save_campaign_now() -> void:
	if game_mode != "campaign":
		world.notify("Salvar manualmente só está disponível na campanha.")
		return
	if save_campaign():
		world.notify("Campanha salva neste dispositivo.")

func has_campaign_save() -> bool:
	return FileAccess.file_exists(campaign_save_path)

func new_campaign() -> void:
	campaign_index = 0
	completed = 0
	world.cash = 900
	world.health = 100
	weapon = 1
	clips = [0, 12, 30, 8, 32]
	reserves = [0, 36, 0, 0, 0]
	rifle_owned = false
	shotgun_owned = false
	smg_owned = false
	start_job(0)
	save_campaign()

func advance_campaign() -> void:
	if campaign_index >= CAMPAIGN_LENGTH:
		world.play_cutscene("COSTA LIVRE", "Você concluiu os 24 capítulos e mudou o destino da cidade.", func(): world.pause_menu.show_campaign_complete())
	else:
		start_job(campaign_index)

func fail_job(message: String) -> void:
	var failed_index := job
	job = -1
	progress = 0
	world.notify(message)
	if game_mode == "campaign":
		world.play_cutscene("MISSÃO FALHOU", "%s  ·  Vamos tentar de novo." % JOBS[failed_index], func(): start_job(campaign_index))

func remove_car(car: CharacterBody3D) -> void:
	world.cars.erase(car)
	car.queue_free()

func destination() -> Vector3:
	if job in [27,28]: return Vector3(294 if job == 27 else 798,0,-99)
	if job>=24:
		return world.life.mission_position()
	if job in [7,9,10,11,12,13,14,15,16] or world.life.NEW_TASKS.has(job):
		return world.life.mission_position()
	if bank.inside() and bank.phase < 5:
		return bank.next_position()
	match job:
		8:
			var routes := [[Vector3(168,0,84),Vector3(168,0,-84),Vector3(0,0,84)], [Vector3(0,0,42),Vector3(42,0,42),Vector3(42,0,0)], [Vector3(168,0,-84),Vector3(168,0,84),Vector3(84,0,0)], [Vector3(-168,0,84),Vector3(-168,0,-84),Vector3(-84,0,0)], [Vector3(126,0,126),Vector3(-126,0,126),Vector3(-168,0,0)], [Vector3(-168,0,-84),Vector3(168,0,-84),Vector3(168,0,84)]]
			return routes[job - 7][mini(stage,2)]
		0: return world.STOPS[mini(stage, 2)]
		1: return ROBBERIES[0]
		2:
			if world.active_car == target_car:
				return Vector3(-42, 0, 84)
			return target_car.position if is_instance_valid(target_car) else Vector3(-84, 0, 42)
		3: return RACE[mini(stage, RACE.size() - 1)]
		4:
			for car in targets:
				if car.hp > 0:
					return car.position
		5: return bank.next_position()
	return world.subject_position()

func objective() -> String:
	if job in [27,28]: return "Dois jogadores: segurem F a 4m nos lados leste e oeste / %d%%" % roundi(progress / 8.0 * 100)
	if job>=24:
		return "%s  /  %d:%02d" % [world.life.task_label(),int(clock)/60,int(clock)%60]
	if job in [7,9,10,11,12,13,14,15,16] or world.life.NEW_TASKS.has(job):
		return world.life.task_label()
	if bank.inside() or (bank.phase == 4):
		return bank.objective()
	match job:
		8: return "%s %d/3 - %ds" % [JOBS[job], stage+1, ceili(clock)]
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
		campaign_index = finished_index + 1
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
			var capacity: int = [0, 12, 30, 8, 32][reload_weapon]
			var count := mini(capacity - clips[reload_weapon], reserves[reload_weapon])
			clips[reload_weapon] += count
			reserves[reload_weapon] -= count
	if Input.is_action_pressed("shoot"):
		shoot()
	for i in robbery_cooldowns.size():
		robbery_cooldowns[i] = maxf(0, robbery_cooldowns[i] - delta)
	tick_robbery(delta)
	tick_pedestrian_robbery(delta)
	bank.tick(delta)
	if world.life != null:
		world.life.tick_leisure(delta)
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
	if job < 0:
		return
	var distance: float = world.subject_position().distance_to(destination())
	var stopped: bool = world.active_car != null and absf(world.active_car.speed) < 3
	match job:
		8:
			clock -= delta
			if clock <= 0:
				fail_job("Tempo esgotado.")
			elif distance < 7 and (world.active_car == null if job == 8 else world.active_car != null):
				stage += 1
				if stage >= 3:
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
	var nearby := -1
	for i in 2:
		if world.subject_position().distance_to(ROBBERIES[i]) < 5:
			nearby = i
	if nearby < 0 or world.active_car != null or weapon == 0 or not world.activity_held():
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
	var distance := 2.5
	for person in world.life.people:
		if person.stationary or person.robbed or person.hp <= 0:
			continue
		var current: float = world.player.position.distance_to(person.position)
		if current < distance:
			distance = current
			closest = person
	return closest

func tick_pedestrian_robbery(delta: float) -> void:
	var target := nearest_robbery_target()
	if target == null or not world.activity_held():
		if is_instance_valid(pedestrian_target):
			pedestrian_target.scared = false
		pedestrian_target = null
		pedestrian_robbery_progress = 0
		return
	if target != pedestrian_target:
		if is_instance_valid(pedestrian_target):
			pedestrian_target.scared = false
		pedestrian_target = target
		pedestrian_robbery_progress = 0
		target.scared = true
		world.raise_heat(8)
		world.notify("Segure F perto do pedestre para pegar o dinheiro.")
	pedestrian_robbery_progress += delta
	if pedestrian_robbery_progress >= 2.0:
		var payout: int = world.rng.randi_range(40, 180)
		world.cash += payout
		pedestrian_target.robbed = true
		pedestrian_target.scared = false
		pedestrian_target = null
		pedestrian_robbery_progress = 0
		world.notify("+$%d. A policia foi alertada!" % payout)

func reload() -> void:
	if weapon <= 0 or reload_time > 0 or reserves[weapon] <= 0:
		return
	var capacity: int = [0, 12, 30, 8, 32][weapon]
	if clips[weapon] >= capacity:
		return
	reload_weapon = weapon
	reload_time = 1.2 if weapon == 1 else (1.8 if weapon == 2 else 2.0)

func shoot() -> void:
	if world.network!=null and world.network.active():
		world.network.rules.fire_local()
		return
	if world.player.roll_time > 0 or world.car_transition:
		return
	if weapon == 0:
		world.extra.punch()
		return
	if weapon <= 0 or fire_cooldown > 0 or reload_time > 0 or world.active_car != null or bank.hacking:
		return
	if clips[weapon] <= 0:
		reload()
		return
	clips[weapon] -= 1
	fire_cooldown = [0.32, 0.11, 0.65, 0.075][weapon - 1]
	world.raise_heat(3)
	var camera: Camera3D = world.camera
	var origin := camera.global_position
	var end := origin - camera.global_basis.z * 180
	var query := PhysicsRayQueryParameters3D.create(origin, end, 7)
	query.exclude = [world.player.get_rid()]
	var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		end = hit.position
	var muzzle: Vector3 = world.player.position + Vector3(0, 1.35, 0)
	var muzzle_query := PhysicsRayQueryParameters3D.create(muzzle, end, 7)
	muzzle_query.exclude = [world.player.get_rid()]
	var obstruction := world.get_world_3d().direct_space_state.intersect_ray(muzzle_query)
	if not obstruction.is_empty():
		hit = obstruction
		end = obstruction.position
	if not hit.is_empty():
		if hit.collider.has_method("take_hit"):
			hit.collider.take_hit([34, 24, 58, 18][weapon - 1])
			hit_flash = 0.16
	trace(muzzle, end, Color("ffe5a0"))
	shot_audio.pitch_scale = [0.85, 1.2, 0.65, 1.45][weapon - 1]
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
	if job==12 and stage>=1 and world.life.apartment_tenth_floor_occupied():
		world.life.begin_apartment_stair_chase()
	if world.life.stair_chase_started:
		if job==12:
			world.heat=maxf(world.heat,40.0)
		else:
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
		var target:Vector3=world.police_target(officers[i]) if world.network!=null and world.network.active() else world.subject_position()
		var mission_stair:bool=bool(officers[i].get_meta("mission_stair",false))
		if (mission_stair and job!=12) or (not mission_stair and (world.heat < response_threshold or officers[i].position.distance_to(target) > 70)):
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
