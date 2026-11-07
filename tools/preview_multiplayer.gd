extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world = load("res://main.tscn").instantiate()
	root.add_child(world)
	for i in 5:
		await process_frame
	world.network.open_menu()
	for i in 10:
		await process_frame
	for node in world.network.panel.find_children("*","Control",true,false):
		if node is Button or node is Label or node is TabContainer:
			print(node.name," visible=",node.is_visible_in_tree()," rect=",node.get_global_rect())
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/multiplayer-preview.png")
	world.network.tabs.current_tab=1
	for i in 10:
		await process_frame
	assert(world.network.panel.get_global_rect().position.y>=0)
	assert(world.network.panel.get_global_rect().end.y<=root.get_visible_rect().size.y)
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/multiplayer-internet-preview.png")
	quit()
