extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world = load("res://main.tscn").instantiate()
	root.add_child(world)
	world.start_mode("sandbox")
	world.set_process_unhandled_input(false)
	world.player.position = world.activities.bank.to_global(Vector3(3,0,9))
	world.camera_yaw = 0.35
	world.camera_pitch = 0.14
	for i in 35:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://preview_bank_redesign.png")
	world.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	quit()
