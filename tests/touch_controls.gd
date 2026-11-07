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
	world.queue_free()
	await process_frame
	await create_timer(0.25).timeout
	print("PASS: Android-only UI, analog movement, held fire release and touch contract navigation")
	quit()
