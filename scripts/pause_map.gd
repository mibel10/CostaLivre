extends Control

var world: Node3D
var zoom := 1.0
var center := Vector2(376, 0)
var dragging := false
var font: Font
var label_rects: Array[Rect2] = []

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	font = ThemeDB.fallback_font

func factor() -> float:
	return minf(size.x, size.y) / 1130.0 * zoom

func project(pos: Vector3) -> Vector2:
	return size / 2 + (Vector2(pos.x, pos.z) - center) * factor()

func zoom_at(multiplier: float, anchor: Vector2) -> void:
	var before := center + (anchor - size / 2) / factor()
	zoom = clampf(zoom * multiplier, 1.0, 6.0)
	center = before - (anchor - size / 2) / factor()
	clamp_center()
	queue_redraw()

func clamp_center() -> void:
	center.x = clampf(center.x, -186, 938)
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
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom_at(1.25, event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom_at(0.8, event.position)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
			grab_focus()
		accept_event()
	elif event is InputEventMouseMotion and dragging:
		center -= event.relative / factor()
		clamp_center()
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
	if label == "":
		return
	var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 12
	for offset in [Vector2(9,-20), Vector2(9,7), Vector2(-width-9,-20), Vector2(-width-9,7)]:
		var rect := Rect2(at + offset, Vector2(width,20))
		if rect.position.x < 2 or rect.end.x > size.x-2 or rect.position.y < 2 or rect.end.y > size.y-2:
			continue
		var overlap := false
		for used in label_rects:
			if rect.grow(2).intersects(used):
				overlap = true
				break
		if not overlap:
			label_rects.append(rect)
			draw_rect(rect, Color(0.035,0.08,0.10,0.96))
			draw_rect(rect, color, false, 1)
			draw_string(font, rect.position + Vector2(6,15), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
			return

func _draw() -> void:
	if world == null or font == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color("1f343f"))
	label_rects.clear()
	var start := project(Vector3(-186, 0, -145))
	var end := project(Vector3(938, 0, 145))
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
		draw_line(project(Vector3(-186, 0, road)), project(Vector3(938, 0, road)), Color("929f9d"), 4 * sqrt(zoom))
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
		dot(Vector3(x,0,z + 14), Color("9fd4b5"))
	dot(Vector3(861,0,-93), Color("b6d9d4"), "Apartamentos")
	dot(a.GUN_SHOP, Color("9ed8ff"), "Arsenal")
	dot(a.DEALER, Color("c7afff"), "APEX")
	dot(a.GARAGE, Color("8ddbb5"), "Oficina")
	if world.station!=null:
		dot(world.station.CENTER,Color("8db8ef"),"Delegacia")
	for i in a.ROBBERIES.size():
		dot(a.ROBBERIES[i], Color("fda487"), "Banco" if i == 2 else "Mercado")
	for cop in world.cops:
		if cop.hp > 0 and world.heat > 0:
			dot(cop.position, Color("ed8277"))
	if world.marker.visible:
		dot(a.destination(), Color("ffd18a"), "Objetivo")
	dot(world.subject_position(), Color.WHITE, "Você")
	draw_string(font, Vector2(16, 28), "N ↑     %.1fx" % zoom, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color.WHITE)
