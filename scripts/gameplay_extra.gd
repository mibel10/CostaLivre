extends Node

var world: Node3D
var wheel := false
var selection := 0
var punch_time := 0.0
var punch_arm: MeshInstance3D
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
	for name in ["step", "punch", "cash", "siren", "death", "hack", "explosion"]:
		var wav := AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.mix_rate = 22050
		var count := 22050 if name == "death" else (11025 if name=="explosion" else 6600)
		var data := PackedByteArray()
		data.resize(count * 2)
		for i in count:
			var t := float(i) / 22050
			var frequency := 750.0 if name == "cash" else (520.0 + sin(t * 25) * 190 if name == "siren" else (460.0 + 310.0 * fmod(floor(t*18),2.0) if name=="hack" else 90.0))
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
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		world.hud.queue_redraw()
		return true
	if wheel:
		if event is InputEventMouseMotion:
			var cursor: Vector2 = event.position / world.get_viewport().get_visible_rect().size * Vector2(1280, 720) - Vector2(640, 360)
			if cursor.length() < 30:
				return true
			var angle := rad_to_deg(cursor.angle())
			var best := 1000.0
			for i in 5:
				var difference := absf(wrapf(angle - (-90.0 + i * 72.0), -180.0, 180.0))
				if difference < best:
					best = difference
					selection = i
			if selection == 2 and not world.activities.rifle_owned or selection == 3 and not world.activities.shotgun_owned or selection == 4 and not world.activities.smg_owned:
				selection = 0
		return true
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_V and not world.get_tree().paused:
		punch()
		return true
	return false

func punch() -> void:
	if punch_time > 0 or world.active_car != null or world.car_transition or world.activities.menu != "" or world.activities.bank.local_hacking() or world.player.roll_time > 0 or (world.network!=null and world.network.active() and world.network.rules.local_mission_hacking()):
		return
	if world.network!=null and world.network.active():
		punch_time=0.45
		world.activities.weapon=0
		world.network.rules.send_action("punch",{"yaw":world.camera_yaw})
		return
	punch_time = 0.45
	world.activities.weapon = 0
	world.player.model.rotation.y = world.camera_yaw
	play("punch")
	var origin: Vector3 = world.player.position + Vector3(0, 1.1, 0)
	var forward := Vector3.FORWARD.rotated(Vector3.UP, world.camera_yaw)
	for target in world.cars + world.activities.officers + (world.life.people if world.life != null else []):
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
	if what == NOTIFICATION_WM_WINDOW_FOCUS_IN and is_inside_tree() and world != null and not world.finished and not get_tree().paused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and wheel:
		wheel = false
		Engine.time_scale = 1
		world.hud.queue_redraw()
