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
	var ui = world.pause_menu
	assert(ui.pages.mode.is_visible_in_tree() and not ui.pause_sidebar.is_visible_in_tree(), "The title does not expose the pause sidebar")
	ui.show_page("character")
	assert(not ui.pause_sidebar.is_visible_in_tree(), "The title's profile page also hides pause controls")
	ui.show_page("mode")
	world.pause_menu.show_campaign_complete()
	assert(ui.pages.ending.is_visible_in_tree() and not ui.pause_sidebar.is_visible_in_tree())
	world.start_mode("sandbox")
	world.activities.set_menu("")
	world.hud.toggle_phone()
	assert(world.hud.phone_panel.position.x>0 and world.hud.phone_panel.position.y>0, "The phone opens centered without flashing in a corner")
	for app in world.hud.phone_apps.get_children():
		assert(app.has_theme_stylebox_override("normal") and app.has_theme_stylebox_override("focus"), "All phone apps share visual and keyboard-focus styles")
	world.hud.toggle_phone()
	var key := InputEventKey.new()
	key.physical_keycode = KEY_Q
	key.pressed = false
	world.activities.weapon = 1
	world.extra.handle_input(key)
	assert(world.activities.weapon == 1 and not world.extra.wheel, "An unmatched Q release does not change weapons")
	world.activities.menu = "jobs"
	key.pressed = true
	world.extra.handle_input(key)
	assert(not world.extra.wheel, "Q does not open a weapon wheel through a menu")
	world.activities.menu = ""
	world.extra.handle_input(key)
	assert(world.extra.wheel and Engine.time_scale < 1)
	world.extra.handle_input(action("pause"))
	assert(not world.extra.wheel and Engine.time_scale == 1, "Escape cancels the wheel and restores game speed")
	world.hud.phone_app("emote_wheel")
	var emote_click := InputEventMouseButton.new()
	emote_click.button_index = MOUSE_BUTTON_LEFT
	emote_click.pressed = true
	emote_click.position = Vector2(640,227) * root.get_visible_rect().size / Vector2(1280,720)
	Input.action_press("shoot")
	world.extra.handle_input(emote_click)
	assert(not world.extra.emote_wheel and world.player.model.emote_lock > 0, "A phone-opened emote wheel accepts a mouse click")
	assert(not Input.is_action_pressed("shoot"), "Choosing an emote does not leave the fire button held")
	world.hud.phone_app("emote_wheel")
	world.extra.handle_input(action("pause"))
	assert(not world.extra.emote_wheel and Engine.time_scale == 1)
	var boarding_car: Node3D = world.spawn_car(Vector3(500,50,500), Color.WHITE)
	world.activities.show_passenger_boarding(boarding_car.position + Vector3.RIGHT * 3, boarding_car.net_id)
	var boarding_actor: Node3D = world.get_child(world.get_child_count() - 1)
	world.cars.erase(boarding_car)
	boarding_car.queue_free()
	for frame in 4:
		await process_frame
	assert(not is_instance_valid(boarding_actor), "Removing a vehicle cancels its passenger boarding visual")
	await physics_frame
	var original_position: Vector3 = world.player.position
	world.player.position = Vector3(500, 0.3, 0)
	var midpoint_on_minimap: Vector2 = world.hud.map_point(world.player.position, Vector2.ZERO, Vector2(164,164))
	assert(is_equal_approx(midpoint_on_minimap.x, 82.0), "Minimap follows the player in the expanded city")
	assert(world.hud.map_point(Vector3(900,0,0), Vector2.ZERO, Vector2(164,164)).x > midpoint_on_minimap.x)
	world.player.position = Vector3(world.MAP_EAST - 30, 0.3, 0)
	assert(world.hud.map_point(world.player.position, Vector2.ZERO, Vector2(164,164)).x > midpoint_on_minimap.x)
	world.player.position = original_position
	var settings = world.settings
	settings.config_path = "user://settings_test.cfg"
	world._unhandled_input(action("pause"))
	assert(paused and ui.pause_sidebar.is_visible_in_tree() and world.activities.menu == "pause")
	ui.show_page("mode")
	assert(ui.pages.mode.is_visible_in_tree() and not ui.pause_sidebar.is_visible_in_tree(), "Switching modes hides pause controls too")
	world._unhandled_input(action("pause"))
	assert(ui.page == "home" and ui.pause_sidebar.is_visible_in_tree() and not ui.pages.mode.is_visible_in_tree())
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
	var map_center := Vector2((world.MAP_EAST - 186.0) * 0.5, 0)
	assert(map.zoom == 1 and map.center == map_center)
	map.zoom_at(2, midpoint)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	map._gui_input(press)
	var drag := InputEventMouseMotion.new()
	drag.relative = Vector2(100, 50)
	map._gui_input(drag)
	assert(map.center != map_center and map.clip_contents)
	press.pressed = false
	map._gui_input(press)
	assert(not map.dragging)
	map.recenter()
	assert(map.center == Vector2(world.player.position.x, world.player.position.z))
	world._unhandled_input(action("pause"))
	assert(paused and ui.page == "home", "Escape from a subpage returns to pause home")
	ui.show_page("graphics")
	var graphics_popup: PopupMenu = ui.quality_select.get_popup()
	if DisplayServer.get_name() != "headless":
		graphics_popup.popup()
		await process_frame
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		graphics_popup.hide()
	else:
		graphics_popup.popup_hide.emit()
	await process_frame
	assert(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE or DisplayServer.get_name() == "headless", "Closing a graphics list restores the menu cursor")
	for quality in 5:
		ui.quality_select.item_selected.emit(quality)
		assert(settings.quality == quality)
		assert(world.camera.far == settings.FAR[quality])
		assert(settings.shadow_quality == [2, 2, 1, 0, 0, 3][quality])
	for index in settings.FPS_LIMITS.size():
		ui.fps_select.item_selected.emit(index)
		assert(Engine.max_fps == settings.FPS_LIMITS[index])
		assert(DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_DISABLED or DisplayServer.get_name() == "headless")
	settings.quality = 0
	settings.fps_limit = 30
	settings.load_settings()
	assert(settings.quality == 4 and settings.fps_limit == 0, "Settings persist including unlimited FPS")
	settings.set_upscaling(2)
	ui.advanced_options["distance"].item_selected.emit(5)
	assert(ui.quality_select.selected == settings.QUALITIES.size(), "A custom draw distance does not select the EXTREMO preset")
	ui.quality_select.item_selected.emit(5)
	assert(not settings.customized and ui.quality_select.selected == 5)
	assert(settings.texture_quality == 0 and settings.shadow_quality == 3 and settings.antialiasing == 3)
	assert(settings.detail_maps and settings.draw_distance == 5 and settings.upscaling == 0 and settings.fps_limit == 0)
	assert(world.camera.far == settings.FAR[5] and root.msaa_3d == Viewport.MSAA_4X)
	var environment: Environment = world.find_children("*", "WorldEnvironment", false, false)[0].environment
	var sea: ShaderMaterial = world.get_node("MarCosta").material_override
	assert(environment.glow_enabled and environment.fog_mode == Environment.FOG_MODE_DEPTH)
	assert(sea.get_shader_parameter("extreme_surface") == true)
	settings.set_quality(0, false)
	assert(not environment.glow_enabled and environment.fog_mode == Environment.FOG_MODE_EXPONENTIAL)
	assert(sea.get_shader_parameter("extreme_surface") == false)
	var old_extreme := ConfigFile.new()
	assert(old_extreme.load(settings.config_path) == OK)
	old_extreme.set_value("video", "textures", 3)
	old_extreme.set_value("video", "shadows", 0)
	old_extreme.set_value("video", "aa", 0)
	old_extreme.set_value("video", "details", false)
	assert(old_extreme.save(settings.config_path) == OK)
	settings.load_settings()
	assert(settings.quality == 5 and settings.texture_quality == 0 and settings.shadow_quality == 3 and settings.antialiasing == 3 and settings.detail_maps)
	var config := ConfigFile.new()
	config.set_value("video", "quality", "invalid")
	config.set_value("video", "fps_limit", 999)
	config.set_value("video", "textures", "invalid")
	config.set_value("video", "window_width", "invalid")
	config.save(settings.config_path)
	settings.load_settings()
	assert(settings.quality == 3 and settings.fps_limit == 30, "Bad configuration falls back safely")
	assert(settings.texture_quality == 3 and settings.window_resolution.x > 0)
	settings.set_quality(3, false)
	var newly_spawned = world.spawn_car(Vector3(42, 0.3, 42), Color.BLUE, false, 1)
	var detail = newly_spawned.get_node("DetailedBody")
	var car_detail_distance: float = minf(settings.NEAR[settings.draw_distance], 12.0)
	assert(detail.get_node("FarBody").visibility_range_begin == car_detail_distance, "New cars inherit the shorter high-performance LOD")
	for child in detail.get_children():
		if child.is_in_group("car_detail"):
			assert(child.visibility_range_end == car_detail_distance)
	settings.set_quality(5, false)
	assert(not detail.get_node("FarBody").visible, "EXTREMO keeps the original car mesh at every distance")
	assert(detail.get_node("FarBody").visibility_range_begin == settings.FAR[5])
	assert(environment.fog_depth_end == world.camera.far, "EXTREMO fog reaches the full render distance")
	for child in detail.get_children():
		if child.is_in_group("car_detail"):
			assert(child.lod_bias == 0.0 and child.visibility_range_end == settings.FAR[5])
	settings.set_quality(3, false)
	assert(detail.get_node("FarBody").visible, "Lower presets restore the distant car mesh")
	var normal_states := {}
	settings.set_quality(0, false)
	for id in settings.tracked:
		var mat: StandardMaterial3D = settings.tracked[id].material.get_ref()
		if mat != null:
			normal_states[id] = mat.normal_enabled
	var temporary_material := StandardMaterial3D.new()
	var temporary_id := temporary_material.get_instance_id()
	settings.register_material(temporary_material)
	temporary_material = null
	settings.set_quality(4, false)
	settings.set_quality(0, false)
	assert(not settings.tracked.has(temporary_id), "A discarded material must not be kept alive by graphics settings")
	for id in normal_states:
		if settings.tracked.has(id):
			assert(settings.tracked[id].material.get_ref().normal_enabled == normal_states[id], "Changing quality restores materials")
	settings.set_quality(3, false)
	settings.set_fps_limit(123, false)
	assert(Engine.max_fps == 30, "Invalid limits are rejected")
	ui.show_page("home")
	world._unhandled_input(action("pause"))
	assert(not paused and not ui.visible)
	assert(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or DisplayServer.get_name() == "headless", "Resuming captures the gameplay cursor")
	world._unhandled_input(action("map"))
	assert(paused and ui.page == "map")
	world._unhandled_input(action("map"))
	assert(not paused and not ui.visible)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(settings.config_path))
	world.activities.set_menu("pause")
	var old_cash: int = world.cash
	assert(ui.admin_entry.is_visible_in_tree())
	ui.admin_entry.pressed.emit()
	await create_timer(0.5).timeout
	assert(ui.page == "admin")
	world.game_mode = "campaign"
	ui.admin_action("cash")
	assert(world.cash == old_cash, "Campaign cannot use the panel even if its page was previously open")
	world.game_mode = "sandbox"
	world.network.peer = ENetMultiplayerPeer.new()
	ui.admin_action("cash")
	assert(world.cash == old_cash, "A pending network connection also blocks admin actions")
	world.network.peer = null
	ui.admin_action("cash")
	assert(world.cash == old_cash + 10000)
	current_scene = world
	world.network.host()
	assert(world.network.peer == null, "Hosting cannot carry over an edited sandbox")
	await process_frame
	await process_frame
	assert(current_scene != world and is_instance_valid(current_scene))
	assert(current_scene.cash == old_cash and current_scene.activities.menu == "mode")
	print("PASS: native pause navigation, zoom/pan, all five graphics levels, all eight frame caps, saving, validation and resume")
	current_scene.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	quit(0)
