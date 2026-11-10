extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	create_timer(30).timeout.connect(func(): quit(1))
	var world = load("res://main.tscn").instantiate()
	root.add_child(world)
	world.start_mode("sandbox")
	world.set_process(false)
	await physics_frame
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var road := PhysicsRayQueryParameters3D.create(Vector3(930,1,0), Vector3(946,1,0), 1)
	assert(space.intersect_ray(road).is_empty(), "The east extension connects to the city")
	var extension_ground := PhysicsRayQueryParameters3D.create(Vector3(1000,3,0), Vector3(1000,-2,0), 1)
	assert(not space.intersect_ray(extension_ground).is_empty(), "The new road has solid ground")
	var gate := PhysicsRayQueryParameters3D.create(Vector3(1035,1,80), Vector3(1035,1,70), 1)
	assert(space.intersect_ray(gate).is_empty(), "The prison entrance is accessible")
	world.player.set_physics_process(false)
	var prison_route := [
		Vector3(1012, 0.08, 40), Vector3(1012, 0.08, 59.3), Vector3(1012, 0.08, 63.8),
		Vector3(1035, 0.08, 63.8), Vector3(1035, 0.08, 60), Vector3(1035, 0.08, 65),
		Vector3(1052, 0.08, 65), Vector3(1035, 0.08, 65), Vector3(1035, 0.08, 48), Vector3(1035, 0.08, 73),
	]
	for index in range(prison_route.size() - 1):
		world.player.position = prison_route[index]
		world.player.set_crouched(index == 1)
		await physics_frame
		assert(world.player.move_and_collide(prison_route[index + 1] - prison_route[index], true) == null, "The player can take the actual route between prison objectives")
	var alley := PhysicsRayQueryParameters3D.create(Vector3(405,11,1), Vector3(405,11,29), 1)
	assert(space.intersect_ray(alley).is_empty(), "The alley connects both streets")
	world.player.set_physics_process(false)
	world.player.position = Vector3(147, 0, 47.5)
	world.player.set_crouched(true)
	await physics_frame
	assert(world.player.move_and_collide(Vector3(0, 0, 13)) == null, "Crouching crosses the entire Data Center duct")
	assert(world.player.move_and_collide(Vector3(0, 0, -13)) == null, "The duct can be used to escape by the same route")
	world.player.set_crouched(false)
	var standing_hit = world.player.move_and_collide(Vector3(0, 0, 13))
	assert(standing_hit != null and standing_hit.get_collider().name == "Teto", "Standing is blocked by the duct roof")
	world.player.position = Vector3(0, 0.2, 12)
	world.player.set_physics_process(true)
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
	var former_hill := PhysicsRayQueryParameters3D.create(Vector3(378, 16, 25), Vector3(378, -1, 25), 1)
	var park: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(former_hill)
	assert(not park.is_empty() and park.collider.name == "Gramado" and park.position.y < 0.2, "The former favela is a flat park")
	for side in [-1, 1]:
		for sample in 10:
			var z := 18.2 + sample * 0.55
			var height := lerpf(9.88, 7.68, (z - 18.0) / 5.8)
			var from := Vector3(1241, height + 0.5, z * side)
			var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN, 1))
			assert(not hit.is_empty() and absf(hit.position.y - height) < 0.04, "Both stepped alleys connect their landings without gaps")
	world.player.set_physics_process(false)
	world.player.position = Vector3(1207, 9.91, 13.45)
	assert(world.player.move_and_collide(Vector3(6, 0, 0), true) != null, "A house annex forces a turn in the alley")
	world.player.position.z = 14.0
	assert(world.player.move_and_collide(Vector3(6, 0, 0), true) == null, "The bend leaves room to walk past the house")
	world.player.position = Vector3(1218, 9.91, 13.45)
	assert(world.player.move_and_collide(Vector3(6, 0, 0), true) != null, "Standing cannot pass under the low roof")
	world.player.set_crouched(true)
	await physics_frame
	assert(world.player.move_and_collide(Vector3(6, 0, 0), true) == null, "Crouching crosses the alley formed by the houses")
	world.player.set_crouched(false)
	world.player.set_physics_process(true)
	world.player.position = Vector3(23, 0, 32.5)
	var original_quality: int = world.settings.quality
	world.settings.quality = 0
	world.life._process(1)
	var simulated: Array = world.life.people.filter(func(person): return person.is_physics_processing())
	world.settings.quality = 4
	world.life._process(1)
	assert(simulated.size() > 10 and simulated == world.life.people.filter(func(person): return person.is_physics_processing()), "Graphics quality cannot change which pedestrians the game simulates")
	world.settings.quality = original_quality
	var contact: CharacterBody3D = world.life.people[world.life.building_contacts.keys()[0]]
	world.player.position = contact.position + Vector3(0, 0, 45)
	var crowd: Array = world.life.people.filter(func(person): return not person.stationary).slice(0, 24)
	var original_positions := []
	for person in crowd:
		original_positions.append(person.position)
		person.position = world.player.position + Vector3.RIGHT * 5.0
	world.life._process(1)
	assert(contact.visible and not contact.is_physics_processing(), "Nearby contacts stay visible even with all walking slots full")
	for i in crowd.size():
		crowd[i].position = original_positions[i]
	var ped = world.life.people[3]
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
	assert(world.life.building_contacts.size() == 21)
	var office := -1
	var cafe := -1
	for index: int in world.life.building_contacts:
		var npc: CharacterBody3D = world.life.people[index]
		assert(npc.stationary and world.life.building_contact_at(npc.position) == index)
		match world.life.building_contacts[index][0]:
			"office": office = index
			"cafe": cafe = index
		if world.life.building_contacts[index][0] in ["office","bank"]:
			for step in 3:
				var stop: Vector3 = world.life.building_destination({"contact":index,"step":step})
				var ray := PhysicsRayQueryParameters3D.create(stop+Vector3.UP*2,stop-Vector3.UP,1)
				var surface: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(ray)
				assert(not surface.is_empty() and absf(surface.position.y-stop.y) < 0.25, "Delivery point must sit on walkable ground: %s" % stop)
	var activity := InputEventAction.new()
	activity.action = "activity"
	activity.pressed = true
	world.player.position = world.life.people[cafe].position + Vector3.BACK
	world.health = 50
	var before_purchase: int = world.cash
	assert(world.activities.handle_input(activity) and world.activities.menu == "building_contact")
	world.life.building_choice.pressed.emit()
	assert(world.cash == before_purchase-20 and world.health == 65)
	world.player.position = world.life.people[office].position + Vector3.BACK
	assert(world.activities.handle_input(activity) and world.activities.menu == "building_contact")
	world.life.building_choice.pressed.emit()
	var delivery: Dictionary = world.life.offline_building_job
	assert(delivery.step == 0 and is_equal_approx(delivery.remaining,60))
	for step in 3:
		world.player.position = world.life.building_destination(delivery)
		assert(world.activities.handle_input(activity))
	assert(delivery.is_empty() and world.cash == before_purchase+180)
	world.player.position = world.life.people[office].position + Vector3.BACK
	assert(world.activities.handle_input(activity) and world.activities.menu == "building_contact")
	world.life.building_choice.pressed.emit()
	assert(world.life.tick_building_job(1,60.1) and delivery.is_empty())
	assert(world.cash == before_purchase+180, "Expired deliveries do not pay")
	var entrance := Vector3(294, 0.3, -83)
	world.heat = 0.0
	world.check_vehicle_entry(entrance + Vector3.BACK, entrance)
	assert(world.heat == 0.0, "The supermarket entrance is still outside")
	world.check_vehicle_entry(entrance, entrance + Vector3.FORWARD)
	assert(world.heat == 60.0, "Driving across the threshold gives three stars")
	world.heat = 20.0
	world.check_vehicle_entry(entrance + Vector3.FORWARD, entrance + Vector3.FORWARD * 2)
	assert(world.heat == 20.0, "Movement inside does not renew wanted level")
	world.heat = 80.0
	world.check_vehicle_entry(entrance, entrance + Vector3.FORWARD)
	assert(world.heat == 80.0, "Entry preserves a higher wanted level")
	world.heat = 0.0
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
	print("PASS: existing contacts, purchase, repeatable delivery, city pedestrians and campaign contracts")
	world.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	quit(0)
