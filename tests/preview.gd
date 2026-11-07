extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world = load("res://main.tscn").instantiate()
	root.add_child(world)
	world.start_mode("sandbox")
	world.set_process_unhandled_input(false)
	world.camera_yaw = 0
	world.camera_pitch = 0.25
	for frame in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://preview.png")
	for menu in ["jobs", "guns", "cars", "map"]:
		world.activities.set_menu(menu)
		world.hud.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://preview_" + menu + ".png")
	world.activities.set_menu("")
	var bank = world.activities.bank
	world.player.position = bank.to_global(Vector3(0, 0.1, 12))
	world.camera_pitch = 0.12
	for frame in 25:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://preview_bank.png")
	world.player.position = bank.to_global(bank.BREAKER)
	bank.interact()
	world.player.position = bank.to_global(bank.TERMINAL)
	bank.interact()
	for frame in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://preview_hack.png")
	bank.hacking = false
	world.hud.queue_redraw()
	world.set_process(false)
	var car = world.cars[0]
	world.camera.position = car.position + Vector3(4.6, 2.5, 5.6)
	world.camera.look_at(car.position + Vector3(0, 0.7, 0))
	for frame in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://preview_vehicle.png")
	var start := Time.get_ticks_msec()
	for frame in 30:
		await process_frame
	print("Preview FPS: ", 30000.0 / maxf(1, Time.get_ticks_msec() - start))
	print("Preview saved")
	quit()
