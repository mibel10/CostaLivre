extends Control

var world: Node3D
var fingers := {}
var stick := Vector2.ZERO
var font: Font
var last_context := ""
var icons := {}
var positions := {}
var saved_positions := {}
var editing := false
var edit_fingers := {}
var layout_path := "user://touch_layout.cfg"
var button_scale := 1.0
var button_sizes := {}
var saved_button_sizes := {}
var selected_button := "shoot"
var saved_button_scale := 1.0
const CONTROLS := ["pause","map","shoot","aim","interact","activity","jump","sprint","jobs","weapon","reload","roll","crouch","reset","stick"]
var edit_message := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	font = ThemeDB.fallback_font
	for name in ["pause","map","shoot","aim","interact","activity","jump","sprint","jobs","weapon","reload","roll","reset","previous","next","restart"]:
		icons[name] = load("res://assets/ui/touch/"+name+".svg")
	icons["crouch"]=load("res://assets/ui/touch/crouch.svg")
	load_layout()
	get_viewport().size_changed.connect(queue_redraw)
	visible = OS.has_feature("android")
	set_process(visible)
	set_process_input(visible)

func context() -> String:
	if editing:
		return ""
	if world.finished:
		return "death"
	if world.cutscene.active:
		return "cutscene"
	if world.activities.bank.local_hacking():
		return "hack"
	if world.network!=null and world.network.active() and world.network.rules.local_mission_hacking():
		return "mission_hack"
	return world.activities.menu

func base_buttons() -> Array:
	var state := context()
	if state in ["mode", "campaign_complete", "cutscene"]:
		return []
	if state == "death":
		return [[Rect2(510,570,260,70),"RECOMEÇAR","restart"]]
	if state in ["jobs","guns","cars","garage","hack","mission_hack","credits"]:
		var rows: Array = [[Rect2(1090,630,160,65),"VOLTAR","pause"]]
		var count := 4 if state in ["hack","mission_hack"] else (7 if state == "jobs" else (5 if state == "guns" else (0 if state == "credits" else 3)))
		for i in count:
			rows.append([Rect2(40+i*140,635,125,60),str(i+1),str(i+1)])
		if state in ["jobs","cars"]:
			rows.append([Rect2(40,550,125,60),"<","previous"])
			rows.append([Rect2(1100,550,125,60),">","next"])
		return rows
	if state != "":
		return [] # Native pause/menu controls use Android touch-to-mouse input.
	return [[Rect2(1090,105,160,65),"PAUSA","pause"], [Rect2(905,105,160,65),"MAPA","map"], [Rect2(1085,530,165,85),"ATIRAR","shoot"], [Rect2(900,530,160,85),"MIRAR","aim"], [Rect2(1085,425,165,80),"ENTRAR/SAIR","interact"], [Rect2(900,425,160,80),"USAR / F","activity"], [Rect2(705,530,165,85),"PULAR/FREIO","jump"], [Rect2(705,425,165,80),"CORRER","sprint"], [Rect2(40,105,160,65),"MISSÕES","jobs"], [Rect2(220,105,160,65),"ARMA","weapon"], [Rect2(400,105,160,65),"RECARGA","reload"], [Rect2(585,105,130,65),"ROLAR","roll"], [Rect2(735,105,150,65),"AGACHAR","crouch"], [Rect2(40,180,130,55),"RESGATE","reset"]]

func action(name: String, pressed: bool) -> void:
	if name == "weapon":
		if pressed:
			var a: Node = world.activities
			var available := [0, 1]
			if a.rifle_owned:
				available.append(2)
			if a.shotgun_owned:
				available.append(3)
			if a.smg_owned:
				available.append(4)
			a.weapon = available[(available.find(a.weapon) + 1) % available.size()]
		return
	if name == "roll":
		if pressed:
			world.player.start_roll()
		return
	if name.is_valid_int() or name in ["previous","next"]:
		var key := InputEventKey.new()
		key.physical_keycode = KEY_LEFT if name == "previous" else (KEY_RIGHT if name == "next" else KEY_1+name.to_int()-1)
		key.pressed = pressed
		Input.parse_input_event(key)
		return
	var event := InputEventAction.new()
	event.action = name
	event.pressed = pressed
	if pressed:
		Input.action_press(name)
	else:
		Input.action_release(name)
	world._unhandled_input(event)

func _input(event: InputEvent) -> void:
	if editing:
		edit_input(event)
		return
	if event is InputEventScreenTouch:
		var point := screen_point(event.position)
		if not event.pressed:
			release_finger(event.index)
			return
		if context() == "cutscene":
			world.cutscene.finish()
			get_viewport().set_input_as_handled()
			return
		for entry in buttons():
			if point.distance_to(entry[0].get_center()) <= entry[0].size.x/2:
				if not fingers.values().has(entry[2]):
					fingers[event.index] = entry[2]
					action(entry[2],true)
					queue_redraw()
				get_viewport().set_input_as_handled()
				return
		if context() == "":
			var name := "stick" if point.distance_to(stick_center()) < 120 else "look"
			if fingers.values().has(name):
				get_viewport().set_input_as_handled()
				return
			fingers[event.index] = name
			if fingers[event.index] == "stick":
				move_stick(point)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and fingers.has(event.index):
		if fingers[event.index] == "stick":
			move_stick(screen_point(event.position))
		elif fingers[event.index] == "look":
			world.camera_yaw -= event.relative.x / ui_scale() * 0.005
			world.camera_pitch = clampf(world.camera_pitch+event.relative.y/ui_scale()*0.004,-0.45,1.35)
			world.mouse_idle = 0
		get_viewport().set_input_as_handled()

func move_stick(point: Vector2) -> void:
	stick = ((point-stick_center())/100).limit_length()
	queue_redraw()
	for entry in [["left",-stick.x],["right",stick.x],["forward",-stick.y],["back",stick.y]]:
		if entry[1] > 0.15:
			Input.action_press(entry[0],entry[1])
		else:
			Input.action_release(entry[0])

func release_finger(index: int) -> void:
	if not fingers.has(index):
		return
	var name: String = fingers[index]
	fingers.erase(index)
	queue_redraw()
	if name == "stick":
		stick = Vector2.ZERO
		for movement in ["left","right","forward","back"]:
			Input.action_release(movement)
	elif name != "look":
		action(name,false)

func release_all() -> void:
	for index in fingers.keys():
		release_finger(index)
	edit_fingers.clear()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		release_all()

func _process(_delta: float) -> void:
	var state := context()
	if state != last_context:
		release_all()
		last_context = state
		queue_redraw()

func ui_scale() -> float:
	return minf(get_viewport_rect().size.x/1280,get_viewport_rect().size.y/720)

func ui_offset() -> Vector2:
	return (get_viewport_rect().size-Vector2(1280,720)*ui_scale())/2

func screen_point(point: Vector2) -> Vector2:
	return (point-ui_offset())/ui_scale()

func control_radius(name: String) -> float:
	return 105.0 if name == "stick" else (48.0 if name == "shoot" else (30.0 if name in ["pause","map","jobs","reset"] else 40.0))*float(button_sizes.get(name, button_scale))

func stick_center() -> Vector2:
	return positions.get("stick",Vector2(180,540)/Vector2(1280,720))*Vector2(1280,720)

func buttons() -> Array:
	var rows := base_buttons()
	for entry in rows:
		var at: Vector2 = entry[0].get_center()
		var r: float = minf(entry[0].size.x,entry[0].size.y)/2
		if context() == "":
			r = control_radius(entry[2])
			at = positions.get(entry[2],at/Vector2(1280,720))*Vector2(1280,720)
		entry[0] = Rect2(at-Vector2.ONE*r,Vector2.ONE*r*2)
	return rows

func place_control(name: String, at: Vector2) -> void:
	if name not in CONTROLS or not at.is_finite():
		return
	var r := control_radius(name)+10
	positions[name] = at.clamp(Vector2(r,r+75),Vector2(1280-r,720-r))/Vector2(1280,720)

func load_layout() -> void:
	positions.clear()
	var config := ConfigFile.new()
	if config.load(layout_path) != OK:
		return
	button_scale = clampf(config.get_value("size", "scale", 1.0), 0.65, 1.5)
	for name in CONTROLS:
		button_sizes[name] = clampf(config.get_value("sizes",name,button_scale),0.65,1.5)
	for name in CONTROLS:
		if not config.has_section_key("positions",name):
			continue
		var value = config.get_value("positions",name)
		if value is Vector2 and value.is_finite():
			place_control(name,value*Vector2(1280,720))

func save_layout() -> bool:
	var config := ConfigFile.new()
	config.set_value("size", "scale", button_scale)
	for name in button_sizes:
		config.set_value("sizes",name,button_sizes[name])
	for name in positions:
		config.set_value("positions",name,positions[name])
	return config.save(layout_path) == OK

func start_edit() -> void:
	release_all()
	saved_positions = positions.duplicate(true)
	saved_button_scale = button_scale
	saved_button_sizes = button_sizes.duplicate()
	editing = true
	last_context = ""
	edit_message = ""
	world.activities.set_menu("touch_layout")
	queue_redraw()

func finish_edit(save: bool) -> void:
	edit_fingers.clear()
	if save:
		if not save_layout():
			edit_message = "Nao foi possivel salvar. Tente novamente."
			return
	else:
		positions = saved_positions.duplicate(true)
		button_scale = saved_button_scale
		button_sizes = saved_button_sizes.duplicate()
	editing = false
	world.activities.set_menu("pause")
	world.pause_menu.show_page("controls")
	queue_redraw()

func edit_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		finish_edit(false)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		var point := screen_point(event.position)
		if not event.pressed:
			edit_fingers.erase(event.index)
		elif Rect2(440,15,70,55).has_point(point):
			resize_selected(-0.1)
			queue_redraw()
		elif Rect2(530,15,70,55).has_point(point):
			resize_selected(0.1)
			queue_redraw()
		elif Rect2(650,15,170,55).has_point(point):
			finish_edit(true)
		elif Rect2(835,15,180,55).has_point(point):
			positions.clear()
			button_scale = 1.0
			button_sizes.clear()
			queue_redraw()
		elif Rect2(1030,15,180,55).has_point(point):
			finish_edit(false)
		else:
			for entry in buttons()+[[Rect2(stick_center()-Vector2(105,105),Vector2(210,210)),"Analogico","stick"]]:
				var center: Vector2 = entry[0].get_center()
				if point.distance_to(center)<=entry[0].size.x/2:
					selected_button = entry[2]
					edit_fingers[event.index] = {"name":entry[2],"offset":center-point}
					queue_redraw()
					break
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and edit_fingers.has(event.index):
		var item: Dictionary = edit_fingers[event.index]
		place_control(item.name,screen_point(event.position)+item.offset)
		queue_redraw()
		get_viewport().set_input_as_handled()

func resize_selected(amount: float) -> void:
	if selected_button == "stick":
		return
	button_sizes[selected_button] = clampf(float(button_sizes.get(selected_button,button_scale))+amount,0.65,1.5)
	for entry in buttons():
		if entry[2] == selected_button:
			place_control(selected_button,entry[0].get_center())

func _draw() -> void:
	draw_set_transform(ui_offset(),0,Vector2.ONE*ui_scale())
	if editing:
		draw_rect(Rect2(0,0,1280,720),Color(0.02,0.04,0.07,0.75))
	if context() == "":
		draw_circle(stick_center(),105,Color(0.03,0.08,0.12,0.45))
		draw_arc(stick_center(),104,0,TAU,48,Color(0.8,0.9,0.95,0.5),2,true)
		draw_circle(stick_center()+stick*75,35,Color(0.85,0.9,0.9,0.6))
	for entry in buttons():
		var at: Vector2 = entry[0].get_center()
		var r: float = entry[0].size.x/2
		var name: String = entry[2]
		draw_circle(at,r,Color(0.3,0.5,0.6,0.85) if fingers.values().has(name) else Color(0.03,0.08,0.12,0.65))
		draw_arc(at,r-1,0,TAU,32,Color("ffd18a") if editing and name == selected_button else Color(0.88,0.94,0.95,0.65),2,true)
		if name.is_valid_int():
			draw_string(font,at+Vector2(-6,7),name,HORIZONTAL_ALIGNMENT_LEFT,-1,21,Color.WHITE)
		else:
			var icon_name := "previous" if name == "pause" and context() != "" else name
			var texture: Texture2D = icons.get(icon_name)
			if texture != null:
				draw_texture_rect(texture,Rect2(at-Vector2.ONE*r*0.53,Vector2.ONE*r*1.06),false)
	if editing:
		draw_rect(Rect2(0,0,1280,85),Color(0.03,0.08,0.12,0.97))
		draw_string(font,Vector2(25,37),"Toque no botao e use A-/A+",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color.WHITE)
		draw_string(font,Vector2(25,65),edit_message if edit_message != "" else "Selecionado: " + selected_button + " | " + str(roundi(float(button_sizes.get(selected_button,button_scale))*100)) + "%",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color(0.7,0.8,0.85))
		for entry in [[Rect2(440,15,70,55),"A−"],[Rect2(530,15,70,55),"A+"],[Rect2(650,15,170,55),"SALVAR"],[Rect2(835,15,180,55),"RESTAURAR"],[Rect2(1030,15,180,55),"CANCELAR"]]:
			draw_rect(entry[0],Color(0.18,0.32,0.4))
			draw_string(font,entry[0].position+Vector2(12,35),entry[1],HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color.WHITE)

func _exit_tree() -> void:
	release_all()
