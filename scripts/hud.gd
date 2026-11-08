extends Control

var world: Node3D
var font: Font
var ink := Color("edf1ed")
var muted := Color("a7b9bf")
var gold := Color("ffd18a")
var navy := Color(0.035, 0.085, 0.12, 0.82)
var panel_styles := {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = ThemeDB.fallback_font

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
	var a: Node = world.activities
	if world.finished:
		draw_rect(Rect2(0, 270, 1280, 155), Color(0, 0, 0, 0.45))
		text("VOCÊ FOI CALADO.", Vector2(340, 365), 57, Color("d34d50"))
		text("ENTER · recomeçar", Vector2(550, 459), 18)
		return
	if world.extra != null and world.extra.wheel:
		draw_wheel()
	if a.menu in ["pause", "map", "mode", "cutscene", "campaign_complete", "touch_layout", "elevator", "network"]:
		return
	if world.network != null and world.network.active():
		text("SALA %s / %d DE 12" % [world.network.code,world.network.members.size()],Vector2(440,25),15,gold)
	if world.network!=null and world.network.active() and world.network.rules.is_dead(multiplayer.get_unique_id()):
		panel(Rect2(300,285,680,150))
		text("VOCE FOI CALADO.",Vector2(400,345),40,Color("d34d50"))
		text("Renascendo em outro ponto da cidade...",Vector2(420,395),19)
		return
	panel(Rect2(24, 24, 365, 48))
	text(a.objective(), Vector2(38, 45), 15)
	var detail := ""
	if world.marker.visible:
		detail = "%d m" % int(world.subject_position().distance_to(a.destination()))
	if a.bank.inside():
		detail += "   ·   Banco Costa"
	elif a.job >= 0:
		if world.life != null and (world.life.TASKS.has(a.job) or world.life.NEW_TASKS.has(a.job) or (a.job >= 24 and a.stage < 3)):
			detail += "   ·   %dº andar" % (roundi(world.life.mission_position().y / 6.0) + 1)
		detail += "   ·   " + a.JOBS[a.job]
	text(detail, Vector2(38, 63), 11, muted)
	panel(Rect2(1070, 24, 186, 45))
	text("$ %d" % world.cash, Vector2(1086, 53), 23, gold)
	if world.heat > 0:
		for i in 5:
			star(Vector2(1136 + i * 24, 87), gold if world.heat > i * 20 else Color("42535c"))
		bar(Vector2(1126, 104), 125, world.heat / 100, gold)
	minimap(Vector2(24, 210 if OS.has_feature("android") else 520), Vector2(164, 164))
	bar(Vector2(24, 385 if OS.has_feature("android") else 692), 164, world.health / 100, Color("8ddbb5"))
	if world.active_car != null:
		text("%03d" % int(absf(world.active_car.speed) * 3.6), Vector2(1120, 659), 36)
		text("km/h", Vector2(1200, 657), 13, muted)
		text(world.active_car.model_name, Vector2(1120, 684), 14, muted)
	elif a.weapon > 0:
		text("%d / %d" % [a.clips[a.weapon], a.reserves[a.weapon]], Vector2(1130, 662), 25)
		text(["", "Pistola", "Fuzil", "Escopeta", "SMG"][a.weapon], Vector2(1132, 684), 13, muted)
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
		bar(Vector2(490, 593), 300, a.progress / 1.5, gold)
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
	if a.menu != "":
		draw_menu(a)
	if world.finished:
		backdrop()
		panel(Rect2(375, 245, 530, 210))
		text("FIM DA LINHA", Vector2(411, 301), 30, gold)
		text("%d contratos concluídos   ·   $ %d" % [a.completed, world.cash], Vector2(413, 342), 18)
		text("ENTER · recomeçar", Vector2(413, 406), 19, gold)

func center_note(value: String, y: float, color: Color) -> void:
	var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 28
	panel(Rect2((1280 - width) / 2, y - 23, width, 34))
	text(value, Vector2((1280 - width) / 2 + 14, y), 14, color)


func draw_wheel() -> void:
	var a: Node = world.activities
	var labels := ["Punhos", "Pistola", "Fuzil" if a.rifle_owned else "Fuzil · loja", "Escopeta" if a.shotgun_owned else "Escopeta · loja", "SMG" if a.smg_owned else "SMG · loja"]
	var centers: Array[Vector2] = []
	for i in 5:
		var angle := deg_to_rad(-90.0 + i * 72.0)
		centers.append(Vector2(640,360) + Vector2(cos(angle),sin(angle)) * 133)
		var sector := PackedVector2Array()
		for step in 17:
			var edge := deg_to_rad(-126.0 + i * 72.0 + step * 4.5)
			sector.append(Vector2(640,360) + Vector2(cos(edge),sin(edge)) * 205)
		for step in range(16,-1,-1):
			var edge := deg_to_rad(-126.0 + i * 72.0 + step * 4.5)
			sector.append(Vector2(640,360) + Vector2(cos(edge),sin(edge)) * 66)
		draw_colored_polygon(sector, Color("bb9458") if world.extra.selection == i else Color(0.03, 0.07, 0.1, 0.92))
		text(labels[i], centers[i] + Vector2(-55, 5), 16)
	text("Solte Q para equipar · mova o mouse para escolher", Vector2(422, 600), 17, gold)

func backdrop() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.015, 0.04, 0.06, 0.9))

func draw_hack(bank: Node3D) -> void:
	panel(Rect2(350, 185, 580, 335), Color(0.025, 0.075, 0.10, 0.97))
	text("BANCO COSTA / CONEXÃO SEGURA", Vector2(380, 227), 21, gold)
	text("Circuito %d / 3     ·     Falhas %d / 3" % [bank.round_index + 1, bank.mistakes], Vector2(380, 259), 15, muted)
	text("Memorize a sequência…" if bank.reveal_time > 0 else "Repita usando as teclas 1, 2, 3 e 4", Vector2(380, 300), 19)
	for i in bank.pattern.size():
		panel(Rect2(385 + i * 99, 327, 82, 70), Color("203e4b"))
		var value := str(bank.pattern[i]) if bank.reveal_time > 0 else ("✓" if i < bank.entered else "?")
		text(value, Vector2(414 + i * 99, 374), 32, gold if i < bank.entered else ink)
	bar(Vector2(380, 426), 520, bank.round_time / 14, Color("8ddbb5"))
	text("%ds   ·   3 circuitos liberam o painel do cofre" % ceili(bank.round_time), Vector2(380, 457), 14, muted)
	text("ESC · cancelar hack", Vector2(380, 492), 14, gold)

func draw_mission_hack(rules: Node) -> void:
	panel(Rect2(350,185,580,335),Color(0.025,0.075,0.10,0.97))
	text("TORRE COSTA / SERVIDOR PRINCIPAL",Vector2(380,227),21,gold)
	text("Circuito %d / 3     ·     Falhas %d / 3" % [rules.mission_round+1,rules.mission_mistakes],Vector2(380,259),15,muted)
	text("Memorize..." if rules.mission_reveal_time>0 else "Repita usando 1, 2, 3 e 4",Vector2(380,300),19)
	for i in rules.mission_pattern.size():
		panel(Rect2(385+i*99,327,82,70),Color("203e4b"))
		var value:=str(rules.mission_pattern[i]) if rules.mission_reveal_time>0 else ("✓" if i<rules.mission_entered else "?")
		text(value,Vector2(414+i*99,374),32,gold if i<rules.mission_entered else ink)
	bar(Vector2(380,426),520,rules.mission_round_time/14.0,Color("8ddbb5"))
	text("Terminal criptografado · agache para evitar a patrulha",Vector2(380,457),14,muted)
	text("ESC · abandonar hack",Vector2(380,492),14,gold)

func draw_menu(a: Node) -> void:
	backdrop()
	if a.menu == "credits":
		text("CRÉDITOS DOS ASSETS", Vector2(270, 150), 27, gold)
		var lines := ["Car Concept · Eric Chadwick / Darmstadt Graphics Group GmbH, 2024", "Cesium Man · Cesium, 2017", "Modelos: CC BY 4.0 · creativecommons.org/licenses/by/4.0/", "Fonte: github.com/KhronosGroup/glTF-Sample-Assets", "Adaptados: escala, materiais, pintura, malhas agrupadas e animação.", "", "Texturas e céu HDR: Poly Haven · CC0 · polyhaven.com", "Asphalt 02 · Concrete Wall 006 · Kloppenheim 06 Pure Sky", "", "C / ESC · voltar"]
		for i in lines.size():
			text(lines[i], Vector2(270, 201 + i * 32), 16, gold if i == 9 else ink)
		return
	panel(Rect2(330, 115, 620, 490))
	var title: String = {"jobs": "CONTRATOS", "guns": "ARSENAL", "cars": "APEX MOTORS", "garage": "OFICINA"}.get(a.menu, "")
	text(title, Vector2(365, 166), 30, gold)
	text("$ %d" % world.cash, Vector2(805, 165), 21, gold)
	text("Escolha pelo número   ·   ESC para fechar", Vector2(366, 199), 14, muted)
	var rows: Array = []
	if a.menu == "jobs":
		for i in range(a.job_page * 7, mini(a.job_count(), a.job_page * 7 + 7)):
			rows.append("%s   ·   $%d" % [a.JOBS[i], a.REWARDS[i]])
	elif a.menu == "garage":
		rows = ["Reparo e cura   ·   $250", "Trocar pintura   ·   $300", "Melhorar motor   ·   $500"]
	elif a.menu == "guns":
		rows = ["Pistola + 48 munições   ·   $400", "Fuzil + 90 munições   ·   $1800", "Escopeta + 32 cartuchos   ·   $2400", "SMG + 96 munições   ·   $2100", "Munição para suas armas   ·   $150"]
	else:
		for index in range(a.car_page*3,mini(a.CAR_PRICES.size(),a.car_page*3+3)):
			rows.append("%s   /   %d km/h   /   $%d" % [a.Catalog.NAMES[index+1],int(a.Catalog.SPEEDS[index+1]*3.6),a.CAR_PRICES[index]])
	for i in rows.size():
		panel(Rect2(362, 218 + i * 43, 556, 36), Color("20343f"), 5)
		text(str(i + 1), Vector2(376, 243 + i * 43), 18, gold)
		text(rows[i], Vector2(410, 242 + i * 43), 16)
	if a.menu == "jobs":
		text("Página %d/%d · setas esquerda/direita para trocar · números para escolher" % [a.job_page + 1,ceili(a.job_count()/7.0)], Vector2(366, 555), 12, muted)
	elif a.menu == "cars":
		text("Pagina %d/3  /  setas: trocar  /  1-3: comprar" % (a.car_page+1),Vector2(366,555),14,muted)
	elif world.toast_time > 0 and (world.toast.begins_with("Dinheiro") or world.toast.begins_with("Libere")):
		text(world.toast, Vector2(366, 550), 12, gold)
	elif a.menu == "guns":
		text("1–5 · comprar/equipar     R · recarregar     Q · roda de armas", Vector2(366, 555), 13, muted)
	else:
		text("Carros comprados não aumentam seu nível de busca.", Vector2(366, 555), 13, muted)

func star(center: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 10:
		var angle := -PI / 2 + i * PI / 5
		points.append(center + Vector2(cos(angle), sin(angle)) * (8 if i % 2 == 0 else 3.5))
	draw_colored_polygon(points, color)

func minimap(origin: Vector2, map_size: Vector2, full := false) -> void:
	panel(Rect2(origin - Vector2(4, 4), map_size + Vector2(8, 8)))
	draw_rect(Rect2(origin, map_size), Color("33474e"))
	draw_rect(Rect2(origin, Vector2(map_size.x * 0.06, map_size.y)), Color("488592"))
	for x in range(-147, 148, 42):
		for z in range(-105, 106, 42):
			var corner := map_point(Vector3(x - 12, 0, z - 11), origin, map_size)
			var other := map_point(Vector3(x + 12, 0, z + 11), origin, map_size)
			draw_rect(Rect2(corner, other - corner), Color("66766f"))
	for x in [-168, 168]:
		var px: float = origin.x + (x + 186) / 372.0 * map_size.x
		draw_line(Vector2(px, origin.y), Vector2(px, origin.y + map_size.y), Color("728081"), 3)
	for road in range(-126, 127, 42):
		var p := (road + 144) / 288.0
		var px := (road + 186) / 372.0
		draw_line(origin + Vector2(px * map_size.x, 0), origin + Vector2(px * map_size.x, map_size.y), Color("728081"), 3)
		draw_line(origin + Vector2(0, p * map_size.y), origin + Vector2(map_size.x, p * map_size.y), Color("728081"), 3)
	var a: Node = world.activities
	if world.marker.visible:
		draw_line(map_point(world.subject_position(), origin, map_size), map_point(a.destination(), origin, map_size), Color(1, 0.8, 0.4, 0.6), 1)
		draw_circle(map_point(a.destination(), origin, map_size), 5, gold)
	for entry in [[a.GUN_SHOP, "A"], [a.DEALER, "C"], [a.GARAGE, "+"]]:
		var p := map_point(entry[0], origin, map_size)
		if full:
			text(entry[1], p + Vector2(-4, 4), 16, Color("9ed8ff"))
		else:
			draw_circle(p, 2.5, Color("9ed8ff"))
	if world.life != null:
		for point in world.life.PLACES:
			draw_circle(map_point(point+Vector3(0,0,14),origin,map_size),3,Color("9fd4b5"))
	for point in a.ROBBERIES:
		text("$", map_point(point, origin, map_size) + Vector2(-3, 3), 12, Color("fda487"))
	for cop in world.cops:
		if cop.hp > 0 and world.heat > 0:
			draw_circle(map_point(cop.position, origin, map_size), 3, Color("ed8277"))
	var pos := map_point(world.subject_position(), origin, map_size)
	var angle: float = world.active_car.heading if world.active_car != null else world.camera_yaw
	var points := PackedVector2Array()
	for offset in [Vector2(0, -6), Vector2(4, 5), Vector2(0, 3), Vector2(-4, 5)]:
		points.append(pos + offset.rotated(-angle))
	draw_colored_polygon(points, ink)

func map_point(pos: Vector3, origin: Vector2, map_size: Vector2) -> Vector2:
	return origin + Vector2(clampf((pos.x + 186) / 372.0, 0.02, 0.98), clampf((pos.z + 144) / 288.0, 0.02, 0.98)) * map_size
