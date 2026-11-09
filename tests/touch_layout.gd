extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	create_timer(25).timeout.connect(func(): quit(1))
	var world = load("res://main.tscn").instantiate()
	root.add_child(world)
	world.start_mode("sandbox")
	var touch = load("res://scripts/touch_controls.gd").new()
	touch.world = world
	world.hud.get_parent().add_child(touch)
	touch.layout_path = "res://artifacts/touch_layout_test.cfg"
	assert(not touch.visible,"Desktop must not acquire mobile controls")
	for name in touch.icons:
		assert(touch.icons[name] != null,"Every action has a real icon texture")
	touch.start_edit()
	assert(paused)
	var shoot: Rect2
	for entry in touch.buttons():
		assert(entry[0].size.x == entry[0].size.y)
		if entry[2] == "shoot":
			shoot = entry[0]
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.pressed = true
	down.position = touch.ui_offset()+shoot.get_center()*touch.ui_scale()
	touch._input(down)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = touch.ui_offset()+Vector2(850,500)*touch.ui_scale()
	touch._input(drag)
	assert(not Input.is_action_pressed("shoot"),"Editing must never fire a weapon")
	assert(touch.positions.has("shoot"))
	touch.place_control("stick",Vector2(400,500))
	touch.finish_edit(true)
	var positions: Dictionary = touch.positions.duplicate(true)
	touch.positions.clear()
	touch.load_layout()
	assert(touch.positions == positions,"Layout must survive reload")
	touch.start_edit()
	touch.positions.clear()
	touch.finish_edit(false)
	assert(touch.positions == positions,"Cancel restores the previous arrangement")
	touch.place_control("shoot",Vector2(-999,9999))
	var point: Vector2 = touch.positions.shoot*Vector2(1280,720)
	assert(point.x>0 and point.y<720,"Controls remain reachable")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(touch.layout_path))
	world.activities.set_menu("")
	world.queue_free()
	await process_frame
	print("PASS: icon textures, circles, drag without firing, save/reload, cancel and screen bounds")
	quit()
