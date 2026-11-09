extends Control

var world: Node3D
var canvas: Control
var pages := {}
var page := "home"
var map_view: Control
var quality_select: OptionButton
var fps_select: OptionButton
var counter_select: OptionButton
var upscaling_select: OptionButton
var window_mode_select: OptionButton
var resolution_select: OptionButton
var window_resolutions: Array[Vector2i] = []
var status: Label
var campaign_save_button: Button
var advanced_options := {}
var clock := 0.0
var awaiting_action := ""
var key_buttons := {}
var name_edit: LineEdit
var outfit_select: OptionButton
var profile_status: Label
var menu_music: AudioStreamPlayer
const REBIND_ACTIONS := ["forward","back","left","right","jump","sprint","crouch","interact","activity","reload","jobs","map","pause","reset"]
const REBIND_LABELS := ["Frente","Ré","Esquerda","Direita","Pular","Correr / acelerar","Agachar","Entrar / sair","Interagir / assaltar","Recarregar","Missões","Mapa","Pausar","Reposicionar"]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas = Control.new()
	canvas.size = Vector2(1280, 720)
	canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(canvas)
	var shade := ColorRect.new()
	shade.color = Color("0c1b25")
	shade.size = Vector2(1280, 720)
	canvas.add_child(shade)
	var theme_resource := Theme.new()
	theme_resource.default_font_size = 19
	var style := StyleBoxFlat.new()
	style.bg_color = Color("223b49")
	style.set_corner_radius_all(6)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	for type in ["Button", "OptionButton"]:
		theme_resource.set_stylebox("normal", type, style)
		var hover: StyleBoxFlat = style.duplicate()
		hover.bg_color = Color("36586a")
		theme_resource.set_stylebox("hover", type, hover)
		theme_resource.set_stylebox("focus", type, hover)
	canvas.theme = theme_resource
	label(canvas, "COSTA LIVRE", Vector2(45, 60), 29, Color("ffd18a"))
	label(canvas, "PAUSADO", Vector2(47, 103), 14, Color("a7b9bf"))
	button(canvas, "Continuar", Rect2(45, 165, 265, 48), resume)
	button(canvas, "Mapa", Rect2(45, 225, 265, 48), func(): show_page("map"))
	button(canvas, "Gráficos e FPS", Rect2(45, 285, 265, 48), func(): show_page("graphics"))
	button(canvas, "Controles", Rect2(45, 345, 265, 48), func(): show_page("controls"))
	button(canvas, "Personagem", Rect2(45, 405, 265, 48), func(): show_page("character"))
	button(canvas, "Trocar modo de jogo", Rect2(45, 465, 265, 48), func(): show_page("mode"))
	campaign_save_button = button(canvas, "Salvar campanha", Rect2(45, 525, 265, 48), world.activities.save_campaign_now)
	button(canvas,"Multiplayer / sala",Rect2(45,585,265,44),func(): world.network.open_menu())
	label(canvas, "ESC · voltar / continuar", Vector2(46, 642), 15, Color("a7b9bf"))
	for name in ["home", "map", "graphics", "controls", "mode", "ending", "character"]:
		var control := Control.new()
		control.position = Vector2(360, 60)
		control.size = Vector2(865, 600)
		canvas.add_child(control)
		pages[name] = control
	pages.mode.position = Vector2.ZERO
	pages.mode.size = Vector2(1280,720)
	pages.ending.position = Vector2.ZERO
	pages.ending.size = Vector2(1280,720)
	var backdrop := preload("res://scripts/title_backdrop.gd").new()
	backdrop.size = Vector2(1280,720)
	pages.mode.add_child(backdrop)
	label(pages.mode,"COSTA",Vector2(64,145),76,Color("f4e8cf"))
	label(pages.mode,"LIVRE",Vector2(64,222),76,Color("ffd18a"))
	label(pages.mode,"DIRIJA. EXPLORE. DECIDA.",Vector2(70,330),16,Color("80d4c5"))
	label(pages.mode,"Sua cidade, suas regras.",Vector2(70,373),20,Color("d4ddd5"))
	label(pages.mode,"JOGAR",Vector2(692,78),15,Color("9badb1"))
	label(pages.mode,"JOGO LIVRE",Vector2(692,145),28,Color("85d5b7"))
	button(pages.mode,"JOGAR LIVRE  >",Rect2(692,193,440,55),func(): world.start_mode("sandbox"))
	label(pages.mode,"HISTORIA",Vector2(692,394),28,Color("ffd18a"))
	button(pages.mode,"CONTINUAR",Rect2(692,448,210,55),func(): world.start_mode("campaign"))
	button(pages.mode,"NOVO JOGO",Rect2(922,448,210,55),func(): start_new_campaign())
	label(pages.mode,"Salvamento automatico na campanha.",Vector2(692,524),14,Color("a7b9bf"))
	button(pages.mode,"MULTIPLAYER",Rect2(70,503,440,55),func(): world.network.open_menu())
	label(pages.mode,"COSTA LIVRE",Vector2(70,650),13,Color("9dadb5"))
	var ending_shade := ColorRect.new()
	ending_shade.color = Color("0c1b25")
	ending_shade.size = Vector2(1280,720)
	pages.ending.add_child(ending_shade)
	label(pages.ending,"CAMPANHA CONCLUÍDA",Vector2(390,190),38,Color("ffd18a"))
	label(pages.ending,"Os 24 capítulos foram concluídos. A cidade está livre.",Vector2(392,260),20)
	button(pages.ending,"CONTINUAR NO JOGO LIVRE",Rect2(392,340,440,58),func(): world.start_mode("sandbox"))
	button(pages.ending,"VOLTAR À ESCOLHA DE MODO",Rect2(392,420,440,58),show_mode_select)
	button(pages.mode,"NOME E ROUPA",Rect2(70,567,440,48),func(): show_page("character"))
	menu_music=AudioStreamPlayer.new()
	menu_music.name="MenuMusic"
	menu_music.process_mode=Node.PROCESS_MODE_ALWAYS
	menu_music.volume_db=-23.0
	menu_music.stream=make_menu_music()
	add_child(menu_music)
	menu_music.play()
	label(pages.character,"SEU PERSONAGEM",Vector2.ZERO,30,Color("ffd18a"))
	label(pages.character,"Nome exibido acima do jogador no multiplayer",Vector2(0,75),19)
	name_edit=LineEdit.new()
	name_edit.max_length=20
	name_edit.position=Vector2(0,115)
	name_edit.size=Vector2(620,50)
	pages.character.add_child(name_edit)
	label(pages.character,"Escolha sua roupa",Vector2(0,205),21)
	outfit_select=OptionButton.new()
	outfit_select.position=Vector2(0,245)
	outfit_select.size=Vector2(620,52)
	for outfit_name in world.profile.OUTFITS:
		outfit_select.add_item(outfit_name)
	pages.character.add_child(outfit_select)
	button(pages.character,"SALVAR NOME E ROUPA",Rect2(0,345,420,55),save_profile)
	button(pages.character,"VOLTAR",Rect2(440,345,180,55),func(): show_page("mode" if world.activities.menu=="mode" else "home"))
	profile_status=label(pages.character,"Suas escolhas ficam salvas neste dispositivo.",Vector2(0,440),18,Color("8ddbb5"))
	label(pages.home, "Sua próxima jogada.", Vector2(0, 45), 32)
	label(pages.home, "Mapa, opções e mudança de modo ficam aqui.", Vector2(0, 105), 18)
	button(pages.home,"Creditos",Rect2(0,345,240,48),func(): world.activities.set_menu("credits"))
	label(pages.home, "MODO ATUAL", Vector2(0, 180), 14, Color("a7b9bf"))
	label(pages.home, "HISTÓRIA" if world.game_mode == "campaign" else "JOGO LIVRE", Vector2(0, 207), 24, Color("ffd18a"))
	label(pages.home, "No modo história, o progresso fica salvo neste aparelho.", Vector2(0, 265), 17, Color("a7b9bf"))
	label(pages.map, "MAPA DA CIDADE", Vector2.ZERO, 27, Color("ffd18a"))
	map_view = preload("res://scripts/pause_map.gd").new()
	map_view.world = world
	map_view.position = Vector2(0, 58)
	map_view.size = Vector2(865, 465)
	pages.map.add_child(map_view)
	button(pages.map, "−", Rect2(0, 539, 55, 42), func(): map_view.zoom_at(0.8, map_view.size / 2))
	button(pages.map, "+", Rect2(67, 539, 55, 42), func(): map_view.zoom_at(1.25, map_view.size / 2))
	button(pages.map, "Centralizar", Rect2(138, 539, 170, 42), map_view.recenter)
	label(pages.map, "Zoom: roda / +/- | Arraste: mover | Passe o mouse ou toque nos pontos", Vector2(326, 551), 12, Color("a7b9bf"))
	label(pages.graphics, "GRÁFICOS E DESEMPENHO", Vector2.ZERO, 27, Color("ffd18a"))
	if not OS.has_feature("android"):
		label(pages.graphics, "Modo de tela", Vector2(0, 40), 17)
		window_mode_select=OptionButton.new()
		window_mode_select.position=Vector2(0,68)
		window_mode_select.size=Vector2(395,42)
		for mode in ["Tela cheia exclusiva","Tela cheia sem bordas","Modo janela"]:
			window_mode_select.add_item(mode)
		pages.graphics.add_child(window_mode_select)
		window_mode_select.item_selected.connect(func(index): world.settings.set_window_mode(index); refresh())
		label(pages.graphics, "Resolução (modo janela)", Vector2(440, 40), 17)
		resolution_select=OptionButton.new()
		resolution_select.position=Vector2(440,68)
		resolution_select.size=Vector2(395,42)
		window_resolutions=world.settings.get_window_resolutions()
		for resolution in window_resolutions:
			resolution_select.add_item("%d × %d" % [resolution.x,resolution.y])
		pages.graphics.add_child(resolution_select)
		resolution_select.item_selected.connect(func(index): world.settings.set_window_resolution(window_resolutions[index]); refresh())
		label(pages.graphics, "Tela cheia usa a resolução do monitor.", Vector2(0, 115), 14, Color("a7b9bf"))
		label(pages.graphics, "Qualidade gráfica", Vector2(0, 150), 21)
	else:
		label(pages.graphics, "Qualidade gráfica", Vector2(0, 90), 21)
	quality_select = OptionButton.new()
	quality_select.position = Vector2(0, 185 if not OS.has_feature("android") else 125)
	quality_select.size = Vector2(420, 50)
	for name in world.settings.QUALITIES:
		quality_select.add_item(name)
	quality_select.add_item("Personalizado")
	pages.graphics.add_child(quality_select)
	label(pages.graphics,"Contador de FPS",Vector2(470,150 if not OS.has_feature("android") else 90),21)
	counter_select = OptionButton.new()
	counter_select.position = Vector2(470,185 if not OS.has_feature("android") else 125)
	counter_select.size = Vector2(370,50)
	for option in ["Desligado","Superior esquerdo","Superior direito","Inferior esquerdo","Inferior direito"]:
		counter_select.add_item(option)
	pages.graphics.add_child(counter_select)
	counter_select.item_selected.connect(func(index):
		world.settings.set_fps_corner(index-1)
		refresh()
	)
	quality_select.item_selected.connect(func(index):
		world.settings.set_quality(index)
		refresh()
	)
	label(pages.graphics, "Limite de FPS", Vector2(0, 245 if not OS.has_feature("android") else 215), 21)
	fps_select = OptionButton.new()
	fps_select.position = Vector2(0, 280 if not OS.has_feature("android") else 250)
	fps_select.size = Vector2(420, 50)
	for limit in world.settings.FPS_LIMITS:
		fps_select.add_item("Sem limite" if limit == 0 else "%d FPS" % limit)
	pages.graphics.add_child(fps_select)
	fps_select.item_selected.connect(func(index):
		world.settings.set_fps_limit(world.settings.FPS_LIMITS[index])
		refresh()
	)
	var specs := [["textures","Texturas",["Original","1024 px","512 px","256 px"]],["shadows","Sombras",["Desligadas","Proximas","Medias","Distantes"]],["aa","Antialiasing",["Desligado","FXAA","MSAA 2x","MSAA 4x"]],["distance","Distancia",["Ultra","Alta","Media","Baixa","Minima"]],["details","Relevo de texturas",["Desligado","Ligado"]]]
	for i in specs.size():
		var spec: Array = specs[i]
		var x: float = 0 if i%2==0 else 440
		var y: float = (340 if not OS.has_feature("android") else 322)+(i/2)*66
		label(pages.graphics,spec[1],Vector2(x,y),16)
		var option := OptionButton.new()
		option.position=Vector2(x,y+25)
		option.size=Vector2(395,34)
		for item in spec[2]:
			option.add_item(item)
		pages.graphics.add_child(option)
		advanced_options[spec[0]]=option
		option.item_selected.connect(func(value): world.settings.set_custom(spec[0],value); refresh())
	var upscaling_y: float = 472 if not OS.has_feature("android") else 454
	label(pages.graphics, "Upscaling", Vector2(440, upscaling_y), 16)
	upscaling_select=OptionButton.new()
	upscaling_select.position=Vector2(440,upscaling_y+25)
	upscaling_select.size=Vector2(395,34)
	for mode in world.settings.UPSCALING_MODES:
		upscaling_select.add_item(mode)
	pages.graphics.add_child(upscaling_select)
	upscaling_select.item_selected.connect(func(index): world.settings.set_upscaling(index); refresh())
	for option in pages.graphics.get_children():
		if option is OptionButton:
			option.get_popup().popup_hide.connect(world.restore_pointer, CONNECT_DEFERRED)
	status = label(pages.graphics, "", Vector2(0, 552 if not OS.has_feature("android") else 530), 18, Color("ffd18a"))
	label(pages.controls, "CONTROLES", Vector2.ZERO, 27, Color("ffd18a"))
	for i in REBIND_ACTIONS.size():
		var action_name: String = REBIND_ACTIONS[i]
		label(pages.controls, REBIND_LABELS[i], Vector2(0, 76 + i * 35), 17)
		var key_button := button(pages.controls, "", Rect2(430, 68 + i * 35, 220, 34), begin_rebind.bind(action_name))
		key_buttons[action_name] = key_button
	label(pages.controls, "Clique numa ação e pressione a nova tecla. Mouse e teclas 1–3 ficam fixos.", Vector2(0, 590), 15, Color("a7b9bf"))
	refresh_controls()
	if OS.has_feature("android"):
		for child in pages.controls.get_children():
			child.hide()
		label(pages.controls,"CONTROLES DE TOQUE",Vector2.ZERO,27,Color("ffd18a"))
		label(pages.controls,"Arraste para olhar. Use o analogico para mover ou dirigir.",Vector2(0,80),19)
		button(pages.controls,"Mudar posicao dos controles",Rect2(0,145,600,60),func(): world.touch_controls.start_edit())
		label(pages.controls,"No editor, arraste qualquer botao ou o analogico e toque em SALVAR.",Vector2(0,245),18)
		label(pages.controls,"RESTAURAR retorna ao padrao; CANCELAR desfaz a edicao.",Vector2(0,285),18)
	var toggle_x := 0.0 if OS.has_feature("android") else 660.0
	var toggle_y := 355.0 if OS.has_feature("android") else 95.0
	for setting in [["toggle_crouch","Alternar agachar"],["toggle_sprint","Alternar correr"]]:
		var option := CheckButton.new()
		option.text=setting[1]
		option.position=Vector2(toggle_x,toggle_y)
		option.button_pressed=world.settings.get(setting[0])
		pages.controls.add_child(option)
		option.toggled.connect(func(enabled): world.settings.set(setting[0],enabled); world.settings.save_settings())
		toggle_y+=60
	get_viewport().size_changed.connect(resize_canvas)
	resize_canvas()
	visible = false

func label(parent: Node, value: String, at: Vector2, font_size: int, color := Color("edf1ed")) -> Label:
	var node := Label.new()
	node.text = value
	node.position = at
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	parent.add_child(node)
	return node

func button(parent: Node, value: String, rect: Rect2, callback: Callable) -> Button:
	var node := Button.new()
	node.text = value
	node.position = rect.position
	node.size = rect.size
	node.pressed.connect(callback)
	parent.add_child(node)
	return node

func resize_canvas() -> void:
	canvas.scale = get_viewport_rect().size / Vector2(1280, 720)

func open_for(value: String) -> void:
	visible = value in ["pause", "map", "mode", "campaign_complete"]
	campaign_save_button.visible = value in ["pause", "map"] and world.game_mode == "campaign"
	if visible:
		show_page("map" if value == "map" else ("mode" if value == "mode" else ("ending" if value == "campaign_complete" else "home")))

func show_mode_select() -> void:
	world.activities.set_menu("mode")
	if is_instance_valid(menu_music) and not menu_music.playing:
		menu_music.play()

func make_menu_music() -> AudioStreamWAV:
	const RATE := 22050
	const SECONDS := 8
	var stream:=AudioStreamWAV.new()
	stream.format=AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate=RATE
	stream.stereo=false
	stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
	stream.loop_end=RATE*SECONDS
	var pcm:=PackedByteArray()
	pcm.resize((RATE*SECONDS+1)*2)
	var chords: Array=[ [130.81,164.81,196.0], [110.0,130.81,164.81], [87.31,110.0,130.81], [98.0,123.47,146.83] ]
	var melody: Array=[261.63,0.0,329.63,392.0,0.0,329.63,293.66,0.0,261.63,0.0,220.0,261.63,0.0,293.66,329.63,0.0]
	for i in RATE*SECONDS:
		var t:=float(i)/RATE
		var beat:=int(t*2.0)
		var chord: Array=chords[int(t/2.0)%chords.size()]
		var sample:=0.0
		for frequency in chord:
			sample+=sin(TAU*float(frequency)*t)*0.035
		var note: float=melody[beat%melody.size()]
		if note>0.0:
			var phase:=fposmod(t*2.0,1.0)
			var envelope:=exp(-phase*3.0)
			sample+=sin(TAU*note*t)*envelope*0.055
		var fade:=minf(1.0,minf(float(i)/500.0,float(RATE*SECONDS-i)/500.0))
		var value:=int(clampf(sample*fade,-0.95,0.95)*32767.0)
		pcm[i*2]=value & 0xff
		pcm[i*2+1]=(value>>8) & 0xff
	# Godot's WAV loop mixer can read the loop_end frame before wrapping.
	pcm[RATE*SECONDS*2]=pcm[0]
	pcm[RATE*SECONDS*2+1]=pcm[1]
	stream.data=pcm
	return stream

func show_campaign_complete() -> void:
	world.activities.set_menu("campaign_complete")

func start_new_campaign() -> void:
	if world.network != null and world.network.active():
		world.notify("Desconecte da sala para jogar a campanha.")
		return
	if is_instance_valid(menu_music):
		menu_music.stop()
	world.activities.set_menu("")
	world.game_mode = "campaign"
	world.activities.game_mode = "campaign"
	world.activities.new_campaign()

func show_page(value: String) -> void:
	if value != "controls":
		awaiting_action = ""
		refresh_controls()
	page = value
	if value=="character":
		name_edit.text=world.profile.player_name
		outfit_select.select(world.profile.outfit)
		profile_status.text="Suas escolhas ficam salvas neste dispositivo."
	for name in pages:
		pages[name].visible = name == value
	refresh()
	if value == "map":
		map_view.inspect_at = Vector2.INF
		map_view.dragging = false
		map_view.grab_focus()
		map_view.queue_redraw()
	elif value == "graphics":
		world.restore_pointer()

func refresh() -> void:
	for key in advanced_options:
		var value: int = {"textures":world.settings.texture_quality,"shadows":world.settings.shadow_quality,"aa":world.settings.antialiasing,"distance":world.settings.draw_distance,"details":int(world.settings.detail_maps)}[key]
		advanced_options[key].select(value)
	quality_select.select(5 if world.settings.customized else world.settings.quality)
	upscaling_select.select(world.settings.upscaling)
	if window_mode_select != null:
		window_mode_select.select(world.settings.window_mode)
		resolution_select.select(window_resolutions.find(world.settings.window_resolution))
		resolution_select.disabled=world.settings.window_mode!=2
	fps_select.select(world.settings.FPS_LIMITS.find(world.settings.fps_limit))
	counter_select.select(world.settings.fps_corner+1)
	status.text = "%s  ·  %s  ·  atual: %d FPS" % [world.settings.QUALITIES[world.settings.quality], "Sem limite" if world.settings.fps_limit == 0 else "%d FPS" % world.settings.fps_limit, Engine.get_frames_per_second()]

func resume() -> void:
	awaiting_action = ""
	refresh_controls()
	map_view.dragging = false
	world.activities.set_menu("")

func handle_input(event: InputEvent) -> bool:
	if awaiting_action != "":
		if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode != KEY_NONE:
			var action_name := awaiting_action
			awaiting_action = ""
			for old_event in InputMap.action_get_events(action_name):
				if old_event is InputEventKey:
					InputMap.action_erase_event(action_name, old_event)
			var replacement := InputEventKey.new()
			replacement.physical_keycode = event.physical_keycode
			InputMap.action_add_event(action_name, replacement)
			world.settings.save_binding(action_name, event.physical_keycode)
			refresh_controls()
		return true
	if event.is_action_pressed("pause"):
		if page == "home" or world.activities.menu == "map":
			resume()
		else:
			show_page("home")
	elif event.is_action_pressed("map"):
		if world.activities.menu == "map":
			resume()
		else:
			show_page("home" if page == "map" else "map")
	elif page == "map" and event is InputEventKey:
		map_view.handle_key(event)
	return true

func begin_rebind(action_name: String) -> void:
	awaiting_action = action_name
	key_buttons[action_name].text = "Pressione uma tecla..."

func refresh_controls() -> void:
	for action_name in key_buttons:
		if awaiting_action == action_name:
			continue
		for event in InputMap.action_get_events(action_name):
			if event is InputEventKey:
				key_buttons[action_name].text = OS.get_keycode_string(event.physical_keycode)
				break

func _process(delta: float) -> void:
	if visible and page == "graphics":
		clock += delta
		if clock > 0.5:
			clock = 0
			refresh()

func save_profile() -> void:
	if world.profile.save_profile(name_edit.text,outfit_select.selected):
		name_edit.text=world.profile.player_name
		profile_status.text="Nome e roupa salvos! Os outros jogadores recebem a mudanca."
	else:
		profile_status.text="Nao foi possivel salvar. Tente novamente."
