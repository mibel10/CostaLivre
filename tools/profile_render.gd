extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func sample(world: Node3D, label: String) -> void:
	await create_timer(4.0).timeout
	var times: Array[float] = []
	var start := Time.get_ticks_usec()
	var previous := start
	var draw_calls := 0.0
	var triangles := 0.0
	while Time.get_ticks_usec() - start < 6000000:
		world.health = 10000
		world.bust_progress = 0
		await process_frame
		var now := Time.get_ticks_usec()
		times.append((now - previous) / 1000.0)
		previous = now
		draw_calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		triangles += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	times.sort()
	var slow_count := maxi(1, ceili(times.size() * 0.01))
	var slow_ms := 0.0
	for time in times.slice(-slow_count):
		slow_ms += time
	print(label, ": fps=", snappedf(times.size() * 1000000.0 / (previous - start), 0.1),
		" low_1pct=", snappedf(slow_count * 1000.0 / slow_ms, 0.1),
		" draws=", roundi(draw_calls / times.size()), " triangles=", roundi(triangles / times.size()))

func run() -> void:
	seed(42)
	var world = load("res://main.tscn").instantiate()
	root.add_child(world)
	world.start_mode("sandbox")
	world.settings.set_quality(0, false)
	world.settings.set_fps_limit(0, false)
	world.settings.upscaling = 2 if OS.get_cmdline_user_args().has("--balanced") else 0
	world.settings.apply_upscaling()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1028, 720))
	world.set_process_unhandled_input(false)
	world.camera_yaw = 0.15
	print("GPU: ", RenderingServer.get_video_adapter_name(), " / Ultra / ", root.size,
		" / 3D scale ", world.settings.UPSCALING_SCALES[world.settings.upscaling])
	await sample(world, "rua")
	var car: CharacterBody3D = world.cars[0]
	car.position = Vector3(0, 0.3, 126)
	car.heading = 0.0
	world.active_car = car
	car.driving = true
	Input.action_press("forward", 0.48)
	await sample(world, "dirigindo")
	Input.action_release("forward")
	car.speed = 0.0
	car.driving = false
	world.active_car = null
	world.player.position = world.activities.bank.to_global(Vector3(3, 0.3, 9))
	world.camera_yaw = 0.35
	await sample(world, "banco")
	world.player.position = Vector3(0, 0.3, 50)
	world.camera_yaw = PI
	world.raise_heat(100)
	world.update_dispatch(6)
	for i in world.cops.size():
		world.cops[i].position = Vector3(-3 + (i % 2) * 6, 0.3, 65 + i * 8)
	await sample(world, "perseguicao")
	quit()
