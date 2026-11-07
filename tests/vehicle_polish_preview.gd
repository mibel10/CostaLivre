extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world = load("res://main.tscn").instantiate()
	root.add_child(world)
	world.start_mode("sandbox")
	world.settings.set_quality(3,false)
	world.set_process(false)
	world.set_process_unhandled_input(false)
	world.hud.visible = false
	world.fps_counter.badge.visible = false
	world.fps_counter.set_process(false)
	var car = world.cars[0]
	for item in [["rear",Vector3(4,2,5)],["front",Vector3(-4,1.7,-5)],["side",Vector3(5,1,0)]]:
		world.camera.position = car.position + item[1]
		world.camera.look_at(car.position + Vector3(0,0.65,0))
		for i in 18:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://preview_car_"+item[0]+".png")
	world.camera.position = world.player.position+Vector3(2.5,1.6,-3)
	world.camera.look_at(world.player.position+Vector3(0,1,0))
	for i in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://preview_player_polish.png")
	world.queue_free()
	await process_frame
	await create_timer(0.3).timeout
	quit()
