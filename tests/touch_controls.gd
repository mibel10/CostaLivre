extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world = load("res://main.tscn").instantiate()
	root.add_child(world)
	world.start_mode("sandbox")
	var touch = load("res://scripts/touch_controls.gd").new()
	touch.world = world
	world.hud.get_parent().add_child(touch)
	assert(not touch.visible, "Desktop never shows mobile controls")
	touch.move_stick(Vector2(180,440))
	assert(Input.is_action_pressed("forward"))
	touch.fingers[0] = "stick"
	touch.release_all()
	assert(not Input.is_action_pressed("forward"))
	touch.action("shoot",true)
	await process_frame
	assert(Input.is_action_pressed("shoot"))
	touch.fingers[1] = "shoot"
	touch.release_all()
	await process_frame
	assert(not Input.is_action_pressed("shoot"))
	world.activities.set_menu("jobs")
	assert(touch.buttons().size() == 10, "Contracts have numeric and pagination controls")
	world.activities.set_menu("")
	world.activities.weapon = 0
	touch.action("weapon", true)
	assert(world.extra.wheel and touch.context() == "weapon_wheel")
	var tap := InputEventScreenTouch.new()
	tap.pressed = true
	tap.position = Vector2(734, 266) * root.get_visible_rect().size / Vector2(1280, 720)
	touch._input(tap)
	assert(world.activities.weapon == 1 and not world.extra.wheel, "Tapping the pistol equips it and closes the wheel")
	world.queue_free()
	await process_frame
	await create_timer(0.25).timeout
	print("PASS: Android-only UI, analog movement, held fire release, touch contract navigation and weapon wheel")
	quit()
