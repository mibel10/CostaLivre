extends Node

var world: Node3D
var wheel := false
var selection := 0
var punch_time := 0.0
var punch_arm: MeshInstance3D
var last_car: Node3D
var was_reloading := false
var last_hack_entered := 0
var audio: AudioStreamPlayer
var step_audio: AudioStreamPlayer
var siren_audio: AudioStreamPlayer
var sounds := {}
var step_clock := 0.0
var siren_clock := 0.0
var death_started := 0
var death_filter: ColorRect

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	audio = AudioStreamPlayer.new()
	audio.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(audio)
	step_audio = AudioStreamPlayer.new()
	step_audio.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(step_audio)
	siren_audio = AudioStreamPlayer.new()
	siren_audio.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(siren_audio)
	for name in ["step", "punch", "cash", "siren", "death", "hack", "explosion", "door", "reload", "digit"]:
		var wav := AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.mix_rate = 22050
		var count := 22050 if name == "death" else (11025 if name=="explosion" else 6600)
		var data := PackedByteArray()
		data.resize(count * 2)
		for i in count:
			var t := float(i) / 22050
			var frequency := 750.0 if name == "cash" else (520.0 + sin(t * 25) * 190 if name == "siren" else (460.0 + 310.0 * fmod(floor(t*18),2.0) if name=="hack" else 90.0))
			if name == "door": frequency = 125.0 + 65.0 * exp(-t * 18.0)
			elif name == "reload": frequency = 380.0 + 110.0 * fmod(floor(t * 20.0), 2.0)
			elif name == "digit": frequency = 920.0
			var value := sin(TAU * frequency * t) * exp(-t * (3 if name == "death" else (7 if name=="explosion" else 20)))
			if name=="explosion": value=(value*0.35+randf_range(-1.0,1.0)*exp(-t*11))*minf(1.0,t*90)
			data.encode_s16(i * 2, int(value * 14000))
		wav.data = data
		sounds[name] = wav
	punch_arm = world.box(world.player.model, Vector3.ZERO, Vector3(0.14, 0.14, 0.42), Color("c9af91"))
	punch_arm.visible = false
	death_filter = ColorRect.new()
	death_filter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	death_filter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/defeat.gdshader")
	death_filter.material = mat
	death_filter.visible = false
	world.hud.get_parent().add_child(death_filter)
	world.hud.get_parent().move_child(death_filter, 0)

func play(name: String, volume := -18.0) -> void:
	var voice := step_audio if name == "step" else (siren_audio if name == "siren" else audio)
	voice.stream = sounds[name]
	voice.volume_db = volume
	voice.play()

func wheel_weapon(offset: Vector2) -> int:
	return posmod(roundi((rad_to_deg(offset.angle()) + 90.0) / 45.0), 8)

func handle_input(event: InputEvent) -> bool:
	if world.finished:
		return false
	if event is InputEventKey and event.physical_keycode == KEY_Q and not event.echo and not world.get_tree().paused and not world.activities.bank.local_hacking() and not (world.network!=null and world.network.active() and world.network.rules.local_mission_hacking()):
		wheel = event.pressed
		if wheel:
			selection = world.activities.weapon
			Engine.time_scale = 1.0 if world.network!=null and world.network.active() else 0.2
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			world.get_viewport().warp_mouse(world.get_viewport().get_visible_rect().size / 2)
		else:
			world.activities.weapon = selection
			world.activities.reload_time = 0
			Engine.time_scale = 1
			world.restore_pointer()
		world.hud.queue_redraw()
		return true
	if wheel:
		if event is InputEventMouseMotion:
			var cursor: Vector2 = event.position / world.get_viewport().get_visible_rect().size * Vector2(1280, 720) - Vector2(640, 360)
			if cursor.length() < 30:
				return true
			selection = wheel_weapon(cursor)
			if not world.activities.owns_weapon(selection):
				selection = 0
		return true
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_V and not world.get_tree().paused and world.active_car == null:
		punch()
		return true
	return false

func punch() -> void:
	if punch_time > 0 or world.active_car != null or world.car_transition or world.activities.menu != "" or world.activities.bank.local_hacking() or world.player.roll_time > 0 or (world.network!=null and world.network.active() and world.network.rules.local_mission_hacking()):
		return
	punch_time = 0.45
	world.activities.weapon = 0
	world.player.model.rotation.y = world.camera_yaw
	play("punch")
	if world.network!=null and world.network.active():
		world.network.rules.send_action("punch",{"yaw":world.camera_yaw})
		return
	var origin: Vector3 = world.player.position + Vector3(0, 1.1, 0)
	var forward := Vector3.FORWARD.rotated(Vector3.UP, world.camera_yaw)
	var targets: Array = world.cars + world.activities.officers + (world.life.people if world.life != null else [])
	targets.sort_custom(func(a, b): return (a.position + Vector3.UP).distance_squared_to(origin) < (b.position + Vector3.UP).distance_squared_to(origin))
	for target in targets:
		var offset: Vector3 = target.position + Vector3(0, 1, 0) - origin
		if offset.length() < 2.5 and offset.normalized().dot(forward) > 0.35:
			var query := PhysicsRayQueryParameters3D.create(origin, target.position + Vector3(0, 1, 0), 1)
			if world.get_world_3d().direct_space_state.intersect_ray(query).is_empty():
				target.take_hit(25)
				world.raise_heat(6)
				break

func begin_death() -> void:
	wheel = false
	Engine.time_scale = 0.18
	death_started = Time.get_ticks_msec()
	death_filter.visible = true
	play("death", -10)

func _process(delta: float) -> void:
	if world.finished:
		var seconds := (Time.get_ticks_msec() - death_started) / 1000.0
		if seconds >= 3.0:
			world.respawn_local()
			return
		world.player.model.rotation.z = move_toward(world.player.model.rotation.z, 1.4, delta * 2)
		death_filter.material.set_shader_parameter("strength", clampf(seconds / 1.5, 0, 1))
		world.hud.queue_redraw()
		return
	if world.get_tree().paused:
		return
	var current_car: Node3D = world.active_car
	if current_car != last_car:
		if current_car != null or is_instance_valid(last_car):
			play("door", -20)
		last_car = current_car
	var reloading: bool = world.activities.reload_time > 0.0
	if reloading and not was_reloading:
		play("reload", -22)
	was_reloading = reloading
	var entered: int = world.activities.bank.entered if world.activities.bank.local_hacking() else 0
	if entered > last_hack_entered:
		play("digit", -24)
	last_hack_entered = entered
	punch_time = maxf(0, punch_time - delta)
	punch_arm.visible = punch_time > 0
	if punch_time > 0:
		var extension := sin((1 - punch_time / 0.45) * PI)
		punch_arm.position = Vector3(0.28, 1.25, -0.3 - extension * 0.7)
		world.player.model.rotation.z = extension * -0.13
	else:
		world.player.model.rotation.z = 0
	step_clock -= delta
	if world.active_car == null and world.player.is_on_floor() and world.player.roll_time <= 0 and world.player.velocity.length() > 1 and step_clock <= 0:
		play("step", -29)
		step_clock = 0.3
	siren_clock -= delta
	if world.heat > 0 and siren_clock <= 0 and not siren_audio.playing:
		for cop in world.cops:
			if cop.position.distance_to(world.subject_position()) < 45:
				play("siren", -18-cop.position.distance_to(world.subject_position())*0.3)
				break
		siren_clock = 0.7

func _exit_tree() -> void:
	Engine.time_scale = 1
	audio.stop()
	step_audio.stop()
	siren_audio.stop()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_IN and is_inside_tree() and world != null:
		world.restore_pointer.call_deferred()
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and wheel:
		wheel = false
		Engine.time_scale = 1
		world.hud.queue_redraw()
