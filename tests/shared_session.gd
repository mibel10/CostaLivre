extends SceneTree
var host
var client
var checkpoint := 0

func _initialize() -> void:
	call_deferred("run")

func wait_for(predicate: Callable, seconds := 12.0) -> void:
	checkpoint+=1
	print("CHECKPOINT ",checkpoint," ",get_stack()[1].line)
	var deadline := Time.get_ticks_msec()+int(seconds*1000)
	while not predicate.call() and Time.get_ticks_msec()<deadline:
		await process_frame
	if not predicate.call():
		push_error("Condition timed out at checkpoint "+str(checkpoint))
		quit(1)

func run() -> void:
	create_timer(180).timeout.connect(func(): push_error("Shared session timed out"); quit(1))
	var host_api := SceneMultiplayer.new()
	var client_api := SceneMultiplayer.new()
	var host_view := SubViewport.new()
	host_view.name="Host"
	host_view.size=Vector2i(1280,720)
	host_view.own_world_3d=true
	root.add_child(host_view)
	var client_view := SubViewport.new()
	client_view.name="Client"
	client_view.size=Vector2i(1280,720)
	client_view.own_world_3d=true
	root.add_child(client_view)
	set_multiplayer(host_api,NodePath("/root/Host/World"))
	set_multiplayer(client_api,NodePath("/root/Client/World"))
	host=load("res://main.tscn").instantiate()
	host.name="World"
	host_view.add_child(host)
	client=load("res://main.tscn").instantiate()
	client.name="World"
	client_view.add_child(client)
	host.network.open_menu()
	host.network.rules.last_actions[999] = 123
	host.network.close_menu()
	assert(host.network.rules.last_actions.has(999), "Closing an idle menu preserves offline gameplay state")
	host.network.rules.last_actions.erase(999)
	host.network.open_menu()
	host.network.host_internet()
	host.network.close_menu()
	assert(host.activities.menu == "mode" and not host.network.active())
	assert(host.network.internet.resolver == IP.RESOLVER_INVALID_ID and host.network.internet.control == null, "Closing the menu cancels room creation")
	host.network.open_menu()
	host.network.connect_target({"relay":"cancelled-room","code":"AB123"})
	var back := InputEventAction.new()
	back.action = "pause"
	back.pressed = true
	host._unhandled_input(back)
	assert(host.activities.menu == "mode" and host.network.relay_target == "", "Closing the menu cancels joining too")
	assert(not host.network.panel.visible)
	assert(host.station.fleet.size()==27)
	var initial_cars: int=host.cars.size()
	if "--relay" in OS.get_cmdline_user_args():
		host.network.host_internet()
		await wait_for(func(): return not host.network.invitation.text.is_empty(), 25.0)
		client.network.address_field.text = host.network.invitation.text
	else:
		host.network.host()
		host_api.connection_failed.emit()
		host.network.host()
		await process_frame
		assert(host.network.active(), "A delayed failure from an old connection cannot close a new room")
		client.network.address_field.text=client.network.make_internet_code("127.0.0.1",28960,host.network.code)
	client.network.join_room()
	await wait_for(func(): return client.network.joined and host.network.members.size()==2, 30.0)
	host.network.close_menu()
	await create_timer(0.4).timeout
	var id: int=client_api.get_unique_id()
	host.fps_counter.refresh()
	client.fps_counter.refresh()
	assert(host.fps_counter.badge.text.contains("Ping: 0 ms"), "The host displays its local ping")
	assert(client.fps_counter.badge.text.contains("Ping: ") and client.fps_counter.badge.text.ends_with(" ms") and not client.fps_counter.badge.text.contains("--"), "The client displays the ENet ping")
	var contact_index := -1
	for i in host.life.people.size():
		if host.life.people[i].stationary and host.life.people[i].hp > 0:
			contact_index = i
			break
	assert(contact_index >= 0, "The test needs a stationary pedestrian")
	var contact: Node3D = host.life.people[contact_index]
	var contact_original: Vector3 = contact.position
	var contact_near: Vector3 = client.player.position + Vector3(8, 0, 0)
	contact.position = contact_near
	await wait_for(func(): return client.life.people[contact_index].position.distance_to(contact_near) < 0.5)
	var synced_contact_position: Vector3 = client.life.people[contact_index].position
	var contact_phase: int = posmod(contact_index + id, 10)
	host.network.snapshot_tick = posmod(contact_phase - 6, 10)
	contact.position = client.player.position + Vector3(66, 0, 0)
	await create_timer(0.35).timeout
	assert(client.life.people[contact_index].position.distance_to(synced_contact_position) < 0.1, "Far pedestrians skip per-tick snapshots")
	var contact_returned: Vector3 = client.player.position + Vector3(12, 0, 0)
	contact.position = contact_returned
	await wait_for(func(): return client.life.people[contact_index].position.distance_to(contact_returned) < 0.5)
	contact.position = contact_original
	client.life.people[contact_index].position = contact_original
	print("PASS: pedestrian relevancy follows the receiving player")
	var distant: Node3D = host.spawn_car(Vector3(500, 0.2, 500), Color.WHITE)
	var distant_id: int = distant.net_id
	await wait_for(func(): return client.car_by_id(distant_id) != null)
	await create_timer(0.3).timeout
	assert(client.car_by_id(distant_id) != null, "Partial snapshots preserve distant cars")
	distant.position = Vector3(510, 0.2, 500)
	await wait_for(func(): return client.car_by_id(distant_id) != null and client.car_by_id(distant_id).position.distance_to(distant.position) < 1.0)
	host.cars.erase(distant)
	distant.queue_free()
	await wait_for(func(): return client.car_by_id(distant_id) == null)
	print("PASS: distant car creation, partial snapshots, refresh and removal")
	assert(host.player.position!=client.player.position,"Different spawn points")
	assert(host.network.rules.sheets.has(id))
	var rules: Node = host.network.rules
	rules.sheets[id]["prison_stage"] = 0
	rules.propose_mission(1, 27)
	assert(rules.pending_mission == -1, "A prisoner cannot be invited to co-op")
	rules.sheets[id].erase("prison_stage")
	rules.propose_mission(1, 27)
	assert(rules.mission_invites.has(id))
	rules.sheets[id]["prison_stage"] = 0
	rules.tick_mission_offer()
	assert(rules.pending_mission == -1 and rules.mission_invites.is_empty(), "An unavailable partner does not hold the invitation open")
	rules.sheets[id].erase("prison_stage")
	var farther_car: Node3D = host.cars[0]
	var farther_position: Vector3 = farther_car.position
	var farther_hp: float = farther_car.hp
	var punch_car: Node3D = host.cars[1]
	var punch_car_position: Vector3 = punch_car.position
	var punch_player_position: Vector3 = host.player.position
	var punch_car_hp: float = punch_car.hp
	punch_car.position = Vector3(900, 50, 900)
	farther_car.position = punch_car.position + Vector3(0, 0, -0.4)
	host.player.position = punch_car.position + Vector3(0, 0, 2)
	rules.punch_peer(1, 0.0)
	assert(punch_car.hp == punch_car_hp - 25, "Host applies punch damage to vehicles")
	assert(rules.wanted_heat(1) > 0.0 and rules.wanted_heat(id) == 0.0, "The innocent client does not inherit the host's wanted level")
	assert(farther_car.hp == farther_hp, "Host hits the closest target first")
	host.camera_yaw = 0.42
	host.extra.punch()
	assert(is_equal_approx(host.player.model.rotation.y, host.camera_yaw), "Multiplayer punch faces the camera")
	assert(host.extra.audio.stream == host.extra.sounds.punch, "Multiplayer punch plays its sound")
	host.extra.punch_time = 0
	host.camera_yaw = 0
	await wait_for(func(): return client.car_by_id(punch_car.net_id).hp == punch_car.hp)
	punch_car.position = punch_car_position
	farther_car.position = farther_position
	host.player.position = punch_player_position
	rules.clear_wanted()
	var inventory: Dictionary = rules.sheets[id].inventory
	var saved_inventory := inventory.duplicate(true)
	var host_ammo: int = host.activities.clips[1]
	inventory.clips[1] = 3
	inventory.reserves[1] = 8
	inventory.reload_weapon = 1
	inventory.reload_time = 0.25
	rules.tick_inventory(id, 0.25)
	assert(inventory.clips[1] == 11 and inventory.reserves[1] == 0 and host.activities.clips[1] == host_ammo)
	rules.sheets[id].inventory = saved_inventory
	var walker: Node3D
	for person in host.life.people:
		if not person.stationary and not person.robbed and person.hp > 0:
			walker = person
			break
	assert(walker != null, "The test needs an interactable pedestrian")
	var walker_position := walker.position
	walker.position = host.player.position
	Input.action_press("activity")
	host.activities.tick_pedestrian_robbery(0.1)
	assert(walker.scared)
	rules.robbery_worker = 1
	Input.action_release("activity")
	rules.physics(0.0)
	assert(not walker.scared and host.activities.pedestrian_target == null)
	walker.position = walker_position
	var observer := Node3D.new()
	rules.visible_police[observer] = id
	observer.free()
	rules.police_sight_clock = 0.2
	rules.physics(0.0)
	rules.clear_wanted()
	host.raise_heat(50, 1)
	rules.sheets[1]["wanted_grace"] = 0.0
	host.raise_heat(50, id)
	assert(rules.police_target_actor(host.player.position, id)[0] == id, "A dispatched patrol keeps its assigned target")
	host.response_delay = 60.0
	rules.physics(0.1)
	assert(rules.wanted_heat(1) < 50.0 and rules.wanted_heat(id) == 50.0, "A second player's crime cannot stop the first player's wanted decay")
	rules.clear_wanted()
	host.raise_heat(100, 1)
	host.raise_heat(100, id)
	host.response_delay = 0
	host.station.dispatch(0)
	assert(host.cops.size() == 14, "Two five-star targets use fourteen cars")
	for peer in [1,id]:
		assert(host.cops.filter(func(car): return car.get_meta("police_target_peer") == peer).size() == 7)
	rules.clear_wanted()
	host.station.dispatch(0)
	assert(host.cops.is_empty())
	for car in host.station.fleet:
		car.position = car.police_home
		car.police_phase = "parked"
		car.speed = 0
		car.velocity = Vector3.ZERO
	assert(host.life.people.size() == 171 and client.life.people.size() == 171)
	assert(host.life.get_node("Predio16NPC0").position == client.life.get_node("Predio16NPC0").position)
	var resident_index: int = host.life.people.size()-1
	host.life.people[resident_index].take_hit(10)
	await wait_for(func(): return client.life.people[resident_index].hp == 50)
	rules.clear_wanted()
	host.update_dispatch(0)
	var theft: Dictionary=host.network.members[id].duplicate()
	theft.car=1
	theft.car_position=host.car_by_id(1).position
	host.network.accept_state(id,theft)
	assert(not host.network.owners.has(1), "Reports cannot claim a car without server approval")
	var steal_car: Node3D = client.car_by_id(1)
	steal_car.position = host.car_by_id(1).position
	client.player.position = steal_car.position+Vector3(2.6,0.3,0)
	# Seed the host position for this test-only teleport.
	host.network.members[id].car_position = client.player.position
	host.network.members[id].erase("elevator_target_until")
	await create_timer(0.25).timeout
	client.network.rules.send_action("vehicle_entry",{"car":1})
	await wait_for(func(): return client.active_car == steal_car)
	assert(host.car_by_id(1).owned and host.heat>=12)
	var theft_heat: float=host.heat
	host.network.accept_state(id,theft)
	assert(is_equal_approx(host.heat,theft_heat),"No repeat theft alert")
	client.interact()
	await create_timer(0.4).timeout
	client.raise_heat(50)
	await wait_for(func(): return client.heat>40 and host.heat>40)
	assert(rules.wanted_heat(id) > 40 and rules.wanted_heat(1) == 0, "The innocent host does not inherit the client's crimes")
	assert(client.network.rules.wanted_heat(id) > 40 and client.network.rules.wanted_heat(1) == 0, "Personal wanted levels replicate")
	host.update_dispatch(6)
	assert(host.cops.size()>=2 and host.cars.size()==initial_cars)
	assert(host.cops.all(func(car): return car.get_meta("police_target_peer") == id), "Police cars pursue only the player who committed the crime")
	await create_timer(2.8).timeout
	assert(host.station.fleet.any(func(car): return car.position.z>car.police_home.z+4))
	for car in host.station.fleet:
		assert(car.position.y<4,"Police stays on the ground")
	rules.clear_wanted()
	host.update_dispatch(0)
	await create_timer(0.3).timeout
	const RESCUE_JOB := 13
	client.activities.start_job(RESCUE_JOB)
	await wait_for(func(): return host.activities.job==RESCUE_JOB and client.activities.job==RESCUE_JOB and is_instance_valid(client.activities.target_car))
	host.cutscene.finish()
	client.cutscene.finish()
	var rescue_car: Node = client.activities.target_car
	client.player.position = rescue_car.position+Vector3(2.6,0.3,0)
	# Seed the host position for this test-only teleport.
	host.network.members[id].car_position = client.player.position
	host.network.members[id].erase("elevator_target_until")
	await create_timer(0.25).timeout
	client.interact()
	await wait_for(func(): return client.active_car == rescue_car)
	assert(client.active_car == rescue_car)
	rescue_car.position = client.activities.ACTION_JOBS[RESCUE_JOB].pickup+Vector3.UP*0.3
	# Seed the host position for this test-only vehicle teleport.
	host.network.members[id].car_position = rescue_car.position
	rescue_car.speed = 0
	await create_timer(0.4).timeout
	client.network.rules.send_action("interact",{})
	await wait_for(func(): return client.activities.stage == 1 and client.activities.passenger_car == rescue_car.net_id)
	rescue_car.position = client.activities.ACTION_JOBS[RESCUE_JOB].drop+Vector3.UP*0.3
	# Seed the host position for this test-only vehicle teleport.
	host.network.members[id].car_position = rescue_car.position
	rescue_car.speed = 0
	await wait_for(func(): return host.activities.job==-1 and client.activities.job==-1)
	assert(client.cash>=900+host.activities.REWARDS[RESCUE_JOB],"Cooperative reward")
	host.network.rules.sheets[id].protected_until=0
	var cash: int=host.cash
	host.network.rules.damage_peer(id,200,1)
	assert(host.cash==cash+1500)
	host.network.rules.damage_peer(id,200,1)
	assert(host.cash==cash+1500,"No duplicate kill reward")
	await wait_for(func(): return client.health<=0)
	host.network.rules.sheets[id].dead_until=Time.get_ticks_msec()-1
	await wait_for(func(): return client.health>0)
	assert(host.SPAWNS.any(func(at): return at.distance_to(client.player.position)<2))
	host.network.rules.sheets[id].cash+=85000
	await create_timer(0.2).timeout
	client.player.position=client.activities.DEALER+Vector3(0,0.3,0)
	# Seed the host position for this test-only teleport.
	host.network.members[id].car_position = client.player.position
	host.network.members[id].erase("elevator_target_until")
	await create_timer(0.3).timeout
	var count: int=host.cars.size()
	client.activities.set_menu("cars")
	for page in 3:
		client.activities.turn_menu_page(1)
	var dealer_cash: int = client.cash
	client.activities.buy(1)
	await wait_for(func(): return host.cars.size()==count+1 and client.cars.size()==host.cars.size())
	var purchase: Node=client.car_by_id(host.cars[-1].net_id)
	assert(purchase!=null and purchase.owned and purchase.tier == client.activities.Catalog.SUPERCAR, "The host buys the model chosen on the fourth page")
	assert(host.network.rules.sheets[id].cash == dealer_cash - client.activities.CAR_PRICES.back())
	client.activities.set_menu("")
	client.player.position=purchase.position+Vector3(2.6,0.3,0)
	# Seed the host position for this test-only teleport.
	host.network.members[id].car_position = client.player.position
	host.network.members[id].erase("elevator_target_until")
	await create_timer(0.25).timeout
	client.interact()
	await wait_for(func(): return client.active_car == purchase)
	assert(client.active_car==purchase)
	client.active_car.position=client.activities.GARAGE+Vector3(0,0.2,0)
	# Seed the host position for this test-only vehicle teleport.
	host.network.members[id].car_position = client.active_car.position
	await create_timer(0.3).timeout
	var paint: Color=purchase.paint
	client.activities.set_menu("garage")
	client.activities.buy(1)
	await wait_for(func(): return purchase.paint!=paint and host.car_by_id(purchase.net_id).paint==purchase.paint)
	rules.clear_wanted()
	host.update_dispatch(0)
	client.network.rules.receive_event("spawn",{"position":Vector3(0,0.3,-5)})
	host.network.members[id].car_position = client.player.position
	host.player.position=Vector3(0,0.3,0)
	await create_timer(0.4).timeout
	host.network.rules.sheets[1].protected_until=0
	host.health=100
	host.network.rules.sheets[1].health=100
	var client_cash: int=host.network.rules.sheets[id].cash
	for shot in 3:
		host.network.rules.fire_peer(id,{"origin":Vector3(0,1.6,-3),"direction":Vector3(0,0,1),"weapon":1})
		await create_timer(0.4).timeout
	assert(host.health<=0,"Remote shot hits host")
	assert(host.network.rules.sheets[id].cash==client_cash+1500,"Remote killer receives reward")
	host.network.rules.sheets[1].dead_until=Time.get_ticks_msec()-1
	await wait_for(func(): return host.health>0)
	rules.clear_wanted()
	host.update_dispatch(0)
	host.network.rules.sheets[id].health=100.0
	client.activities.set_menu("")
	host.activities.bank.phase=1
	client.player.position=client.activities.bank.to_global(client.activities.bank.TERMINAL)+Vector3(1,0.2,0)
	# Seed the host position for this test-only teleport.
	host.network.members[id].car_position = client.player.position
	host.network.members[id].erase("elevator_target_until")
	await create_timer(0.3).timeout
	client.network.rules.send_action("interact",{})
	await wait_for(func(): return client.activities.bank.local_hacking())
	assert(not host.activities.bank.local_hacking())
	for round_index in 3:
		host.activities.bank.reveal_time=0
		var pattern: Array=host.activities.bank.pattern.duplicate()
		for digit in pattern:
			client.network.rules.send_action("digit", {"digit": digit})
		await wait_for(func(): return host.activities.bank.round_index > round_index or host.activities.bank.phase >= 2)
	await wait_for(func(): return client.activities.bank.phase==2)
	client.player.position=client.activities.bank.to_global(client.activities.bank.VAULT_PANEL)+Vector3(1,0.2,0)
	# Seed the host position for this test-only teleport.
	host.network.members[id].car_position = client.player.position
	host.network.members[id].erase("elevator_target_until")
	await create_timer(0.3).timeout
	client.network.rules.send_action("interact",{})
	await wait_for(func(): return host.activities.bank.phase==3)
	assert(is_equal_approx(rules.export_state().bank_door_angle, host.activities.bank.door.rotation.y), "Snapshots carry the actual vault door angle")
	await wait_for(func(): return is_equal_approx(client.activities.bank.door.rotation.y, PI / 2))
	for bag in client.activities.bank.BAGS:
		client.player.position=client.activities.bank.to_global(bag)+Vector3(1,0.2,0)
		# Seed the host position for this test-only teleport.
		host.network.members[id].car_position = client.player.position
		host.network.members[id].erase("elevator_target_until")
		await create_timer(0.3).timeout
		client.network.rules.send_action("interact",{})
		await create_timer(0.2).timeout
	await wait_for(func(): return host.activities.bank.phase==4)
	client.player.position=client.activities.bank.to_global(client.activities.bank.ENTRY)+Vector3(0,0.2,1)
	# Seed the host position for this test-only teleport.
	host.network.members[id].car_position = client.player.position
	host.network.members[id].erase("elevator_target_until")
	await wait_for(func(): return client.activities.bank.phase==5)
	host.cutscene.finish()
	client.cutscene.finish()
	rules.clear_wanted()
	host.update_dispatch(0)
	host.network.rules.sheets[id].protected_until = Time.get_ticks_msec()+15000
	host.network.rules.sheets[id].cash = 50000
	client.player.position = client.activities.HEAVY_SHOP + Vector3.UP*0.3
	# Seed the host position for this test-only teleport.
	host.network.members[id].car_position = client.player.position
	host.network.members[id].erase("elevator_target_until")
	await wait_for(func(): return host.network.avatars[id].node.position.distance_to(host.activities.HEAVY_SHOP)<1)
	var before_weapon: int = host.network.rules.sheets[id].inventory.weapon
	host.network.rules.fire_peer(id,{"origin":client.player.position+Vector3.UP,"direction":Vector3.FORWARD,"weapon":7})
	assert(host.network.rules.sheets[id].inventory.weapon == before_weapon, "Reject firing a heavy weapon not owned")
	for choice in 3:
		client.activities.set_menu("heavy_guns")
		client.activities.buy(choice)
		await create_timer(0.4).timeout
		await wait_for(func(): return client.activities.heavy_owned[choice])
		assert(host.network.rules.sheets[id].inventory.heavy_owned[choice])
	assert(host.network.rules.sheets[id].cash == 13500, "Heavy purchases charge the buyer")
	client.player.position = Vector3(0,0.3,0)
	# Seed the host position for this test-only teleport.
	host.network.members[id].car_position = client.player.position
	host.network.members[id].erase("elevator_target_until")
	await create_timer(0.3).timeout
	var remaining: int = host.network.rules.sheets[id].cash
	client.activities.set_menu("heavy_guns")
	client.activities.buy(0)
	await create_timer(0.3).timeout
	assert(host.network.rules.sheets[id].cash == remaining, "Reject remote purchase away from shop")
	client.activities.set_menu("")
	client.player.position = client.activities.SUPPLY_PICKUP + Vector3.UP * 0.3
	# Seed the host position for this test-only teleport.
	host.network.members[id].car_position = client.player.position
	host.network.members[id].erase("elevator_target_until")
	await wait_for(func(): return host.network.members[id].position.distance_to(host.activities.SUPPLY_PICKUP) < 2)
	await wait_for(func(): return host.network.avatars[id].node.position.distance_to(host.activities.SUPPLY_PICKUP) < 2)
	client.network.rules.send_action("interact", {})
	await wait_for(func(): return host.activities.supply_stage == 1)
	client.player.position = client.activities.SUPPLY_ALLEY + Vector3.UP * 0.3
	# Seed the host position for this test-only teleport.
	host.network.members[id].car_position = client.player.position
	host.network.members[id].erase("elevator_target_until")
	await wait_for(func(): return client.cutscene.active)
	assert(client.cutscene.duration_msec == 30000 and not host.cutscene.active, "Only the delivery owner sees the full cinematic")
	client.cutscene.finish()
	await wait_for(func(): return host.activities.supply_stage == 3)
	await wait_for(func(): return host.network.avatars[id].node.position.distance_to(host.activities.SUPPLY_ALLEY) < 2)
	client.network.rules.send_action("interact", {})
	await wait_for(func(): return host.activities.supply_stage == 4)
	host.network.rules.damage_peer(id, 200, 0, true)
	assert(host.network.rules.sheets[id].get("prison_stage", -1) == 0, "Police death assigns prison on the host")
	await wait_for(func(): return not host.network.rules.is_dead(id) and client.player.position.distance_to(client.PRISON_SPAWN) < 3, 8.0)
	assert(host.network.rules.sheets[1].get("prison_stage", -1) == -1, "Other players remain free")
	for step in client.PRISON_POINTS.size():
		client.player.position = client.PRISON_POINTS[step] + Vector3.UP * 0.3
		# Seed the host position for this test-only teleport.
		host.network.members[id].car_position = client.player.position
		host.network.members[id].erase("elevator_target_until")
		await wait_for(func(): return host.network.members[id].position.distance_to(client.PRISON_POINTS[step]) < 2)
		if step == 1:
			Input.action_press("crouch")
			await wait_for(func(): return bool(host.network.members[id].get("crouch", false)))
		if step in [2, 4]:
			host.tick_prison(id, host.network.rules.position_of(id), true, 11.0)
		else:
			client.network.rules.send_action("prison_step", {})
		var expected: int = step + 1 if step + 1 < client.PRISON_POINTS.size() else -1
		await wait_for(func(): return int(host.network.rules.sheets[id].get("prison_stage", -2)) == expected)
		if step == 1: Input.action_release("crouch")
	await wait_for(func(): return client.player.position.z > 76)
	assert(client.player.position.z > 76, "Escape releases the correct player")
	host.active_car = null
	host.player.position = Vector3(0, 0.3, 84)
	host.health = 100
	host.network.rules.sheets[1].health = 100
	var hover_car = host.spawn_car(Vector3(0, 4, 84), Color.WHITE, false, 11)
	hover_car.hovering = true
	host.network.owners[hover_car.net_id] = id
	host.network.members[id].car = hover_car.net_id
	host.network.rules.action(id, "hover_mode", {})
	assert(host.health == 100 and not hover_car.hovering, "The victim is safe until the car descends")
	host.network.apply_car(id, {"car": hover_car.net_id, "car_position": Vector3(0, 2, 84), "car_heading": 0.0, "speed": 0.0})
	assert(host.health == 0 and not host.network.rules.is_dead(id), "The host detects the remote driver's descending car and spares the driver")
	# Five-round PvP restores equipment and awards only the winning team.
	host.network.owners.clear()
	host.network.members[id].car = -1
	host.health = 100.0
	host.network.rules.sheets[1].health = 100.0
	host.network.rules.sheets[id].health = 100.0
	host.activities.job = -1
	host.activities.bank.phase = 0
	host.network.rules.pending_mission = -1
	var pvp_rules = host.network.rules
	var cash_before: int = host.cash
	var weapon_before: int = host.activities.weapon
	pvp_rules.join_pvp(1)
	pvp_rules.join_pvp(id)
	pvp_rules.tick_pvp(13.0)
	assert(pvp_rules.pvp.teams.size() == 2 and pvp_rules.pvp.round == 1)
	await wait_for(func(): return not client.network.rules.pvp.is_empty())
	assert(client.activities.rifle_owned and client.activities.clips[2] == 30)
	pvp_rules.sheets[1]["stand"] = 3
	pvp_rules.use_stand(1,0.0)
	await wait_for(func(): return client.network.rules.remote_stand_walls.size() == 1)
	assert(pvp_rules.sheets[1].stand_cooldown > 0.0)
	var objects_before: int = pvp_rules.stand_objects.size()
	pvp_rules.use_stand(1,0.0)
	assert(pvp_rules.stand_objects.size() == objects_before, "The host enforces Stand cooldown")
	var barrier = pvp_rules.stand_objects[0]
	var barrier_body = barrier.get_child(0).get_child(0)
	for shot in 4: host.activities.weapon_impact({"collider":barrier_body},barrier.position,2)
	await wait_for(func(): return client.network.rules.remote_stand_walls.is_empty())


	for round_index in 5:
		assert(pvp_rules.pvp.round == round_index + 1)
		assert(int(pvp_rules.sheets[id].stand) in range(5))
		pvp_rules.sheets[id].protected_until = 0
		pvp_rules.damage_peer(id,100.0,1)
		assert(pvp_rules.is_dead(id))
		pvp_rules.tick_pvp(0.1)
		if round_index < 4: pvp_rules.tick_pvp(5.0)
	assert(pvp_rules.pvp.is_empty() and host.cash == cash_before + 2500)
	assert(host.activities.weapon == weapon_before and not pvp_rules.is_dead(id))
	print("PASS: five PvP arenas, random Stands, loadouts, rounds, reward and restoration")
	var partner = await add_arena_client("Partner")
	var opponent = await add_arena_client("Opponent")
	await wait_for(func(): return host.network.members.size() == 4)
	var partner_id: int = partner.multiplayer.get_unique_id()
	var opponent_id: int = opponent.multiplayer.get_unique_id()
	pvp_rules.join_pvp(1)
	pvp_rules.join_pvp(id)
	pvp_rules.join_pvp(partner_id)
	pvp_rules.join_pvp(opponent_id)
	pvp_rules.tick_pvp(13.0)
	assert(pvp_rules.pvp.teams.size() == 4)
	pvp_rules.sheets[partner_id].protected_until = 0
	pvp_rules.damage_peer(partner_id,100.0,1)
	assert(pvp_rules.sheets[partner_id].health == 100.0, "Friendly fire is blocked")
	pvp_rules.sheets[id].protected_until = 0
	pvp_rules.damage_peer(id,100.0,1)
	pvp_rules.tick_pvp(0.1)
	assert(pvp_rules.pvp.round == 1 and pvp_rules.pvp.phase == "fight", "A living teammate keeps the round running")
	pvp_rules.sheets[opponent_id].protected_until = 0
	pvp_rules.damage_peer(opponent_id,100.0,1)
	pvp_rules.tick_pvp(0.1)
	assert(pvp_rules.pvp.scores[0] == 1 and pvp_rules.pvp.phase == "break")
	pvp_rules.tick_pvp(5.0)
	opponent.network.disconnect_room()
	await wait_for(func(): return host.network.members.size() == 3)
	partner.network.disconnect_room()
	await wait_for(func(): return host.network.members.size() == 2)
	pvp_rules.tick_pvp(0.1)
	assert(pvp_rules.pvp.teams.size() == 2, "Disconnected players leave the active teams")
	pvp_rules.finish_pvp(-1)
	partner.queue_free()
	opponent.queue_free()
	print("PASS: four connected peers form 2v2, team eliminations, friendly fire and disconnect cleanup")

	client.network.disconnect_room()
	await wait_for(func(): return host.network.members.size()==1)
	client.network.announced_version="old-build"
	client.network.address_field.text = host.network.invitation.text if "--relay" in OS.get_cmdline_user_args() else client.network.make_internet_code("127.0.0.1",28960,host.network.code)
	client.network.join_room()
	await wait_for(func(): return host.network.refusal_reason.contains("Versoes diferentes") and client.network.peer == null, 30.0)
	assert(not client.network.joined and host.network.members.size()==1,"Reject incompatible builds")
	host.network.disconnect_room()
	client.network.disconnect_room()
	host.queue_free()
	client.queue_free()
	await process_frame
	print("PASS: version rejection, police fleet, coop mission, PvP both directions, respawn, car purchase, garage, bank hack and bags")
	quit()

func add_arena_client(label: String) -> Node:
	var view := SubViewport.new()
	view.name = label
	view.size = Vector2i(1280,720)
	view.own_world_3d = true
	root.add_child(view)
	set_multiplayer(SceneMultiplayer.new(),NodePath("/root/"+label+"/World"))
	var game = load("res://main.tscn").instantiate()
	game.name = "World"
	view.add_child(game)
	game.network.address_field.text = host.network.invitation.text if "--relay" in OS.get_cmdline_user_args() else game.network.make_internet_code("127.0.0.1",28960,host.network.code)
	game.network.join_room()
	await wait_for(func(): return game.network.joined, 30.0)
	return game
