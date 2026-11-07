extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func sample(label: String, frames := 70) -> void:
	for i in 15:
		await process_frame
	var times: Array[float] = []
	var previous := Time.get_ticks_usec()
	for i in frames:
		await process_frame
		var now := Time.get_ticks_usec()
		times.append((now - previous) / 1000.0)
		previous = now
	times.sort()
	print(label, ": median_ms=", snappedf(times[times.size() / 2], 0.01), " p95_ms=", snappedf(times[int(times.size() * 0.95)], 0.01), " draws=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " triangles=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), " process_ms=", Performance.get_monitor(Performance.TIME_PROCESS) * 1000)

func run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var world = load("res://main.tscn").instantiate()
	root.add_child(world)
	world.settings.set_fps_limit(0, false)
	world.set_process_unhandled_input(false)
	world.camera_yaw = 0
	world.camera_pitch = 0.25
	print("Viewport: ", root.size)
	await sample("baseline")
	world.hud.visible = false
	await sample("no_hud")
	var sun: DirectionalLight3D
	for child in world.get_children():
		if child is DirectionalLight3D:
			sun = child
	sun.shadow_enabled = false
	await sample("no_shadows")
	for car in world.cars:
		car.get_node("DetailedBody").visible = false
	await sample("no_cars")
	quit()
