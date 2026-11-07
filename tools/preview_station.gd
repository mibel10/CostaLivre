extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var world = load("res://main.tscn").instantiate()
	root.add_child(world)
	world.start_mode("sandbox")
	world.player.position=Vector3(105,0.3,42)
	world.set_process(false)
	world.camera.position=Vector3(124,17,58)
	world.camera.look_at(Vector3(105,2.5,23))
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/station-preview.png")
	quit()
