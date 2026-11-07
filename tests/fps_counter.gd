extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world = load("res://main.tscn").instantiate()
	root.add_child(world)
	world.start_mode("sandbox")
	world.settings.config_path = "user://fps_counter_test.cfg"
	for corner in 4:
		world.settings.set_fps_corner(corner)
		var label: Label = world.fps_counter.badge
		assert(label.visible)
		var bounds := root.get_visible_rect().size
		assert((label.position.x > bounds.x/2) == (corner in [1,3]))
		assert((label.position.y > bounds.y/2) == (corner in [2,3]))
	world.settings.fps_corner = -1
	world.settings.load_settings()
	assert(world.settings.fps_corner == 3)
	world.settings.set_fps_corner(-1,false)
	assert(not world.fps_counter.badge.visible)
	world.settings.set_fps_corner(99,false)
	assert(world.settings.fps_corner == -1)
	world.activities.set_menu("pause")
	world.pause_menu.counter_select.item_selected.emit(2)
	assert(world.settings.fps_corner == 1 and world.fps_counter.badge.visible)
	world.activities.set_menu("")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(world.settings.config_path))
	print("PASS: all four FPS corners, hidden option, persistence and native menu selection")
	world.queue_free()
	await process_frame
	await create_timer(0.25).timeout
	quit()
