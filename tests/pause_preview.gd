extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func capture(name: String) -> void:
	await process_frame
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
	world.activities.set_menu("pause")
	await capture("pause")
	world.pause_menu.show_page("graphics")
	await capture("graphics")
	world.pause_menu.fps_select.show_popup()
	await capture("fps_options")
	world.pause_menu.fps_select.get_popup().hide()
	world.pause_menu.show_page("map")
	await capture("map")
	world.pause_menu.map_view.zoom_at(3, world.pause_menu.map_view.size / 2)
	await capture("map_zoom")
	world.pause_menu.resume()
	world.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	print("Pause, graphics, FPS options and zoom map previews saved")
	quit()
