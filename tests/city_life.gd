extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	create_timer(30).timeout.connect(func(): quit(1))
	var world = load("res://main.tscn").instantiate()
	root.add_child(world)
	world.start_mode("sandbox")
	world.set_process(false)
	assert(world.life.rooms.size() == 22 and world.life.people.size() == 148)
	assert(world.cars.filter(func(car): return car.traffic and car.position.x > 200).size() == 16)
	assert(world.life.people.filter(func(person): return person.position.x > 200 and not person.stationary and not person.shopper).size() == 36)
	var lobby_counts := {}
	for person in world.life.people:
		if person.has_meta("building_center"):
			var center: Vector3 = person.get_meta("building_center")
			lobby_counts[center] = int(lobby_counts.get(center,0))+1
	assert(lobby_counts.size() == 17)
	for count in lobby_counts.values(): assert(count == 3, "Three NPCs per large enterable building")
	await physics_frame
	for side in [-1, 1]:
		for step in 5:
			var x := 344.0 + step * 1.2
			var ground := (x - 294.0) * 10.0 / 56.0 - 0.1
			var from := Vector3(x, ground + 1, side * 31.0)
			var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 2, 1))
			assert(not hit.is_empty() and absf(hit.position.y - ground) < 0.02, "Favela steps must not block the walking ramp")
	var ped = world.life.people[0]
	world.player.position = ped.position + Vector3(2,0,0)
	world.life._process(1)
	var before: Vector3 = ped.position
	for i in 30:
		await physics_frame
	assert(ped.position.distance_to(before) > 0.3, "Pedestrians walk along their sidewalk routes")
	world.player.position = Vector3(0,0.2,12)
	for i in 40:
		await physics_frame
	before = world.player.position
	assert(world.player.start_roll())
	assert(world.player.roll_time > 0)
	for i in 65:
		await physics_frame
	assert(world.player.roll_time == 0 and world.player.model.rotation.x == 0)
	assert(world.player.position.distance_to(before) > 10, "Roll moves player and resets visual pose")
	for room in world.life.rooms:
		if room.position.y > 0:
			continue
		var query := PhysicsRayQueryParameters3D.create(room.to_global(Vector3(0,1,15)),room.to_global(Vector3(0,1,8)),1)
		assert(world.get_world_3d().direct_space_state.intersect_ray(query).is_empty(), "New interiors have real entrances")
	for index in range(13,17):
		if world.activities.ACTION_JOBS.has(index): continue
		world.activities.start_job(index)
		world.cutscene.finish()
		for step in 3:
			world.player.position = world.life.mission_position()
			Input.action_press("activity")
			world.life.tick_tasks(world.life.BUILDING_TASK_DURATION+0.1)
			Input.action_release("activity")
		assert(world.activities.job == -1)
		world.cutscene.finish()
	world.activities.set_menu("jobs")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_RIGHT
	key.pressed = true
	world.activities.handle_input(key)
	world.activities.handle_input(key)
	assert(world.activities.job_page == 2)
	world.activities.handle_input(key)
	assert(world.activities.job_page == 3)
	world.activities.handle_input(key)
	assert(world.activities.job_page == 0)
	world.activities.set_menu("")
	for store in 2:
		for cashier in 5:
			assert(world.life.get_node("Mercado%dCaixa%d" % [store,cashier]).stationary)
		for customer in 8:
			assert(world.life.get_node("Mercado%dCliente%d" % [store,customer]).route.size() > 5)
	world.player.position = world.activities.ROBBERIES[3]
	var cash_before: int = world.cash
	Input.action_press("activity")
	world.activities.tick_robbery(5.1)
	Input.action_release("activity")
	assert(world.cash == cash_before+1200 and world.activities.robbery_cooldowns[3] > 0)
	print("PASS: walking pedestrians, animated roll, six accessible interiors, campaign contracts and four job pages")
	world.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	quit(0)
