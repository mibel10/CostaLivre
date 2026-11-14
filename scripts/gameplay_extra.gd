extends Node

var world: Node3D
var wheel := false
var selection := 0
var emote_wheel := false
var emote_selection := 0
var punch_time := 0.0
var punch_arm: MeshInstance3D
var last_car: Node3D
var was_reloading := false
var last_hack_entered := 0
var audio: AudioStreamPlayer
var step_audio: AudioStreamPlayer
var siren_audio: AudioStreamPlayer
var chase_audio: AudioStreamPlayer
var emote_music: AudioStreamPlayer
var sounds := {}
var step_clock := 0.0
var siren_clock := 0.0
var death_started := 0
var death_filter: ColorRect
var battle_marks: Array[Node3D] = []
var effects_bus := ""
var rain_audio: AudioStreamPlayer
var effects_indoors := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	effects_bus = "Interior_"+str(get_instance_id())
	AudioServer.add_bus()
	var bus := AudioServer.bus_count-1
	AudioServer.set_bus_name(bus,effects_bus)
	var lowpass := AudioEffectLowPassFilter.new()
	lowpass.cutoff_hz = 1800
	AudioServer.add_bus_effect(bus,lowpass)
	AudioServer.set_bus_effect_enabled(bus,0,false)
	audio = AudioStreamPlayer.new()
	audio.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(audio)
	step_audio = AudioStreamPlayer.new()
	step_audio.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(step_audio)
	siren_audio = AudioStreamPlayer.new()
	siren_audio.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(siren_audio)
	chase_audio = AudioStreamPlayer.new()
	chase_audio.process_mode = Node.PROCESS_MODE_PAUSABLE
	chase_audio.stream = make_chase_music()
	chase_audio.volume_db = -60.0
	add_child(chase_audio)
	if ResourceLoader.exists("res://assets/audio/golden_wind.ogg"):
		emote_music = AudioStreamPlayer.new()
		emote_music.process_mode = Node.PROCESS_MODE_PAUSABLE
		emote_music.stream = load("res://assets/audio/golden_wind.ogg") as AudioStream
		emote_music.volume_db = -8.0
		add_child(emote_music)
	for name in ["step", "punch", "cash", "siren", "death", "hack", "explosion", "door", "reload", "digit", "thunder", "impact", "clue", "splash", "rain"]:
		var wav := AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.mix_rate = 22050
		var count := 22050 if name == "death" else (11025 if name=="explosion" else 6600)
		if name in ["rain","thunder"]: count = 44100
		var data := PackedByteArray()
		data.resize(count * 2)
		for i in count:
			var t := float(i) / 22050
			var frequency := 750.0 if name == "cash" else (520.0 + sin(t * 25) * 190 if name == "siren" else (460.0 + 310.0 * fmod(floor(t*18),2.0) if name=="hack" else 90.0))
			if name == "door": frequency = 125.0 + 65.0 * exp(-t * 18.0)
			elif name == "reload": frequency = 380.0 + 110.0 * fmod(floor(t * 20.0), 2.0)
			elif name == "digit": frequency = 920.0
			elif name == "clue": frequency = 440.0+sin(t*12)*220.0
			elif name == "thunder": frequency = 38.0+sin(t*16)*18.0
			var value := sin(TAU * frequency * t) * exp(-t * (3 if name == "death" else (7 if name=="explosion" else 20)))
			if name=="explosion": value=(value*0.35+randf_range(-1.0,1.0)*exp(-t*11))*minf(1.0,t*90)
			if name in ["thunder","impact","splash"]: value = (value*0.3+randf_range(-0.6,0.6))*exp(-t*(5.0 if name == "thunder" else 18.0))
			if name == "rain": value = randf_range(-0.3,0.3)
			data.encode_s16(i * 2, int(value * 14000))
		wav.data = data
		if name == "rain":
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_end = count
		sounds[name] = wav
	rain_audio = AudioStreamPlayer.new()
	rain_audio.stream = sounds.rain
	rain_audio.bus = effects_bus
	add_child(rain_audio)
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
	for voice in [audio,step_audio,siren_audio]: voice.bus = effects_bus

func battle_impact(at: Vector3, direction := Vector3.FORWARD) -> void:
	if world.subject_position().distance_to(at)>100: return
	var ray := PhysicsRayQueryParameters3D.create(at-direction*0.25,at+direction*0.25,7)
	var hit := world.get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty(): return
	battle_marks.assign(battle_marks.filter(func(mark): return is_instance_valid(mark)))
	var impact := AudioStreamPlayer3D.new()
	impact.stream = sounds.impact
	impact.bus = effects_bus
	impact.volume_db = -24
	impact.max_distance = 45
	world.add_child(impact)
	impact.position = at
	impact.finished.connect(impact.queue_free)
	impact.play()
	while battle_marks.size() >= 48:
		var old := battle_marks.pop_front() as Node3D
		if is_instance_valid(old): old.queue_free()
	var normal: Vector3 = hit.normal
	var mark: MeshInstance3D = world.box(world,hit.position+normal*0.012,Vector3(0.14,0.14,0.008),Color("353035"))
	mark.look_at(mark.global_position+normal,Vector3.RIGHT if absf(normal.dot(Vector3.UP))>0.95 else Vector3.UP)
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if hit.collider is Node3D: mark.reparent(hit.collider,true)
	battle_marks.append(mark)
	var fade := mark.create_tween()
	fade.tween_interval(12)
	fade.tween_property(mark,"scale",Vector3.ONE*0.01,3)
	fade.tween_callback(mark.queue_free)

func play(name: String, volume := -18.0) -> void:
	var voice := step_audio if name in ["step","splash"] else (siren_audio if name == "siren" else audio)
	voice.stream = sounds[name]
	voice.volume_db = volume
	voice.play()

func make_chase_music() -> AudioStreamWAV:
	const RATE := 22050
	const SECONDS := 8
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = RATE * SECONDS
	var data := PackedByteArray()
	data.resize(RATE * SECONDS * 2)
	var bass_notes := [55.0,55.0,65.41,49.0,55.0,73.42,65.41,49.0]
	for i in RATE * SECONDS:
		var t := float(i) / RATE
		var beat := int(t * 2.0)
		var bass := sin(TAU * bass_notes[beat % bass_notes.size()] * t) * 0.10
		var pulse_phase := fposmod(t,0.5)
		var pulse := sin(TAU * 165.0 * t) * exp(-pulse_phase * 13.0) * 0.16
		var alarm := sin(TAU * (440.0 if beat % 4 < 2 else 523.25) * t) * 0.035
		data.encode_s16(i * 2,int(clampf(bass + pulse + alarm,-1.0,1.0) * 15000.0))
	stream.data = data
	return stream

func wheel_weapon(offset: Vector2) -> int:
	return posmod(roundi((rad_to_deg(offset.angle()) + 90.0) / 45.0), 8)

func wheel_emote(offset: Vector2) -> int:
	return posmod(roundi((rad_to_deg(offset.angle()) + 90.0) / 72.0), 5)

func play_emote_music(name: String) -> void:
	if name == "torture_dance" and is_instance_valid(emote_music) and not emote_music.playing:
		emote_music.play()

func finish_emote_wheel(index := -1) -> void:
	emote_wheel = false
	Engine.time_scale = 1
	if index >= 0 and index < world.network.EMOTES.size():
		world.network.send_emote(world.network.EMOTES[index])
	world.restore_pointer()
	world.hud.queue_redraw()

func handle_input(event: InputEvent) -> bool:
	if world.finished:
		return false
	if (wheel or emote_wheel) and event.is_action_pressed("pause"):
		wheel = false
		finish_emote_wheel()
		return true
	if event is InputEventKey and event.physical_keycode == KEY_Q and not event.echo and not emote_wheel:
		if not wheel and (not event.pressed or world.activities.menu != "" or world.hud.phone_panel.visible or world.get_tree().paused or world.activities.bank.local_hacking() or (world.network != null and world.network.active() and world.network.rules.local_mission_hacking())):
			return false
		wheel = event.pressed
		if wheel:
			selection = world.activities.weapon
			Engine.time_scale = 1.0 if world.network!=null and world.network.active() else 0.2
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			world.get_viewport().warp_mouse(world.get_viewport().get_visible_rect().size / 2)
		else:
			if world.activities.menu == "" and not world.get_tree().paused:
				world.activities.weapon = selection
				world.activities.reload_time = 0
			Engine.time_scale = 1
			world.restore_pointer()
		world.hud.queue_redraw()
		return true
	if event is InputEventKey and event.physical_keycode == KEY_B and not event.echo:
		if event.pressed and not wheel and not world.get_tree().paused and world.activities.menu == "" and not world.hud.phone_panel.visible and world.active_car == null and not world.car_transition and not world.activities.bank.local_hacking() and not (world.network != null and world.network.active() and world.network.rules.local_mission_hacking()):
			emote_wheel = true
			emote_selection = 0
			Engine.time_scale = 1.0 if world.network != null and world.network.active() else 0.2
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			world.get_viewport().warp_mouse(world.get_viewport().get_visible_rect().size / 2)
			world.hud.queue_redraw()
			return true
		if not event.pressed and emote_wheel:
			finish_emote_wheel(emote_selection)
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
	if emote_wheel:
		if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			Input.action_release("shoot" if event.button_index == MOUSE_BUTTON_LEFT else "aim")
			var offset: Vector2 = event.position / world.get_viewport().get_visible_rect().size * Vector2(1280,720) - Vector2(640,360)
			finish_emote_wheel(wheel_emote(offset) if event.button_index == MOUSE_BUTTON_LEFT and offset.length() >= 66.0 and offset.length() <= 205.0 else -1)
			return true
		if event is InputEventMouseMotion:
			var cursor: Vector2 = event.position / world.get_viewport().get_visible_rect().size * Vector2(1280, 720) - Vector2(640, 360)
			if cursor.length() >= 30.0:
				emote_selection = wheel_emote(cursor)
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
	emote_wheel = false
	Engine.time_scale = 0.18
	death_started = Time.get_ticks_msec()
	death_filter.visible = true
	play("death", -10)

func _process(delta: float) -> void:
	if world.finished:
		chase_audio.stop()
		chase_audio.volume_db = -60.0
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
	var bus := AudioServer.get_bus_index(effects_bus)
	var indoors: bool = world.life.inside_public_interior(world.subject_position()) or world.PRISON_INTERIOR.has_point(world.subject_position())
	if bus >= 0 and indoors != effects_indoors:
		AudioServer.set_bus_effect_enabled(bus,0,indoors)
		effects_indoors = indoors
	if world.atmosphere_cycle.storm>0.1:
		if not rain_audio.playing: rain_audio.play()
		rain_audio.volume_db = -30.0+(world.atmosphere_cycle.storm*8.0)-(10.0 if indoors else 0.0)
	elif rain_audio.playing: rain_audio.stop()
	if world.activities.shot_audio.bus != effects_bus: world.activities.shot_audio.bus = effects_bus
	var chase_heat: float = world.heat
	if world.network != null and world.network.active():
		chase_heat = world.network.rules.wanted_heat(multiplayer.get_unique_id())
	var pursuit: bool = chase_heat >= (12.0 if world.network != null and world.network.active() else 20.0) and world.activities.menu == ""
	if pursuit and not chase_audio.playing:
		chase_audio.play()
	chase_audio.volume_db = move_toward(chase_audio.volume_db,-17.0 if pursuit else -60.0,delta*22.0)
	if not pursuit and chase_audio.playing and chase_audio.volume_db <= -59.0:
		chase_audio.stop()
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
		play("splash" if world.atmosphere_cycle.flooded(world.player.position) else "step", -29)
		step_clock = 0.3
	siren_clock -= delta
	if world.heat > 0 and siren_clock <= 0 and not siren_audio.playing:
		for cop in world.cops:
			if cop.position.distance_to(world.subject_position()) < 45:
				play("siren", -18-cop.position.distance_to(world.subject_position())*0.3)
				break
		siren_clock = 0.7

func _exit_tree() -> void:
	var bus := AudioServer.get_bus_index(effects_bus)
	if bus > 0: AudioServer.remove_bus(bus)
	Engine.time_scale = 1
	audio.stop()
	step_audio.stop()
	siren_audio.stop()
	chase_audio.stop()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_IN and is_inside_tree() and world != null:
		world.restore_pointer.call_deferred()
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and (wheel or emote_wheel):
		wheel = false
		emote_wheel = false
		Engine.time_scale = 1
		world.hud.queue_redraw()
