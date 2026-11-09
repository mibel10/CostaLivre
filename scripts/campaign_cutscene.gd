extends Control

var world: Node3D
var title := ""
var subtitle := ""
var callback := Callable()
var active := false
var started_msec := 0
var duration_msec := 4200
var gameplay_camera := Transform3D.IDENTITY
var gameplay_fov := 68.0
var view_direction := Vector3.BACK
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
	if not active:
		gameplay_camera = world.camera.global_transform
		gameplay_fov = world.camera.fov
	active = true
	visible = true
	focus = world.subject_position() + Vector3(0,1.2,0)
	var offset := gameplay_camera.origin - focus
	offset.y = 0.0
	view_direction = offset.normalized() if offset.length_squared() > 0.01 else Vector3.BACK
	_frame_camera(0.0)
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
	if elapsed >= duration_msec:
		finish()
	else:
		_frame_camera(progress)
		queue_redraw()

func _frame_camera(progress: float) -> void:
	var wide_shot := progress < 0.48
	var shot_progress := progress / 0.48 if wide_shot else (progress - 0.48) / 0.52
	var motion := smoothstep(0.0, 1.0, shot_progress)
	var angle := lerpf(-0.25, 0.30, motion) if wide_shot else lerpf(0.95, 0.55, motion)
	var distance := lerpf(9.0, 7.0, motion) if wide_shot else lerpf(5.0, 3.8, motion)
	var height := 2.8 if wide_shot else 0.7
	var desired := focus + view_direction.rotated(Vector3.UP, angle) * distance + Vector3.UP * height
	world.camera.global_position = world.safe_camera_position(focus, desired)
	world.camera.fov = 66.0 if wide_shot else 52.0
	if world.camera.global_position.distance_squared_to(focus) > 0.01:
		world.camera.look_at(focus)

func finish() -> void:
	if not active:
		return
	active = false
	visible = false
	world.camera.global_transform = gameplay_camera
	world.camera.fov = gameplay_fov
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
	var progress := clampf(float(elapsed) / duration_msec, 0.0, 1.0)
	var cut := 1.0 - smoothstep(0.0, 0.035, absf(progress - 0.48))
	draw_rect(Rect2(0,0,1280,720),Color(0.01,0.025,0.035,maxf(0.12*alpha,cut)))
	draw_rect(Rect2(0,0,1280,92),Color(0.01,0.025,0.035,0.96*alpha))
	draw_rect(Rect2(0,628,1280,92),Color(0.01,0.025,0.035,0.96*alpha))
	draw_string(font,Vector2(86,505),title,HORIZONTAL_ALIGNMENT_LEFT,-1,33,Color(1,0.82,0.54,alpha))
	draw_string(font,Vector2(88,548),subtitle,HORIZONTAL_ALIGNMENT_LEFT,1100,21,Color(0.92,0.95,0.93,alpha))
	var skip_hint := "TOQUE NA TELA PARA PULAR" if OS.has_feature("android") else "PRESSIONE UMA TECLA OU CLIQUE PARA PULAR"
	draw_string(font,Vector2(88,594),skip_hint,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color(0.68,0.76,0.78,alpha))
