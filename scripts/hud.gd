extends Control

var world: Node3D
var font: Font
var ink := Color("edf1ed")
var muted := Color("a7b9bf")
var gold := Color("ffd18a")
var navy := Color(0.035, 0.085, 0.12, 0.82)
var panel_styles := {}
var phone_button: Button
var phone_panel: PanelContainer
var phone_scroll: ScrollContainer
var phone_apps: GridContainer
var phone_status: Label
var phone_messages: VBoxContainer
var phone_message_text: Label
var phone_contract_index := -1
var invite_available := false
var tutorial_panel: PanelContainer
const CHOICE_MENUS := ["jobs", "guns", "heavy_guns", "cars", "garage_cars", "owned_cars", "garage", "credits"]
const PAGE_MENUS := ["jobs", "cars", "garage_cars", "owned_cars"]
const MENU_CLOSE := Rect2(762, 590, 156, 52)
const MENU_PREVIOUS := Rect2(362, 590, 130, 56)
const MENU_NEXT := Rect2(506, 590, 130, 56)
const HACK_CLOSE := Rect2(778, 595, 136, 50)

func choice_rect(index: int) -> Rect2:
	var mobile := OS.has_feature("android")
	return Rect2(362, 207 + index * (53 if mobile else 48), 556, 44 if mobile else 39)

func hack_key_rect(index: int) -> Rect2:
	var mobile := OS.has_feature("android")
	return Rect2(365 + index * 142, 517, 118 if mobile else 100, 62 if mobile else 48)

func draw_choice(rect: Rect2, value: String, size := 17) -> void:
	panel(rect, Color("20343f"), 7)
	text(value, rect.position + Vector2(16, (rect.size.y + size) * 0.5 - 2), size)

const WEAPON_ICONS := [
	[Vector2(9,14),Vector2(16,8),Vector2(35,8),Vector2(35,14),Vector2(46,14),Vector2(48,23),Vector2(43,31),Vector2(25,31),Vector2(18,26),Vector2(9,26)],
	[Vector2(10,9),Vector2(52,9),Vector2(52,17),Vector2(33,17),Vector2(28,33),Vector2(17,33),Vector2(20,17),Vector2(10,17)],
	[Vector2(3,12),Vector2(21,12),Vector2(21,9),Vector2(52,9),Vector2(52,13),Vector2(63,13),Vector2(63,17),Vector2(40,17),Vector2(43,28),Vector2(35,29),Vector2(30,17),Vector2(24,17),Vector2(20,25),Vector2(15,25),Vector2(17,17),Vector2(3,21)],
	[Vector2(2,22),Vector2(19,13),Vector2(62,13),Vector2(62,18),Vector2(45,18),Vector2(45,22),Vector2(31,22),Vector2(31,18),Vector2(20,18),Vector2(4,30)],
	[Vector2(7,12),Vector2(17,12),Vector2(17,9),Vector2(48,9),Vector2(48,13),Vector2(55,13),Vector2(55,17),Vector2(39,17),Vector2(39,31),Vector2(33,31),Vector2(31,17),Vector2(25,17),Vector2(22,27),Vector2(16,27),Vector2(17,17),Vector2(7,17)],
	[Vector2(3,8),Vector2(15,11),Vector2(50,11),Vector2(60,7),Vector2(63,11),Vector2(63,21),Vector2(58,24),Vector2(49,20),Vector2(35,20),Vector2(32,32),Vector2(26,32),Vector2(28,20),Vector2(15,20),Vector2(3,23)],
	[Vector2(2,19),Vector2(15,14),Vector2(27,14),Vector2(27,10),Vector2(23,10),Vector2(23,5),Vector2(43,5),Vector2(43,10),Vector2(38,10),Vector2(38,14),Vector2(62,14),Vector2(62,18),Vector2(37,18),Vector2(32,26),Vector2(28,26),Vector2(30,18),Vector2(16,18),Vector2(3,27)],
	[Vector2(4,11),Vector2(15,11),Vector2(15,6),Vector2(48,6),Vector2(48,10),Vector2(57,10),Vector2(62,15),Vector2(62,24),Vector2(46,24),Vector2(46,28),Vector2(30,28),Vector2(26,34),Vector2(18,34),Vector2(21,23),Vector2(4,23)],
]

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = ThemeDB.fallback_font
	phone_button = Button.new()
	phone_button.text = "CELULAR"
	phone_button.custom_minimum_size = Vector2(142,48)
	phone_button.size = Vector2(142,48)
	phone_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	phone_button.position = Vector2(-158,-66)
	phone_button.visible = not OS.has_feature("android")
	phone_button.pressed.connect(toggle_phone)
	add_child(phone_button)
	phone_panel = PanelContainer.new()
	phone_panel.custom_minimum_size = Vector2(360,540)
	phone_panel.size = Vector2(360,540)
	phone_panel.z_index = 20
	var shell := StyleBoxFlat.new()
	shell.bg_color = Color("102b40")
	shell.border_color = Color("080e17")
	shell.set_border_width_all(7)
	shell.set_corner_radius_all(32)
	shell.content_margin_left = 20
	shell.content_margin_right = 20
	shell.content_margin_top = 14
	shell.content_margin_bottom = 14
	phone_panel.add_theme_stylebox_override("panel",shell)
	phone_panel.hide()
	add_child(phone_panel)
	var screen := VBoxContainer.new()
	screen.add_theme_constant_override("separation",12)
	phone_panel.add_child(screen)
	phone_status = Label.new()
	phone_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phone_status.add_theme_font_size_override("font_size",13)
	screen.add_child(phone_status)
	var brand := Label.new()
	brand.text = "COSTA\nLIVRE"
	brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	brand.add_theme_font_size_override("font_size",28)
	brand.add_theme_color_override("font_color",Color("81e8dd"))
	screen.add_child(brand)
	phone_apps = GridContainer.new()
	phone_apps.columns = 2
	phone_apps.add_theme_constant_override("h_separation",10)
	phone_apps.add_theme_constant_override("v_separation",10)
	phone_scroll = ScrollContainer.new()
	phone_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	phone_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	screen.add_child(phone_scroll)
	phone_scroll.add_child(phone_apps)
	phone_apps.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var rematch := Button.new()
	rematch.text = "REVANCHE\nPVP"
	rematch.custom_minimum_size = Vector2(145,80)
	rematch.pressed.connect(phone_app.bind("rematch"))
	phone_apps.add_child(rematch)
	for item in [["PVP / ENTRAR OU SAIR DA FILA", "pvp"],["USAR STAND / H", "stand"],["USAR FLECHA DOURADA", "stand_select"],["CONTRATOS / MENSAGENS", "messages"],["CONVITES", "invites"],["MISSÕES", "jobs"],["MAPA", "map"],["CHAT DA REGIÃO", "chat"],["RODA DE EMOTES / B", "emote_wheel"],["CUMPRIMENTAR", "wave"],["GRIDDY", "griddy"],["DANÇA", "dance"],["GOLDEN WIND / TORTURE DANCE", "torture_dance"],["TAKE THE L", "take_l"]]:
		var app := Button.new()
		app.text = str(item[0]).replace(" / ","\n").replace(" OU ","\n")
		app.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		app.custom_minimum_size = Vector2(145,80)
		app.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		app.add_theme_font_size_override("font_size",14)
		var tile := StyleBoxFlat.new()
		tile.bg_color = Color("21465a") if phone_apps.get_child_count()%2 == 0 else Color("25404f")
		tile.set_corner_radius_all(17)
		tile.content_margin_left = 10
		tile.content_margin_right = 10
		app.add_theme_stylebox_override("normal",tile)
		var highlight := tile.duplicate() as StyleBoxFlat
		highlight.bg_color = Color("347c87")
		app.add_theme_stylebox_override("hover",highlight)
		app.add_theme_stylebox_override("pressed",highlight)
		app.pressed.connect(phone_app.bind(item[1]))
		phone_apps.add_child(app)
	phone_messages = VBoxContainer.new()
	phone_messages.hide()
	phone_messages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	screen.add_child(phone_messages)
	phone_message_text = Label.new()
	phone_message_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	phone_messages.add_child(phone_message_text)
	var accept_contract := Button.new()
	accept_contract.text = "ACEITAR CONTRATO"
	accept_contract.pressed.connect(accept_phone_contract)
	phone_messages.add_child(accept_contract)
	var dismiss_contract := Button.new()
	dismiss_contract.text = "IGNORAR"
	dismiss_contract.pressed.connect(func(): close_phone_message())
	phone_messages.add_child(dismiss_contract)
	var back := Button.new()
	back.text = "VOLTAR"
	back.pressed.connect(func(): phone_messages.hide(); phone_scroll.show())
	phone_messages.add_child(back)
	var home := Button.new()
	home.text = "FECHAR  ━"
	home.custom_minimum_size.y = 44
	home.pressed.connect(toggle_phone)
	screen.add_child(home)

func toggle_phone() -> void:
	if world.extra != null and (world.extra.wheel or world.extra.emote_wheel):
		world.extra.wheel = false
		world.extra.finish_emote_wheel()
	phone_panel.visible = not phone_panel.visible
	world.restore_pointer()

func phone_app(app: String) -> void:
	phone_panel.hide()
	match app:
		"rematch":
			if world.network.active(): world.network.rules.send_action("pvp_rematch")
			else: world.notify("Entre em uma sala para disputar uma revanche.")
		"pvp":
			if world.network.active(): world.network.rules.send_action("pvp_join")
			else: world.notify("Conecte-se a uma sala multiplayer para convidar ao PvP.")
		"stand": world.network.rules.local_stand_action()
		"stand_select": world.network.rules.local_stand_action(true)
		"messages":
			phone_panel.show()
			phone_scroll.hide()
			phone_messages.show()
			phone_message_text.text = "Nenhuma proposta nova." if phone_contract_index < 0 else "Mensagem de uma empresa local:\n\nContrato: %s\n\nAceite para iniciar." % world.activities.JOBS[phone_contract_index]
		"invites":
			if invite_available and world.network.active(): world.network.open_mission_offer()
			else: world.notify("Você não tem convites de atividade pendentes.")
		"jobs": world.activities.set_menu("jobs")
		"map": world.pause_menu.show_page("map")
		"chat":
			if world.network.active(): world.network.open_chat()
			else: world.notify("O chat regional fica disponível durante o multiplayer.")
		"emote_wheel": world.extra.emote_wheel = true
		_: world.network.send_emote(app)
	world.restore_pointer()
	queue_redraw()

func show_contract_message(index: int) -> void:
	if index < 0 or index >= world.activities.JOBS.size():
		return
	phone_contract_index = index
	phone_button.text = "CELULAR · NOVA MENSAGEM"
	world.notify("Nova proposta no celular: %s." % world.activities.JOBS[index])

func accept_phone_contract() -> void:
	if phone_contract_index < 0:
		return
	var index := phone_contract_index
	if world.network.active():
		world.network.rules.send_action("phone_contract_response",{"index":index,"accept":true})
	else:
		world.activities.start_job(index)
	close_phone_message()

func close_phone_message() -> void:
	phone_contract_index = -1
	phone_button.text = "CELULAR · CONVITE" if invite_available else "CELULAR"
	phone_messages.hide()
	phone_scroll.show()

func set_phone_invite_available(value: bool) -> void:
	invite_available = value
	if phone_contract_index < 0:
		phone_button.text = "CELULAR · CONVITE" if invite_available else "CELULAR"

func show_tutorial() -> void:
	if world.profile.tutorial_seen or tutorial_panel != null:
		return
	tutorial_panel = PanelContainer.new()
	tutorial_panel.set_anchors_preset(Control.PRESET_CENTER)
	tutorial_panel.position = Vector2(-260,-150)
	tutorial_panel.size = Vector2(520,300)
	tutorial_panel.theme = world.pause_menu.canvas.theme
	var content := VBoxContainer.new()
	tutorial_panel.add_child(content)
	var title := Label.new()
	title.text = "COMEÇANDO EM COSTA LIVRE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var tips := Label.new()
	tips.text = "PC: WASD para andar, mouse para olhar, F para interagir e M para contratos.\nAndroid: use o direcional e os botões na tela.\nUse o celular para mensagens, convites, mapa e emotes.\nNo multiplayer, o host valida missões e ações compartilhadas."
	tips.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(tips)
	var skip := Button.new()
	skip.text = "ENTENDI / PULAR TUTORIAL"
	skip.pressed.connect(func(): world.profile.mark_tutorial_seen(); tutorial_panel.queue_free(); tutorial_panel = null)
	content.add_child(skip)
	world.hud.get_parent().add_child(tutorial_panel)

func _process(_delta: float) -> void:
	if world != null and is_instance_valid(phone_button):
		if phone_panel.visible:
			var screen_size := get_viewport_rect().size
			var fit := minf(1.0,minf((screen_size.x-24)/360.0,(screen_size.y-24)/540.0))
			phone_panel.scale = Vector2.ONE*fit
			phone_panel.position = (screen_size-phone_panel.size*fit)*0.5
			var clock := Time.get_time_dict_from_system()
			phone_status.text = "%02d:%02d     ●●●  COSTA NET     ▰" % [clock.hour,clock.minute]
		if world.finished or world.activities.menu not in ["", "chat"] or world.cutscene.active:
			phone_panel.hide()
		phone_button.visible = not OS.has_feature("android") and not world.finished and world.activities.menu in ["", "chat"] and not world.cutscene.active

func text(value: String, at: Vector2, size: int = 16, color := Color("edf1ed")) -> void:
	draw_string(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func panel(rect: Rect2, color: Color = navy, radius := 8) -> void:
	var key := color.to_html() + str(radius)
	if not panel_styles.has(key):
		var style := StyleBoxFlat.new()
		style.bg_color = color
		style.set_corner_radius_all(radius)
		panel_styles[key] = style
	draw_style_box(panel_styles[key], rect)

func bar(at: Vector2, width: float, ratio: float, color: Color) -> void:
	draw_rect(Rect2(at, Vector2(width, 4)), Color("33454e"))
	draw_rect(Rect2(at, Vector2(width * clampf(ratio, 0, 1), 4)), color)

func _draw() -> void:
	if world == null or font == null or world.activities == null:
		return
	draw_set_transform(Vector2.ZERO, 0, get_viewport_rect().size / Vector2(1280, 720))
	if world.network != null and world.activities.menu == "":
		var rules: Node = world.network.rules
		var sheet: Dictionary = rules.stand_sheet(multiplayer.get_unique_id())
		var selected := int(sheet.get("stand",-1))
		var arrows := int(sheet.get("golden_arrows",0))
		var stand_status := "Sem Stand · Flechas: %d · use o celular" % arrows
		if selected >= 0 and selected < rules.STAND_NAMES.size():
			stand_status = "%s / H / %.0fs · Flechas: %d" % [rules.STAND_NAMES[selected],float(sheet.get("stand_cooldown",0.0)),arrows]
		text(stand_status,Vector2(400,95),16)
		if not rules.pvp.is_empty():
			var team: int = int(rules.pvp.teams.get(multiplayer.get_unique_id(),-1))
			var phase := "PRÓXIMA RODADA" if rules.pvp.phase == "break" else ("ELIMINADO · AGUARDE" if rules.is_dead(multiplayer.get_unique_id()) else "EM COMBATE")
			panel(Rect2(392,102,490,62),navy,10)
			text("PVP %d/5  ·  %d x %d  ·  %.0fs  ·  EQUIPE %d" % [rules.pvp.round,rules.pvp.scores[0],rules.pvp.scores[1],ceilf(rules.pvp.time),team+1],Vector2(404,126),17)
			text(phase,Vector2(404,151),15,gold)
	var a: Node = world.activities
	if world.finished:
		draw_rect(Rect2(0, 270, 1280, 155), Color(0, 0, 0, 0.45))
		text("VOCÊ FOI CALADO.", Vector2(340, 365), 57, Color("d34d50"))
		text("Renascendo...", Vector2(550, 459), 18)
		return
	if a.menu in ["pause", "map", "mode", "cutscene", "campaign_complete", "touch_layout", "elevator", "building_contact", "network"]:
		return
	if world.network != null and world.network.active():
		text("SALA %s / %d DE 12" % [world.network.code,world.network.members.size()],Vector2(440,25),15,gold)
	if world.network!=null and world.network.active() and world.network.rules.is_dead(multiplayer.get_unique_id()):
		panel(Rect2(300,285,680,150))
		text("VOCE FOI CALADO.",Vector2(400,345),40,Color("d34d50"))
		text("Renascendo em outro ponto da cidade...",Vector2(420,395),19)
		return
	if world.extra != null and world.extra.wheel:
		draw_wheel()
		return
	if world.extra != null and world.extra.emote_wheel:
		draw_emote_wheel()
		return
	if a.menu == "" and a.weapon == 6 and world.active_car == null and not world.car_transition and Input.is_action_pressed("aim"):
		draw_sniper_scope(a)
		return
	panel(Rect2(24, 24, 740 if a.ACTION_JOBS.has(a.job) or a.job == 8 else 365, 48))
	text(a.objective(), Vector2(38, 45), 15)
	var detail := ""
	if world.marker.visible:
		detail = "%d m" % int(world.subject_position().distance_to(a.destination()))
	if a.bank.inside():
		detail += "   ·   Banco Costa"
	elif a.job >= 0:
		if world.life != null and ((world.life.TASKS.has(a.job) or world.life.NEW_TASKS.has(a.job)) and not a.ACTION_JOBS.has(a.job) or (a.job in [24,25,26] and a.stage < 3)):
			detail += "   ·   %dº andar" % (roundi(world.life.mission_position().y / 6.0) + 1)
		detail += "   ·   " + a.JOBS[a.job]
	text(detail, Vector2(38, 63), 11, muted)
	panel(Rect2(1070, 24, 186, 45))
	text("$ %d" % world.cash, Vector2(1086, 53), 23, gold)
	var wanted: float = world.network.rules.wanted_heat(multiplayer.get_unique_id()) if world.network != null and world.network.active() else world.heat
	if wanted > 0:
		for i in 5:
			star(Vector2(1136 + i * 24, 87), gold if wanted > i * 20 else Color("42535c"))
		bar(Vector2(1126, 104), 125, wanted / 100, gold)
	minimap(Vector2(24, 210 if OS.has_feature("android") else 520), Vector2(164, 164))
	bar(Vector2(24, 385 if OS.has_feature("android") else 692), 164, world.health / 100, Color("8ddbb5"))
	if world.active_car != null:
		if not OS.has_feature("android") and not world.bus_passenger and world.active_car.can_right_vehicle():
			center_note("V · Desvirar carro", 560, gold)
		text("%03d" % roundi(absf(world.active_car.speed) * 3.6), Vector2(1120, 659), 36)
		text("km/h", Vector2(1200, 657), 13, muted)
		text(world.active_car.model_name, Vector2(1120, 684), 14, muted)
		text("Combustível %d%%" % roundi(world.active_car.fuel * 100.0), Vector2(1105, 706), 14, Color("ef9b70") if world.active_car.fuel <= 0.1 else muted)
		if world.active_car.fuel <= 0.1:
			text("Abasteça!", Vector2(1154, 626), 15, Color("ff846e"))
		if world.active_car.tier == a.Catalog.SUPERCAR:
			var mode := "FLUTUANTE" if world.active_car.hovering else "ESTRADA"
			text(("%s · %s" % ["USAR" if OS.has_feature("android") else "F", mode]), Vector2(1105, 623), 14, gold)
		if world.active_car.tier == a.Catalog.BUS and world.network.active():
			var bus_id: int = world.active_car.net_id
			var occupants := int(world.network.owners.has(bus_id))
			for member in world.network.members.values():
				if int(member.get("bus", -1)) == bus_id:
					occupants += 1
			text("%d / %d ocupantes" % [occupants, a.Catalog.BUS_CAPACITY], Vector2(1105, 623), 14, gold)
	elif a.weapon > 0:
		text("%d / %d" % [a.clips[a.weapon], a.reserves[a.weapon]], Vector2(1130, 662), 25)
		text(a.WEAPON_NAMES[a.weapon], Vector2(1132, 684), 13, muted)
		if a.reload_time > 0:
			text("Recarregando…", Vector2(1094, 626), 14, gold)
		if a.menu == "" and not get_tree().paused and not world.finished and (Input.is_action_pressed("aim") or Input.is_action_pressed("shoot")):
			var color := gold if a.hit_flash > 0 else Color(1, 1, 1, 0.7)
			for offset in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				draw_line(Vector2(640, 360) + offset * 4, Vector2(640, 360) + offset * 9, color, 1.4)
	var prompt: String = a.prompt()
	if prompt != "":
		center_note(prompt, 205 if OS.has_feature("android") else 611, gold)
	if world.toast_time > 0:
		center_note(world.toast, 652, ink)
	if a.progress > 0:
		bar(Vector2(490, 593), 300, a.progress / (8.0 if a.job in [27,28] else 1.5), gold)
	if a.robbery_progress > 0:
		center_note("Pegando o dinheiro… mantenha F pressionado", 560, gold)
		bar(Vector2(490, 578), 300, a.robbery_progress / 5, gold)
	if a.pedestrian_robbery_progress > 0:
		center_note("Assaltando pedestre... mantenha F pressionado", 530, gold)
		bar(Vector2(490, 548), 300, a.pedestrian_robbery_progress / 2, gold)
	if world.bust_progress > 0:
		center_note("Fuja! A polícia está prendendo você", 170, Color("ff8b7c"))
		bar(Vector2(490, 191), 300, world.bust_progress / 9, Color("ff8b7c"))
	if a.bank.local_hacking():
		draw_hack(a.bank)
	elif world.network!=null and world.network.active() and world.network.rules.local_mission_hacking():
		draw_mission_hack(world.network.rules)
	if a.menu != "" and a.menu != "chat":
		draw_menu(a)
	if world.finished:
		backdrop()
		panel(Rect2(375, 245, 530, 210))
		text("FIM DA LINHA", Vector2(411, 301), 30, gold)
		text("%d contratos concluídos   ·   $ %d" % [a.completed, world.cash], Vector2(413, 342), 18)
		text("Renascendo...", Vector2(413, 406), 19, gold)

func draw_sniper_scope(a: Node) -> void:
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	var viewport_size := get_viewport_rect().size
	var center := viewport_size * 0.5
	var radius := minf(viewport_size.x, viewport_size.y) * (0.36 if OS.has_feature("android") else 0.42)
	var outer_radius := viewport_size.length()
	var black := Color(0.01, 0.015, 0.018, 1.0)
	for i in 96:
		var angle := TAU * i / 96.0
		var next := TAU * (i + 1) / 96.0
		var direction := Vector2(cos(angle), sin(angle))
		var next_direction := Vector2(cos(next), sin(next))
		draw_colored_polygon(PackedVector2Array([center + direction * radius, center + direction * outer_radius, center + next_direction * outer_radius, center + next_direction * radius]), black)
	draw_arc(center, radius, 0, TAU, 96, Color("282d2b"), 8, true)
	var reticle := Color(0.04, 0.05, 0.045, 0.95)
	draw_line(center + Vector2(-radius, 0), center + Vector2(radius, 0), reticle, 1.4)
	draw_line(center + Vector2(0, -radius), center + Vector2(0, radius), reticle, 1.4)
	for mark in range(1, 6):
		var distance := radius * mark / 6.0
		for side in [-1, 1]:
			draw_line(center + Vector2(side * distance, -5), center + Vector2(side * distance, 5), reticle, 1.5)
			draw_line(center + Vector2(-5, side * distance), center + Vector2(5, side * distance), reticle, 1.5)
	draw_circle(center, 2.0, Color("de534b"))
	draw_string(font, center + Vector2(-75, radius * 0.82), "%d / %d" % [a.clips[6], a.reserves[6]], HORIZONTAL_ALIGNMENT_CENTER, 150, 18, ink)

func center_note(value: String, y: float, color: Color) -> void:
	var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 28
	panel(Rect2((1280 - width) / 2, y - 23, width, 34))
	text(value, Vector2((1280 - width) / 2 + 14, y), 14, color)


func draw_wheel() -> void:
	var a: Node = world.activities
	for i in 8:
		var angle := deg_to_rad(-90.0 + i * 45.0)
		var center := Vector2(640,360) + Vector2(cos(angle),sin(angle)) * 133
		var sector := PackedVector2Array()
		for step in 17:
			var edge := deg_to_rad(-112.5 + i * 45.0 + step * 2.8125)
			sector.append(Vector2(640,360) + Vector2(cos(edge),sin(edge)) * 205)
		for step in range(16,-1,-1):
			var edge := deg_to_rad(-112.5 + i * 45.0 + step * 2.8125)
			sector.append(Vector2(640,360) + Vector2(cos(edge),sin(edge)) * 66)
		var selected: bool = world.extra.selection == i
		draw_colored_polygon(sector, Color("765526") if selected else Color(0.03, 0.07, 0.1, 0.92))
		var owned: bool = a.owns_weapon(i)
		var color := ink if owned else muted
		var icon := PackedVector2Array()
		for point: Vector2 in WEAPON_ICONS[i]:
			icon.append(center + point - Vector2(32, 26))
		draw_colored_polygon(icon, color)
		if i > 0:
			var ammo := "%d / %d" % [a.clips[i], a.reserves[i]]
			if not owned:
				ammo = "Loja" if i < 5 else "Favela"
			draw_string(font, center + Vector2(-58, 27), ammo, HORIZONTAL_ALIGNMENT_CENTER, 116, 16, color)
	var selected_name: String = a.WEAPON_NAMES[world.extra.selection]
	draw_string(font, Vector2(565, 365), selected_name, HORIZONTAL_ALIGNMENT_CENTER, 150, 16, gold)
	var hint := "Toque numa arma para equipar" if OS.has_feature("android") else "Solte Q para equipar · mova o mouse para escolher"
	draw_string(font, Vector2(360, 600), hint, HORIZONTAL_ALIGNMENT_CENTER, 560, 17, gold)

func draw_emote_wheel() -> void:
	var names := ["CUMPRIMENTAR", "GRIDDY", "TAKE THE L", "DANÇA", "GOLDEN WIND"]
	for i in names.size():
		var angle := deg_to_rad(-90.0 + i * 72.0)
		var center := Vector2(640,360) + Vector2(cos(angle),sin(angle)) * 133
		var sector := PackedVector2Array()
		for step in 17:
			var edge := deg_to_rad(-126.0 + i * 72.0 + step * 4.5)
			sector.append(Vector2(640,360) + Vector2(cos(edge),sin(edge)) * 205)
		for step in range(16,-1,-1):
			var edge := deg_to_rad(-126.0 + i * 72.0 + step * 4.5)
			sector.append(Vector2(640,360) + Vector2(cos(edge),sin(edge)) * 66)
		draw_colored_polygon(sector, Color("765526") if world.extra.emote_selection == i else Color(0.03, 0.07, 0.1, 0.92))
		draw_string(font, center + Vector2(-62, 5), names[i], HORIZONTAL_ALIGNMENT_CENTER, 124, 15, ink)
	draw_circle(Vector2(640,360), 55, Color("203e4b"))
	draw_string(font, Vector2(580, 355), "EMOTE", HORIZONTAL_ALIGNMENT_CENTER, 120, 15, gold)
	var hint := "Toque num emote para usar · toque fora para cancelar" if OS.has_feature("android") else "Solte B ou clique para usar · Esc / botao direito cancela"
	draw_string(font, Vector2(360, 600), hint, HORIZONTAL_ALIGNMENT_CENTER, 560, 17, gold)

func backdrop() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.015, 0.04, 0.06, 0.9))

func draw_hack(bank: Node3D) -> void:
	panel(Rect2(350, 185, 580, 335), Color(0.025, 0.075, 0.10, 0.97))
	text("BANCO COSTA / CONEXÃO SEGURA", Vector2(380, 227), 21, gold)
	text("Circuito %d / 3     ·     Falhas %d / 3" % [bank.round_index + 1, bank.mistakes], Vector2(380, 259), 15, muted)
	text("Memorize a sequência…" if bank.reveal_time > 0 else ("Repita usando o teclado na tela" if OS.has_feature("android") else "Repita usando as teclas 1 a 4 · ESC cancela"), Vector2(380, 300), 19)
	for i in bank.pattern.size():
		panel(Rect2(385 + i * 99, 327, 82, 70), Color("203e4b"))
		var value := str(bank.pattern[i]) if bank.reveal_time > 0 else ("✓" if i < bank.entered else "?")
		text(value, Vector2(414 + i * 99, 374), 32, gold if i < bank.entered else ink)
	bar(Vector2(380, 426), 520, bank.round_time / 14, Color("8ddbb5"))
	text("%ds   ·   3 circuitos liberam o painel do cofre" % ceili(bank.round_time), Vector2(380, 457), 14, muted)
	if OS.has_feature("android"):
		draw_hack_keys(bank.reveal_time <= 0)

func draw_mission_hack(rules: Node) -> void:
	panel(Rect2(350,185,580,335),Color(0.025,0.075,0.10,0.97))
	text("TORRE COSTA / SERVIDOR PRINCIPAL",Vector2(380,227),21,gold)
	text("Circuito %d / 3     ·     Falhas %d / 3" % [rules.mission_round+1,rules.mission_mistakes],Vector2(380,259),15,muted)
	text("Memorize..." if rules.mission_reveal_time>0 else "Repita usando o teclado na tela",Vector2(380,300),19)
	for i in rules.mission_pattern.size():
		panel(Rect2(385+i*99,327,82,70),Color("203e4b"))
		var value:=str(rules.mission_pattern[i]) if rules.mission_reveal_time>0 else ("✓" if i<rules.mission_entered else "?")
		text(value,Vector2(414+i*99,374),32,gold if i<rules.mission_entered else ink)
	bar(Vector2(380,426),520,rules.mission_round_time/14.0,Color("8ddbb5"))
	text("Terminal criptografado · agache para evitar a patrulha",Vector2(380,457),14,muted)
	draw_hack_keys(rules.mission_reveal_time <= 0)

func draw_hack_keys(ready: bool) -> void:
	if ready:
		for index in 4:
			draw_choice(hack_key_rect(index), str(index + 1), 23)
	draw_choice(HACK_CLOSE, "Cancelar")

func draw_menu(a: Node) -> void:
	backdrop()
	if a.menu == "credits":
		text("CRÉDITOS DOS ASSETS", Vector2(270, 150), 27, gold)
		var lines := ["Car Concept · Eric Chadwick / Darmstadt Graphics Group GmbH, 2024", "Esqueleto e caminhada: Cesium Man · Cesium, 2017", "Modelos de origem: CC BY 4.0 · creativecommons.org/licenses/by/4.0/", "Fonte: github.com/KhronosGroup/glTF-Sample-Assets", "A malha humana do Costa Livre foi criada sobre o esqueleto adaptado.", "", "Texturas e céu HDR: Poly Haven · CC0 · polyhaven.com", "Asphalt 02 · Concrete Wall 006 · Kloppenheim 06 Pure Sky", "", "C / ESC · voltar"]
		for i in lines.size():
			text(lines[i], Vector2(270, 201 + i * 32), 16, gold if i == 9 else ink)
		draw_choice(MENU_CLOSE, "Voltar")
		return
	panel(Rect2(330, 115, 620, 545))
	var title: String = {"jobs": "CONTRATOS", "guns": "ARSENAL", "heavy_guns": "ARSENAL DA FAVELA", "cars": "APEX MOTORS", "garage": "OFICINA", "garage_cars": "VEICULOS / OFICINA", "owned_cars": "MEUS VEICULOS"}.get(a.menu, "")
	text(title, Vector2(365, 166), 30, gold)
	text("$ %d" % world.cash, Vector2(805, 165), 21, gold)
	text("Toque em uma opção" if OS.has_feature("android") else "Clique em uma opção", Vector2(366, 192), 15, muted)
	var rows: Array = []
	if a.menu == "jobs":
		for i in range(a.job_page * 7, mini(a.job_count(), a.job_page * 7 + 7)):
			var index: int = a.job_id_at(i)
			rows.append("%s   ·   $%d" % [a.JOBS[index], a.REWARDS[index]])
	elif a.menu == "garage":
		rows = ["Reparo e cura   ·   $250", "Pintura / 10 cores   ·   $300", "Melhorar motor   ·   $500", "Aumentar suspensao   /   $800", "Comprar veiculo"]
	elif a.menu == "owned_cars":
		for index in range(a.car_page*3,mini(a.purchased_cars.size(),a.car_page*3+3)):
			rows.append("%s / RETIRAR" % a.Catalog.NAMES[int(a.purchased_cars[index].tier)])
		if rows.is_empty(): rows.append("Compre um veiculo na APEX ou na oficina")
	elif a.menu == "heavy_guns":
		rows = ["Bazuca + 4 foguetes · $6500", "Sniper + 15 munições · $5000", "Canhão de pulso + 60 cargas · $25000", "Munição pesada · $1200"]
	elif a.menu == "guns":
		rows = ["Pistola + 48 munições   ·   $400", "Fuzil + 90 munições   ·   $1800", "Escopeta + 32 cartuchos   ·   $2400", "SMG + 96 munições   ·   $2100", "Munição para suas armas   ·   $150"]
	else:
		for index in range(a.car_page*3,mini(a.CAR_PRICES.size(),a.car_page*3+3)):
			rows.append("%s   /   %d km/h   /   $%d" % [a.Catalog.NAMES[index+1],roundi(a.Catalog.SPEEDS[index+1]*3.6),a.CAR_PRICES[index]])
	for i in rows.size():
		draw_choice(choice_rect(i), rows[i], 20 if OS.has_feature("android") else 17)
	if a.menu in PAGE_MENUS:
		draw_choice(MENU_PREVIOUS, "‹  Anterior", 17)
		draw_choice(MENU_NEXT, "Próxima  ›", 17)
		var page: int = a.job_page if a.menu == "jobs" else a.car_page
		text("%d / %d" % [page + 1, a.menu_page_count()], Vector2(660, 624), 17, muted)
	if world.toast_time > 0 and (world.toast.begins_with("Dinheiro") or world.toast.begins_with("Libere")):
		text(world.toast, Vector2(366, 575), 14, gold)
	draw_choice(MENU_CLOSE, "Voltar")

func star(center: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 10:
		var angle := -PI / 2 + i * PI / 5
		points.append(center + Vector2(cos(angle), sin(angle)) * (8 if i % 2 == 0 else 3.5))
	draw_colored_polygon(points, color)

func minimap(origin: Vector2, map_size: Vector2, full := false) -> void:
	panel(Rect2(origin - Vector2(4, 4), map_size + Vector2(8, 8)))
	draw_rect(Rect2(origin, map_size), Color("33474e"))
	var subject: Vector3 = world.subject_position()
	var left := clampf(subject.x - 186.0, -186.0, world.MAP_EAST - 372.0)
	var pos := map_point(subject, origin, map_size, left)
	if left <= -168.0:
		var coast := map_point(Vector3(-168,0,0), origin, map_size, left).x
		draw_rect(Rect2(origin, Vector2(coast - origin.x, map_size.y)), Color("488592"))
	var favela_x: float = world.activities.FAVELA_CENTER_X
	for center in [378.0, 714.0, favela_x]:
		if center + 84 < left or center - 84 > left + 372: continue
		var corner := map_point(Vector3(center - 84,0,-35), origin, map_size, left)
		var other := map_point(Vector3(center + 84,0,35), origin, map_size, left)
		draw_rect(Rect2(corner, other - corner), Color("607d5f"))
	for x in range(-147, 904, 42):
		if x < left - 12 or x > left + 384: continue
		for z in range(-105, 106, 42):
			if absi(z) < 35 and (absf(x - 378) < 84 or absf(x - 714) < 84): continue
			if z in [-105, -63] and x in [273, 315, 777, 819]: continue
			var corner := map_point(Vector3(x - 12, 0, z - 11), origin, map_size, left)
			var other := map_point(Vector3(x + 12, 0, z + 11), origin, map_size, left)
			draw_rect(Rect2(corner, other - corner), Color("66766f"))
	for road in range(-126, 883, 42):
		if road < left or road > left + 372: continue
		var px := map_point(Vector3(road, 0, 0), origin, map_size, left).x
		if (road > 294 and road < 462) or (road > 630 and road < 798):
			var upper := map_point(Vector3(road,0,-35), origin, map_size, left).y
			var lower := map_point(Vector3(road,0,35), origin, map_size, left).y
			draw_line(Vector2(px, origin.y), Vector2(px, upper), Color("728081"), 3)
			draw_line(Vector2(px, lower), Vector2(px, origin.y + map_size.y), Color("728081"), 3)
		else:
			draw_line(Vector2(px, origin.y), Vector2(px, origin.y + map_size.y), Color("728081"), 3)
	for x in [-168, 924]:
		if x < left or x > left + 372: continue
		var px := map_point(Vector3(x, 0, 0), origin, map_size, left).x
		draw_line(Vector2(px, origin.y), Vector2(px, origin.y + map_size.y), Color("728081"), 3)
	for road in range(-126, 127, 42):
		var py := map_point(Vector3(0, 0, road), origin, map_size, left).y
		var road_end: float = world.MAP_EAST if road == 0 else 938.0
		if left < road_end:
			var end_x := map_point(Vector3(road_end, 0, road), origin, map_size, left).x
			draw_line(Vector2(origin.x, py), Vector2(end_x, py), Color("728081"), 3)
	for center in [294.0, 798.0]:
		if center + 36 < left or center - 36 > left + 372: continue
		var corner := map_point(Vector3(center - 36,0,-117), origin, map_size, left)
		var other := map_point(Vector3(center + 36,0,-83), origin, map_size, left)
		draw_rect(Rect2(corner, other - corner), Color("aa997a"))
	if left < favela_x + 29.0 and left + 372 > favela_x - 24.0:
		for offset in [-27.0, -17.0, -7.0, 3.0, 13.0, 23.0, 33.0]:
			var x: float = favela_x + offset
			for z in [-34.0, -23.0, -11.0, 11.0, 23.0, 34.0]:
				var corner := map_point(Vector3(x - 3,0,z - 2), origin, map_size, left)
				var other := map_point(Vector3(x + 3,0,z + 2), origin, map_size, left)
				draw_rect(Rect2(corner, other - corner), Color("c78f72"))
	var a: Node = world.activities
	var prison_stage: int = world.prison_stage_for()
	if prison_stage >= 0 and prison_stage < world.PRISON_POINTS.size():
		var target: Vector3 = world.PRISON_POINTS[prison_stage]
		draw_circle(map_point(target, origin, map_size, left), 5, gold)
	if a.supply_stage in [1, 2, 3] and (world.network == null or not world.network.active() or a.supply_owner == multiplayer.get_unique_id()):
		var delivery_target: Vector2 = map_point(a.SUPPLY_ALLEY, origin, map_size, left)
		draw_line(pos, delivery_target, Color(1, 0.8, 0.4, 0.6), 1)
		draw_circle(delivery_target, 5, gold)
	if world.marker.visible:
		var target := map_point(a.destination(), origin, map_size, left)
		draw_line(pos, target, Color(1, 0.8, 0.4, 0.6), 1)
		draw_circle(target, 5, gold)
	for entry in [[a.GUN_SHOP, "A"], [a.DEALER, "C"], [a.GARAGE, "+"], [Vector3(1035, 0, 55), "P"]]:
		if entry[0].x < left or entry[0].x > left + 372: continue
		var p := map_point(entry[0], origin, map_size, left)
		if full:
			text(entry[1], p + Vector2(-4, 4), 16, Color("9ed8ff"))
		else:
			draw_circle(p, 2.5, Color("9ed8ff"))
	if world.life != null:
		for point in world.life.PLACES:
			if point.x >= left and point.x <= left + 372:
				draw_circle(map_point(point+Vector3(0,0,14), origin, map_size, left),3,Color("9fd4b5"))
	for ix in range(8, 18):
		var x := -147.0 + ix * 42
		if x < left or x > left + 372: continue
		var z := -105.0 if ix == 12 else 105.0
		draw_circle(map_point(Vector3(x,0,z + 14), origin, map_size, left), 2, Color("9fd4b5"))
	if 861 >= left and 861 <= left + 372:
		draw_circle(map_point(Vector3(861,0,-93), origin, map_size, left), 3, Color("b6d9d4"))
	for point in a.ROBBERIES:
		if point.x >= left and point.x <= left + 372:
			text("$", map_point(point, origin, map_size, left) + Vector2(-3, 3), 12, Color("fda487"))
	for cop in world.cops:
		if cop.hp > 0 and world.heat > 0 and cop.position.x >= left and cop.position.x <= left + 372:
			draw_circle(map_point(cop.position, origin, map_size, left), 3, Color("ed8277"))
	for station_at: Vector3 in world.FUEL_STATIONS:
		var pump := map_point(station_at, origin, map_size, left)
		if pump.x >= origin.x and pump.x <= origin.x + map_size.x:
			draw_circle(pump, 4, Color("f0c56d"))
			draw_circle(pump, 2, Color("53636a"))
	var angle: float = world.active_car.heading if world.active_car != null else world.player.model.rotation.y
	var points := PackedVector2Array()
	for offset in [Vector2(0, -6), Vector2(4, 5), Vector2(0, 3), Vector2(-4, 5)]:
		points.append(pos + offset.rotated(-angle))
	draw_colored_polygon(points, ink)
	points.append(points[0])
	draw_polyline(points,Color("10252e"),1.5,true)

func map_point(pos: Vector3, origin: Vector2, map_size: Vector2, left := INF) -> Vector2:
	if not is_finite(left):
		left = clampf(world.subject_position().x - 186.0, -186.0, world.MAP_EAST - 372.0)
	return origin + Vector2(clampf((pos.x - left) / 372.0, 0.02, 0.98), clampf((pos.z + 144) / 288.0, 0.02, 0.98)) * map_size

