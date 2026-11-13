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
	assert(world.activities.JOBS.size() == 34)
	var car = world.cars[0]
	world.player.position = car.position + Vector3(-2,0,0)
	world.interact()
	await create_timer(2.15).timeout
	car.speed = 25
	world.interact()
	assert(world.active_car == null and world.player.visible)
	await create_timer(0.4).timeout
	car.speed = 0
	var moving: Node3D = world.spawn_car(Vector3(150,0.3,12),Color.BLUE,false,1)
	moving.traffic = true
	moving.speed = 9.0
	world.player.position = moving.position + Vector3.LEFT * 2.5
	world.interact()
	await create_timer(0.31).timeout
	assert(world.active_car == null and moving.get_node("DetailedBody/EntryDoor/Left").rotation.y < -0.1)
	await create_timer(0.33).timeout
	var falls := get_nodes_in_group("ejected_driver")
	assert(falls.size() == 1 and world.active_car == null)
	var bones := falls[0].find_children("*","PhysicalBone3D",true,false)
	assert(bones.size() >= 10 and bones.all(func(bone): return bone.get_bone_id() >= 0))
	await create_timer(0.5).timeout
	assert(world.active_car == moving and not moving.traffic)
	moving.speed = 0
	moving.position = Vector3(900, 50, 900)
	world.interact()
	await create_timer(0.4).timeout
	await create_timer(1.1).timeout
	assert(get_nodes_in_group("ejected_driver").is_empty())
	world.player.position = Vector3(900,50,900)
	world.camera_yaw = 0
	var farther = world.spawn_car(Vector3(900,50,897.6), Color.BLUE)
	var target = world.spawn_car(Vector3(900,50,898), Color.RED)
	extra.punch()
	assert(target.hp == target.MAX_HP-25 and extra.punch_time > 0)
	assert(farther.hp == farther.MAX_HP, "Punch hits the closest target first")
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
	var stand_rules = world.network.rules
	world.player.position = Vector3(0,0.3,0)
	var stand_target = load("res://scripts/pedestrian.gd").new()
	stand_target.world = world
	stand_target.stationary = true
	world.life.add_child(stand_target)
	world.life.people.append(stand_target)
	await process_frame
	stand_target.position = Vector3(0,0.3,-3.0)
	stand_target.hp = 150.0
	stand_rules.offline_stand.stand = 0
	stand_rules.offline_stand.stand_cooldown = 0.0
	stand_rules.use_stand(1,0.0)
	assert(is_equal_approx(stand_target.hp,60.0) and stand_target.position.z < -3.0, "Concrete Hand hits hard and knocks nearby targets back")
	assert(stand_rules.offline_stand.stand_cooldown == stand_rules.STAND_COOLDOWNS[0])
	stand_target.position = Vector3(0,0.3,24)
	world.player.position = Vector3(0,0.3,0)
	world.health = 60.0
	stand_rules.offline_stand.stand = 1
	stand_rules.offline_stand.stand_cooldown = 0.0
	stand_rules.stand_history[1] = []
	for sample in 21: stand_rules.stand_history[1].append(Vector3(4,0.3,0))
	stand_rules.use_stand(1,0.0)
	assert(world.player.position.is_equal_approx(Vector3(4,0.3,0)) and world.health == 80.0 and stand_rules.offline_stand.stand_slow == 0.0, "Reverse Step rewinds safely, heals and clears slow")
	world.player.position = Vector3(0,0.3,0)
	stand_target.position = Vector3(0,0.3,-4.0)
	stand_rules.offline_stand.stand = 2
	stand_rules.offline_stand.stand_cooldown = 0.0
	stand_rules.stand_fields.clear()
	stand_rules.use_stand(1,0.0)
	assert(stand_rules.stand_fields.size() == 1 and stand_rules.stand_fields[0].time == 5.0, "Closed Signal holds a large control zone")
	stand_rules.tick_stands(0.05)
	assert(stand_target.get_meta("stand_slow_until",0) > Time.get_ticks_msec(), "Closed Signal slows NPCs inside the zone")
	stand_rules.offline_stand.stand = 3
	stand_rules.offline_stand.stand_cooldown = 0.0
	stand_rules.use_stand(1,0.0)
	var barrier: Node3D = stand_rules.stand_objects.filter(func(object): return int(object.get_meta("stand_kind",-1)) == 3)[0]
	assert(barrier.get_meta("health") == stand_rules.STAND_WALL_HEALTH and stand_rules.STAND_WALL_HEALTH > 4*world.activities.DAMAGE[2], "Shattered Display is durable cover")
	var barrier_body = barrier.get_child(0).get_child(0)
	for shot in 4: world.activities.weapon_impact({"collider":barrier_body},barrier.position,2)
	assert(stand_rules.stand_objects.has(barrier), "Shattered Display withstands four rifle hits")
	world.activities.weapon_impact({"collider":barrier_body},barrier.position,2)
	assert(not stand_rules.stand_objects.has(barrier), "Gunfire eventually shatters the cover")
	await process_frame
	stand_target.position = Vector3(0,0.3,-8.0)
	stand_target.hp = 150.0
	stand_rules.offline_stand.stand = 4
	stand_rules.offline_stand.stand_cooldown = 0.0
	stand_rules.stand_fields.clear()
	stand_rules.use_stand(1,0.0)
	assert(is_equal_approx(stand_target.hp,110.0) and stand_target.position.z < -8.0, "Low Tide sweeps a wide arc, damages and pushes targets")
	assert(stand_rules.stand_fields.size() == 1 and stand_rules.stand_fields[0].kind == 4, "Low Tide leaves a short stagger pulse")
	stand_rules.tick_stands(0.05)
	assert(stand_target.get_meta("stand_slow_until",0) > Time.get_ticks_msec(), "Low Tide staggers NPCs")
	print("PASS: each Stand ability, cooldown, healing, crowd control, cover and knockback works offline")
	world.finish(false)
	assert(Engine.time_scale == 0.18 and extra.death_filter.visible)
	world.queue_free()
	await process_frame
	assert(Engine.time_scale == 1)
	await create_timer(0.2).timeout
	print("PASS: contracts, moving exit, punch damage and animation, weapon wheel, indoor missions, defeat filter and time reset")
	quit()
