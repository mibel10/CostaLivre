extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://preview_" + name + ".png")

func run() -> void:
	var world = load("res://main.tscn").instantiate()
	root.add_child(world)
	world.start_mode("sandbox")
	world.set_process_unhandled_input(false)
	for i in 30:
		await process_frame
	world.extra.wheel = true
	world.hud.queue_redraw()
	await capture("wheel")
	world.extra.wheel = false
	world.finish(false)
	for i in 45:
		await process_frame
	await capture("defeat")
	world.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	quit()
