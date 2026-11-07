extends Control

var world: Node3D
var title := ""
var subtitle := ""
var callback := Callable()
var active := false
var started_msec := 0
var duration_msec := 3400
var camera_start := Vector3.ZERO
var camera_end := Vector3.ZERO
var focus := Vector3.ZERO
var font: Font

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	font = ThemeDB.fallback_font
	visible = false

func play(scene_title: String, scene_subtitle: String, on_finished := Callable()) -> void:
	title = scene_title
	subtitle = scene_subtitle
	callback = on_finished
	started_msec = Time.get_ticks_msec()
	active = true
	visible = true
	focus = world.subject_position() + Vector3(0,1.2,0)
	camera_start = world.camera.global_position
	camera_end = focus + Vector3(-7,4,9)
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not active:
		return
	var skip: bool = event is InputEventKey and event.pressed and not event.echo
	skip = skip or (event is InputEventMouseButton and event.pressed)
	if skip:
		get_viewport().set_input_as_handled()
		finish()

func _process(_delta: float) -> void:
	if not active:
		return
	var elapsed := Time.get_ticks_msec() - started_msec
	var progress := clampf(float(elapsed) / duration_msec, 0, 1)
	if is_instance_valid(world.camera):
		world.camera.global_position = world.safe_camera_position(focus,camera_start.lerp(camera_end, ease(progress, 0.65)))
		if world.camera.global_position.distance_to(focus)>0.1:
			world.camera.look_at(focus)
	if elapsed >= duration_msec:
		finish()
	else:
		queue_redraw()

func finish() -> void:
	if not active:
		return
	active = false
	visible = false
	var next := callback
	callback = Callable()
	world.activities.set_menu("")
	if next.is_valid():
		next.call()

func _draw() -> void:
	if not active or font == null:
		return
	var screen := get_viewport_rect().size
	var scale := screen / Vector2(1280,720)
	draw_set_transform(Vector2.ZERO,0,scale)
	var elapsed := Time.get_ticks_msec() - started_msec
	var alpha := minf(1.0,float(elapsed)/350.0)
	if elapsed > duration_msec - 450:
		alpha = minf(alpha,float(duration_msec-elapsed)/450.0)
	draw_rect(Rect2(0,0,1280,720),Color(0.01,0.025,0.035,0.34*alpha))
	draw_rect(Rect2(0,0,1280,92),Color(0.01,0.025,0.035,0.96*alpha))
	draw_rect(Rect2(0,628,1280,92),Color(0.01,0.025,0.035,0.96*alpha))
	draw_string(font,Vector2(86,505),title,HORIZONTAL_ALIGNMENT_LEFT,-1,33,Color(1,0.82,0.54,alpha))
	draw_string(font,Vector2(88,548),subtitle,HORIZONTAL_ALIGNMENT_LEFT,1100,21,Color(0.92,0.95,0.93,alpha))
	draw_string(font,Vector2(88,594),"PRESSIONE UMA TECLA OU CLIQUE PARA PULAR",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color(0.68,0.76,0.78,alpha))
