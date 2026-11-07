extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world = load("res://main.tscn").instantiate()
	root.add_child(world)
	world.activities.set_menu("pause")
	world.pause_menu.show_page("character")
	for i in 12:
		await process_frame
	assert(world.pause_menu.name_edit.is_visible_in_tree())
	assert(world.pause_menu.outfit_select.item_count==6)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/profile-preview.png")
	quit()
