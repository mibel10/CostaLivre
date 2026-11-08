extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func action(name: String) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = true
	return event

func run() -> void:
	create_timer(25).timeout.connect(func(): quit(1))
	var world = load("res://main.tscn").instantiate()
	root.add_child(world)
	world.start_mode("sandbox")
	await physics_frame
	var original_position: Vector3 = world.player.position
	world.player.position = Vector3(500, 0.3, 0)
	var midpoint_on_minimap: Vector2 = world.hud.map_point(world.player.position, Vector2.ZERO, Vector2(164,164))
	assert(is_equal_approx(midpoint_on_minimap.x, 82.0), "Minimap follows the player in the expanded city")
	assert(world.hud.map_point(Vector3(900,0,0), Vector2.ZERO, Vector2(164,164)).x > midpoint_on_minimap.x)
	world.player.position = Vector3(920, 0.3, 0)
	assert(world.hud.map_point(world.player.position, Vector2.ZERO, Vector2(164,164)).x > midpoint_on_minimap.x)
	world.player.position = original_position
	var settings = world.settings
	settings.config_path = "user://settings_test.cfg"
	var ui = world.pause_menu
	world._unhandled_input(action("pause"))
	assert(paused and ui.visible and world.activities.menu == "pause")
	var time_before: float = world.elapsed
	world._physics_process(2)
	assert(world.elapsed == time_before)
	ui.show_page("map")
	var map = ui.map_view
	await process_frame
	await process_frame
	assert(map.inspected_label == "", "Map starts without point labels")
	var hover := InputEventMouseMotion.new()
	hover.position = map.project(world.activities.GUN_SHOP)
	map._gui_input(hover)
	await process_frame
	await process_frame
	assert(map.inspected_label == "Arsenal", "Desktop hover shows one point name")
	var tap := InputEventScreenTouch.new()
	tap.pressed = true
	tap.position = map.project(world.activities.DEALER)
	map._gui_input(tap)
	await process_frame
	await process_frame
	assert(map.inspected_label == "APEX", "Touch selects the point name")
	assert(map.factor() > map.size.y/1130.0, "Initial map uses more screen space")
	var midpoint: Vector2 = map.size / 2
	map.zoom_at(100, midpoint)
	assert(map.zoom == 6)
	map.zoom_at(0.001, midpoint)
	assert(map.zoom == 1 and map.center == Vector2(376, 0))
	map.zoom_at(2, midpoint)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	map._gui_input(press)
	var drag := InputEventMouseMotion.new()
	drag.relative = Vector2(100, 50)
	map._gui_input(drag)
	assert(map.center != Vector2(376, 0) and map.clip_contents)
	press.pressed = false
	map._gui_input(press)
	assert(not map.dragging)
	map.recenter()
	assert(map.center == Vector2(world.player.position.x, world.player.position.z))
	world._unhandled_input(action("pause"))
	assert(paused and ui.page == "home", "Escape from a subpage returns to pause home")
	ui.show_page("graphics")
	for quality in 5:
		ui.quality_select.item_selected.emit(quality)
		assert(settings.quality == quality)
		assert(world.camera.far == settings.FAR[quality])
	for index in settings.FPS_LIMITS.size():
		ui.fps_select.item_selected.emit(index)
		assert(Engine.max_fps == settings.FPS_LIMITS[index])
		assert(DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_DISABLED or DisplayServer.get_name() == "headless")
	settings.quality = 0
	settings.fps_limit = 30
	settings.load_settings()
	assert(settings.quality == 4 and settings.fps_limit == 0, "Settings persist including unlimited FPS")
	var config := ConfigFile.new()
	config.set_value("video", "quality", "invalid")
	config.set_value("video", "fps_limit", 999)
	config.save(settings.config_path)
	settings.load_settings()
	assert(settings.quality == 3 and settings.fps_limit == 30, "Bad configuration falls back safely")
	settings.set_quality(3, false)
	var newly_spawned = world.spawn_car(Vector3(42, 0.3, 42), Color.BLUE, false, 1)
	var detail = newly_spawned.get_node("DetailedBody")
	assert(detail.get_node("FarBody").visibility_range_begin == settings.NEAR[3], "New cars inherit graphics settings")
	for child in detail.get_children():
		if child.is_in_group("car_detail"):
			assert(child.visibility_range_end == settings.NEAR[3])
	var normal_states: Array[bool] = []
	settings.set_quality(0, false)
	for mat in settings.tracked:
		normal_states.append(mat.normal_enabled)
	settings.set_quality(4, false)
	settings.set_quality(0, false)
	var state_index := 0
	for mat in settings.tracked:
		assert(mat.normal_enabled == normal_states[state_index], "Changing quality restores materials")
		state_index += 1
	settings.set_quality(3, false)
	settings.set_fps_limit(123, false)
	assert(Engine.max_fps == 30, "Invalid limits are rejected")
	ui.show_page("home")
	world._unhandled_input(action("pause"))
	assert(not paused and not ui.visible)
	world._unhandled_input(action("map"))
	assert(paused and ui.page == "map")
	world._unhandled_input(action("map"))
	assert(not paused and not ui.visible)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(settings.config_path))
	print("PASS: native pause navigation, zoom/pan, all five graphics levels, all eight frame caps, saving, validation and resume")
	world.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	quit(0)
