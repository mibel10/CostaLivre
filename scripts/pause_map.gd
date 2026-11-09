extends Control

var world: Node3D
var zoom := 1.0
var center := Vector2(376, 0)
var dragging := false
var font: Font
var points: Array = []
var inspect_at := Vector2.INF
var press_at := Vector2.ZERO
var inspected_label := ""
var touch_inspection := false
var tooltip := StyleBoxFlat.new()

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	font = ThemeDB.fallback_font
	tooltip.bg_color = Color(0.02,0.04,0.06,0.98)
	tooltip.border_color = Color("d9e6e5")
	tooltip.set_border_width_all(1)
	tooltip.set_corner_radius_all(4)
	mouse_exited.connect(func():
		if not touch_inspection:
			inspect_at = Vector2.INF
			queue_redraw()
	)

func factor() -> float:
	return minf(size.x/1160.0, size.y/340.0) * zoom

func project(pos: Vector3) -> Vector2:
	return size / 2 + (Vector2(pos.x, pos.z) - center) * factor()

func zoom_at(multiplier: float, anchor: Vector2) -> void:
	var before := center + (anchor - size / 2) / factor()
	zoom = clampf(zoom * multiplier, 1.0, 6.0)
	center = before - (anchor - size / 2) / factor()
	clamp_center()
	queue_redraw()

func clamp_center() -> void:
	center.x = clampf(center.x, -186, 1120)
	center.y = clampf(center.y, -144, 144)
	if zoom == 1:
		center = Vector2(376, 0)

func recenter() -> void:
	var pos: Vector3 = world.subject_position()
	center = Vector2(pos.x, pos.z)
	zoom = maxf(2, zoom)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey and handle_key(event):
		accept_event()
	elif event is InputEventScreenTouch and event.pressed:
		touch_inspection = true
		inspect_at = event.position
		queue_redraw()
		accept_event()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom_at(1.25, event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom_at(0.8, event.position)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
			if event.pressed: press_at = event.position
			elif press_at.distance_to(event.position) < 10: inspect_at = event.position
			queue_redraw()
			grab_focus()
		accept_event()
	elif event is InputEventMouseMotion:
		if dragging:
			center -= event.relative / factor()
			clamp_center()
			inspect_at = Vector2.INF
		else:
			inspect_at = event.position
			touch_inspection = OS.has_feature("android")
		queue_redraw()
		accept_event()

func handle_key(event: InputEventKey) -> bool:
	if not event.pressed:
		return false
	match event.physical_keycode:
		KEY_EQUAL, KEY_KP_ADD: zoom_at(1.25, size / 2)
		KEY_MINUS, KEY_KP_SUBTRACT: zoom_at(0.8, size / 2)
		KEY_LEFT, KEY_A: center.x -= 25 / zoom
		KEY_RIGHT, KEY_D: center.x += 25 / zoom
		KEY_UP, KEY_W: center.y -= 25 / zoom
		KEY_DOWN, KEY_S: center.y += 25 / zoom
		KEY_HOME: recenter()
		_: return false
	clamp_center()
	queue_redraw()
	return true

func dot(pos: Vector3, color: Color, label := "") -> void:
	var at := project(pos)
	draw_circle(at, 5, color)
	if label != "": points.append({"at":at,"color":color,"label":label})

func draw_inspection() -> void:
	inspected_label = ""
	var nearest: Dictionary = {}
	var distance := 22.0 if touch_inspection else 12.0
	for point in points:
		var current: float = point.at.distance_to(inspect_at)
		if current < distance:
			distance = current
			nearest = point
	if nearest.is_empty(): return
	inspected_label = str(nearest.label)
	var width := minf(size.x-16,font.get_string_size(inspected_label,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x+20)
	var at: Vector2 = nearest.at+Vector2(12,-32)
	at.x = clampf(at.x,8,size.x-width-8)
	at.y = clampf(at.y,8,size.y-36)
	var rect := Rect2(at,Vector2(width,28))
	draw_circle(nearest.at,8,nearest.color,false,2)
	draw_style_box(tooltip,rect)
	draw_string(font,at+Vector2(10,20),inspected_label,HORIZONTAL_ALIGNMENT_LEFT,width-20,16,Color.WHITE)

func _draw() -> void:
	if world == null or font == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color("1f343f"))
	points.clear()
	var start := project(Vector3(-186, 0, -145))
	var end := project(Vector3(1120, 0, 145))
	draw_rect(Rect2(start, end - start), Color("405453"))
	for center_x in [378.0, 714.0]:
		var hill_start := project(Vector3(center_x - 84, 0, -35))
		var hill_end := project(Vector3(center_x + 84, 0, 35))
		draw_rect(Rect2(hill_start, hill_end - hill_start), Color("607d5f"))
	for x in [-168, 924]:
		draw_line(project(Vector3(x,0,-144)), project(Vector3(x,0,144)), Color("929f9d"), 4 * sqrt(zoom))
	draw_rect(Rect2(project(Vector3(-190, 0, -190)), Vector2(45, 380) * factor()), Color("367184"))
	for road in range(-126, 883, 42):
		if (road > 294 and road < 462) or (road > 630 and road < 798):
			draw_line(project(Vector3(road,0,-144)), project(Vector3(road,0,-35)), Color("929f9d"), 4 * sqrt(zoom))
			draw_line(project(Vector3(road,0,35)), project(Vector3(road,0,144)), Color("929f9d"), 4 * sqrt(zoom))
		else:
			draw_line(project(Vector3(road, 0, -144)), project(Vector3(road, 0, 144)), Color("929f9d"), 4 * sqrt(zoom))

	for road in range(-126, 127, 42):
		draw_line(project(Vector3(-186, 0, road)), project(Vector3(1120 if road == 0 else 938, 0, road)), Color("929f9d"), 4 * sqrt(zoom))
	for center_x in [294.0, 798.0]:
		var store_start := project(Vector3(center_x - 36, 0, -117))
		var store_end := project(Vector3(center_x + 36, 0, -83))
		draw_rect(Rect2(store_start, store_end - store_start), Color("aa997a"))
		dot(Vector3(center_x, 0, -100), Color("ffdd99"), "Supermercado")
	dot(Vector3(378, 0, 15), Color("b7d8a7"), "Favela")
	dot(Vector3(714, 0, 0), Color("b7d8a7"), "Morro")
	var a: Node = world.activities
	if world.life != null:
		for i in world.life.PLACES.size():
			dot(world.life.PLACES[i]+Vector3(0,0,14),Color("9fd4b5"),world.life.TITLES[i])
	for ix in range(8, 18):
		var x := -147.0 + ix * 42
		var z := -105.0 if ix == 12 else 105.0
		dot(Vector3(x,0,z + 14), Color("9fd4b5"), "Predio entravel")
	dot(Vector3(861,0,-93), Color("b6d9d4"), "Apartamentos")
	dot(Vector3(1035,0,55), Color("8db8ef"), "Cadeia Costa")
	dot(a.GUN_SHOP, Color("9ed8ff"), "Arsenal")
	dot(a.DEALER, Color("c7afff"), "APEX")
	dot(a.GARAGE, Color("8ddbb5"), "Oficina")
	if world.station!=null:
		for station in world.station.STATIONS:
			dot(station.center,Color("8db8ef"),"Delegacia / %d viaturas" % int(station.count))
	dot(a.HEAVY_SHOP,Color("9ed8ff"),"Arsenal da favela")
	dot(a.SUPPLY_PICKUP,Color("ffd18a"),"Entrega no beco")
	dot(a.HILL_RESIDENT,Color("ffd18a"),"Morador / entrega de remedios")
	for pad in a.CAR_SPAWNERS:
		dot(pad[0],Color("c7afff"),"Retirada de veiculos comprados")
	for i in mini(3,a.ROBBERIES.size()):
		dot(a.ROBBERIES[i], Color("fda487"), "Banco" if i == 2 else "Mercado")
	for cop in world.cops:
		if cop.hp > 0 and world.heat > 0:
			dot(cop.position, Color("ed8277"))
	if world.marker.visible:
		dot(a.destination(), Color("ffd18a"), "Objetivo")
	var player_at := project(world.subject_position())
	var angle: float = world.active_car.heading if world.active_car != null else world.player.model.rotation.y
	var arrow := PackedVector2Array()
	for offset in [Vector2(0,-11),Vector2(8,8),Vector2(0,4),Vector2(-8,8)]:
		arrow.append(player_at+offset.rotated(-angle))
	draw_colored_polygon(arrow,Color.WHITE)
	arrow.append(arrow[0])
	draw_polyline(arrow,Color("0c202b"),2,true)
	points.append({"at":player_at,"color":Color.WHITE,"label":"Voce"})
	draw_inspection()
	draw_string(font, Vector2(16, 28), "N ↑     %.1fx" % zoom, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color.WHITE)
