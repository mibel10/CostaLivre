extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world = load("res://main.tscn").instantiate()
	root.add_child(world)
	world.start_mode("sandbox")
	assert(world.life.rooms.size() == 22)
	world.player.position=world.life.elevator_position("apartment",0)
	world.life.use_elevator(9)
	await create_timer(1.1,true).timeout
	assert(world.player.position.y > 53.7 and world.life.inside_room(world.player.position))
	for job in [7,9,10,11,12,13,14,15,16]:
		world.activities.start_job(job)
		world.cutscene.finish()
		for stage in 3:
			world.player.position = world.life.mission_position()+Vector3(1.2,0.1,0)
			Input.action_press("activity")
			world.life.tick_tasks(world.life.BUILDING_TASK_DURATION+0.1)
			Input.action_release("activity")
		assert(world.activities.job == -1)
		world.cutscene.finish()
	var touch = load("res://scripts/touch_controls.gd").new()
	touch.world = world
	root.add_child(touch)
	var previous: float = touch.control_radius("map")
	touch.selected_button = "shoot"
	touch.resize_selected(0.2)
	assert(is_equal_approx(previous,touch.control_radius("map")))
	touch.queue_free()
	world.queue_free()
	await process_frame
	await create_timer(0.25).timeout
	print("PASS: ten floors, elevator, nine interior missions, independent touch sizes")
	quit()
