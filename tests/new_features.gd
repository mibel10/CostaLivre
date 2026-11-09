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
	assert(world.activities.JOBS.size() == 30)
	var car = world.cars[0]
	world.player.position = car.position + Vector3(-2,0,0)
	world.interact()
	await create_timer(2.15).timeout
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
	world.activities.shotgun_owned = true
	world.activities.smg_owned = true
	var weapon_key := InputEventKey.new()
	weapon_key.pressed = true
	weapon_key.physical_keycode = KEY_4
	assert(world.activities.handle_input(weapon_key) and world.activities.weapon == 3)
	weapon_key.physical_keycode = KEY_5
	assert(world.activities.handle_input(weapon_key) and world.activities.weapon == 4)
	const SIGNAL_JOB := 11
	world.activities.start_job(SIGNAL_JOB)
	world.cutscene.finish()
	world.active_car = null
	var signal_job: Dictionary = world.activities.ACTION_JOBS[SIGNAL_JOB]
	for index in signal_job.points.size():
		var transmitter: Node = world.get_node("ObjetivosCampanha/Alvo11_%d" % index)
		world.activities.weapon_impact({"collider": transmitter}, signal_job.points[index], 1)
	world.player.position = signal_job.exit
	world.heat = 0.0
	world.activities.tick_mission(0.1)
	assert(world.activities.job == -1, "Indoor contract completes")
	world.cutscene.finish()
	world.finish(false)
	assert(Engine.time_scale == 0.18 and extra.death_filter.visible)
	world.queue_free()
	await process_frame
	assert(Engine.time_scale == 1)
	await create_timer(0.2).timeout
	print("PASS: contracts, moving exit, punch damage and animation, weapon wheel, indoor missions, defeat filter and time reset")
	quit()
