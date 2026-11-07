extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	create_timer(25).timeout.connect(func(): quit(1))
	var world = load("res://main.tscn").instantiate()
	root.add_child(world)
	world.start_mode("sandbox")
	await physics_frame
	var extra = world.extra
	assert(world.activities.JOBS.size() == 20)
	var car = world.cars[0]
	world.player.position = car.position + Vector3(-2,0,0)
	world.interact()
	await create_timer(0.4).timeout
	car.speed = 25
	world.interact()
	assert(world.active_car == null and world.player.visible)
	await create_timer(0.4).timeout
	car.speed = 0
	world.player.position = Vector3(126,0,12)
	world.camera_yaw = 0
	var target = world.spawn_car(Vector3(126,0,10), Color.RED)
	extra.punch()
	assert(target.hp == target.MAX_HP-25 and extra.punch_time > 0)
	extra._process(0.1)
	assert(extra.punch_arm.visible and extra.punch_arm.position.z < -0.3)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_Q
	key.pressed = true
	extra.handle_input(key)
	assert(extra.wheel and Engine.time_scale == 0.2)
	extra.selection = 1
	key.pressed = false
	extra.handle_input(key)
	assert(not extra.wheel and Engine.time_scale == 1 and world.activities.weapon == 1)
	for index in range(7,13):
		world.activities.start_job(index)
		world.cutscene.finish()
		world.active_car = null
		for stage in 3:
			var destination: Vector3 = world.activities.destination()
			world.player.position = destination
			if index == 8:
				world.activities.tick_mission(0.1)
			else:
				Input.action_press("activity")
				world.life.tick_tasks(world.life.BUILDING_TASK_DURATION+0.1)
				Input.action_release("activity")
		assert(world.activities.job == -1, "Contract completes")
		world.cutscene.finish()
	world.finish(false)
	assert(Engine.time_scale == 0.18 and extra.death_filter.visible)
	world.queue_free()
	await process_frame
	assert(Engine.time_scale == 1)
	await create_timer(0.2).timeout
	print("PASS: contracts, moving exit, punch damage and animation, weapon wheel, indoor missions, defeat filter and time reset")
	quit()
