extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world = load("res://main.tscn").instantiate()
	root.add_child(world)
	world.start_mode("sandbox")
	world.settings.set_quality(3,false)
	world.set_process(false)
	world.set_physics_process(false)
	world.hud.visible = false
	world.fps_counter.visible = false
	world.player.visible = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/fleet"))
	for tier in range(4,10):
		var car = world.spawn_car(Vector3(0,0.2,84),Color("d59042"),false,tier)
		car.set_physics_process(false)
		if tier == 9:
			car.rider.visible = true
		world.camera.position = car.position+Vector3(4,2.2,-5)
		world.camera.look_at(car.position+Vector3(0,0.8,0))
		for frame in 18:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/fleet/model_"+str(tier)+".png")
		world.cars.erase(car)
		car.queue_free()
		await process_frame
	world.queue_free()
	await process_frame
	quit()
