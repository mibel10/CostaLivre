extends SceneTree

var rows: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("run")

func sample(world: Node3D, label: String, frames := 180) -> void:
	for i in 45:
		await process_frame
	var values: Array[float] = []
	var previous := Time.get_ticks_usec()
	for i in frames:
		await process_frame
		var now := Time.get_ticks_usec()
		values.append((now - previous) / 1000.0)
		previous = now
	values.sort()
	var sum := 0.0
	for value in values:
		sum += value
	var row := {"scene": label, "quality": world.settings.QUALITIES[world.settings.quality], "cap": Engine.max_fps, "average_fps": snappedf(1000.0 * frames / sum, 0.1), "median_ms": snappedf(values[frames / 2], 0.01), "p95_ms": snappedf(values[int(frames * 0.95)], 0.01), "p99_ms": snappedf(values[int(frames * 0.99)], 0.01), "draws": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
	rows.append(row)
	print(JSON.stringify(row))

func run() -> void:
	var world = load("res://main.tscn").instantiate()
	root.add_child(world)
	world.set_process_unhandled_input(false)
	world.settings.set_quality(3, false)
	world.settings.set_fps_limit(0, false)
	world.camera_yaw = 0
	world.camera_pitch = 0.25
	await sample(world, "rua_sem_limite")
	world.player.position = Vector3(-5, 0.3, 7)
	world.interact()
	Input.action_press("forward")
	await sample(world, "dirigindo_sem_limite")
	Input.action_release("forward")
	world.active_car.speed = 0
	world.interact()
	world.heat = 0
	world.update_dispatch(0)
	world.player.position = world.activities.bank.to_global(Vector3(3, 0, 9))
	await sample(world, "banco_sem_limite")
	world.player.position = Vector3(0, 0.2, 50)
	world.raise_heat(100)
	world.update_dispatch(6)
	world.health = 10000
	world.camera_yaw = PI
	for i in world.cops.size():
		world.cops[i].position = Vector3(-3 + (i % 2) * 6, 0.3, 65 + i * 8)
	await sample(world, "perseguicao_sem_limite")
	world.settings.set_fps_limit(30, false)
	await sample(world, "perseguicao_limitada_30", 240)
	world.heat = 0
	world.update_dispatch(0)
	world.activities.tick_police(1)
	world.player.position = Vector3(-5, 0.2, 12)
	world.camera_yaw = 0
	await sample(world, "rua_limitada_30", 240)
	var output := FileAccess.open("res://benchmark_results.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"viewport": str(root.size), "adapter": RenderingServer.get_video_adapter_name(), "scenes": rows}, "\t"))
	output.close()
	world.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	quit()
