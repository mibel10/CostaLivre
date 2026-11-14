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
	world.atmosphere_cycle.storm_remaining = 60.0
	await process_frame
	assert(world.atmosphere_cycle.storm>0.9 and world.atmosphere_cycle.flooded(Vector3(0,0.3,84)))
	assert(world.atmosphere_cycle.flooded(Vector3(1260,0.3,126)), "Flooding reaches the far east")
	assert(world.atmosphere_cycle.DAY_LENGTH_SECONDS == 600.0, "Day and night each last five minutes")
	assert(not world.atmosphere_cycle.flooded(Vector3(0,6,84)), "Flooding does not affect upper floors")
	for sample in 500:
		var at := Vector3(-160+sample*3.1,0.3,-135+posmod(sample*37,270))
		var expected := false
		for region in world.atmosphere_cycle.flood_regions:
			if region.has_point(Vector2(at.x,at.z)): expected = true
		assert(world.atmosphere_cycle.flooded(at) == expected, "Fast flood detection matches the rendered road grid")
	world.player.position = world.activities.GARAGE
	world.atmosphere_cycle.shelter_check = 0.0
	world.atmosphere_cycle._process(0.01)
	assert(world.atmosphere_cycle.sheltered and not world.atmosphere_cycle.rain.emitting, "The workshop roof shelters the player from rain")
	world.atmosphere_cycle.storm_remaining = 0.0
	await process_frame
	assert(not world.atmosphere_cycle.flooded(Vector3(0,0.3,84)), "Floods recede after the storm")
	for shot in 65: world.extra.battle_impact(world.player.position+Vector3(0,1,1))
	assert(world.extra.battle_marks.size()<=48, "Battle marks have a fixed mobile-safe limit")
	world.player.position = Vector3(900,50,900)
	world.extra.battle_impact(Vector3(900,51,900))
	assert(world.extra.battle_marks.is_empty(), "Gunshots into empty air do not leave floating marks")
	var impact_wall := Node3D.new()
	world.add_child(impact_wall)
	impact_wall.position = Vector3(900,50,898)
	world.box(impact_wall,Vector3(0,1,0),Vector3(3,3,0.2),Color.GRAY,true)
	await physics_frame
	await physics_frame
	world.extra.battle_impact(Vector3(900,51,898.1),Vector3.FORWARD)
	assert(world.extra.battle_marks.size() == 1 and world.extra.battle_marks[0].get_parent() != world, "Impact marks attach to the surface they hit")
	impact_wall.queue_free()
	await process_frame
	world.extra.battle_impact(Vector3(900,51,900))
	stand_target.react_to_threat()
	assert(stand_target.reaction_time>0 and stand_target.model.animation.current_animation == "Flinch")
	world.player.model.play_emote("torture_dance")
	assert(world.player.model.animation.get_animation("GoldenWind").length == 8.0)
	world.player.model._process(5.25)
	assert(world.player.model.rig.rotation.y>PI, "Torture Dance includes the spin")
	world.player.model._process(3.0)
	assert(is_equal_approx(world.player.model.rig.rotation.y,PI))
	world.activities.job = world.activities.SECRET_DATA_JOB
	world.activities.stage = 1
	world.activities.spawn_infiltration_sentinels()
	world.player.position = Vector3(147,0.3,42)
	stand_rules.create_distraction(1)
	assert(world.activities.officers.any(func(guard): return int(guard.get_meta("distraction_until",0))>Time.get_ticks_msec()), "Distraction attracts sentinels")
	world.activities.job = -1
	for clue in stand_rules.CALADO_CLUES:
		world.player.position = clue
		stand_rules.investigate_calado(1)
	assert(stand_rules.offline_stand.calado_clues == 7)
	world.player.position = world.life.HAUNTED_HOUSE
	var mystery_cash: int = world.cash
	stand_rules.investigate_calado(1)
	assert(stand_rules.offline_stand.calado_done and world.cash == mystery_cash+1500)
	stand_rules.investigate_calado(1)
	assert(world.cash == mystery_cash+1500, "Mystery reward cannot be claimed twice")
	world.cutscene.finish()
	print("PASS: storm, floods, bounded battle marks, NPC reaction, Torture Dance, distraction and solo Calado mystery")
	world.finish(false)
	assert(Engine.time_scale == 0.18 and extra.death_filter.visible)
	world.queue_free()
	await process_frame
	assert(Engine.time_scale == 1)
	await create_timer(0.2).timeout
	print("PASS: contracts, moving exit, punch damage and animation, weapon wheel, indoor missions, defeat filter and time reset")
	quit()
