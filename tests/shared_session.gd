extends SceneTree
var host
var client
var checkpoint := 0

func _initialize() -> void:
	call_deferred("run")

func wait_for(predicate: Callable, seconds := 5.0) -> void:
	checkpoint+=1
	print("CHECKPOINT ",checkpoint)
	var deadline := Time.get_ticks_msec()+int(seconds*1000)
	while not predicate.call() and Time.get_ticks_msec()<deadline:
		await process_frame
	if not predicate.call():
		push_error("Condition timed out at checkpoint "+str(checkpoint))
		quit(1)

func run() -> void:
	create_timer(80).timeout.connect(func(): push_error("Shared session timed out"); quit(1))
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
	assert(host.station.fleet.size()==27)
	var initial_cars: int=host.cars.size()
	host.network.host()
	client.network.address_field.text=client.network.make_internet_code("127.0.0.1",28960,host.network.code)
	client.network.join_room()
	await wait_for(func(): return client.network.joined and host.network.members.size()==2)
	await create_timer(0.4).timeout
	var id: int=client_api.get_unique_id()
	assert(host.player.position!=client.player.position,"Different spawn points")
	assert(host.network.rules.sheets.has(id))
	var rules: Node = host.network.rules
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
	assert(farther_car.hp == farther_hp, "Host hits the closest target first")
	await wait_for(func(): return client.car_by_id(punch_car.net_id).hp == punch_car.hp)
	punch_car.position = punch_car_position
	farther_car.position = farther_position
	host.player.position = punch_player_position
	host.heat = 0
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
	rules.visible_police.append(observer)
	observer.free()
	rules.police_sight_clock = 0.2
	rules.physics(0.0)
	host.heat = 100
	host.response_delay = 0
	host.station.dispatch(0)
	assert(host.cops.size() == 14, "Two five-star targets use fourteen cars")
	for peer in [1,id]:
		assert(host.cops.filter(func(car): return car.get_meta("police_target_peer") == peer).size() == 7)
	host.heat = 0
	host.station.dispatch(0)
	assert(host.cops.is_empty())
	for car in host.station.fleet:
		car.position = car.police_home
		car.police_phase = "parked"
		car.speed = 0
		car.velocity = Vector3.ZERO
	assert(host.life.people.size() == 148 and client.life.people.size() == 148)
	assert(host.life.get_node("Predio16NPC0").position == client.life.get_node("Predio16NPC0").position)
	var resident_index: int = host.life.people.size()-1
	host.life.people[resident_index].take_hit(10)
	await wait_for(func(): return client.life.people[resident_index].hp == 50)
	host.heat = 0
	host.update_dispatch(0)
	var theft: Dictionary=host.network.members[id].duplicate()
	theft.car=1
	theft.car_position=host.car_by_id(1).position
	host.network.accept_state(id,theft)
	assert(not host.network.owners.has(1), "Reports cannot claim a car without server approval")
	var steal_car: Node3D = client.car_by_id(1)
	client.player.position = steal_car.position+Vector3(2.6,0.3,0)
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
	host.update_dispatch(6)
	assert(host.cops.size()>=2 and host.cars.size()==initial_cars)
	await create_timer(2.8).timeout
	assert(host.station.fleet.any(func(car): return car.position.z>car.police_home.z+4))
	for car in host.station.fleet:
		assert(car.position.y<4,"Police stays on the ground")
	host.heat=0
	host.update_dispatch(0)
	await create_timer(0.3).timeout
	const RESCUE_JOB := 13
	client.activities.start_job(RESCUE_JOB)
	await wait_for(func(): return host.activities.job==RESCUE_JOB and client.activities.job==RESCUE_JOB and is_instance_valid(client.activities.target_car))
	host.cutscene.finish()
	client.cutscene.finish()
	var rescue_car: Node = client.activities.target_car
	client.player.position = rescue_car.position+Vector3(2.6,0.3,0)
	await create_timer(0.25).timeout
	client.interact()
	await create_timer(2.35).timeout
	assert(client.active_car == rescue_car)
	rescue_car.position = client.activities.ACTION_JOBS[RESCUE_JOB].pickup+Vector3.UP*0.3
	rescue_car.speed = 0
	await create_timer(0.4).timeout
	client.network.rules.send_action("interact",{})
	await wait_for(func(): return client.activities.stage == 1 and client.activities.passenger_car == rescue_car.net_id)
	rescue_car.position = client.activities.ACTION_JOBS[RESCUE_JOB].drop+Vector3.UP*0.3
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
	host.network.rules.sheets[id].cash+=6000
	await create_timer(0.2).timeout
	client.player.position=client.activities.DEALER+Vector3(0,0.3,0)
	await create_timer(0.3).timeout
	var count: int=host.cars.size()
	client.activities.set_menu("cars")
	client.activities.buy(0)
	await wait_for(func(): return host.cars.size()==count+1 and client.cars.size()==host.cars.size())
	var purchase: Node=client.car_by_id(host.cars[-1].net_id)
	assert(purchase!=null and purchase.owned)
	client.activities.set_menu("")
	client.player.position=purchase.position+Vector3(2.6,0.3,0)
	await create_timer(0.25).timeout
	client.interact()
	await create_timer(2.35).timeout
	assert(client.active_car==purchase)
	client.active_car.position=client.activities.GARAGE+Vector3(0,0.2,0)
	await create_timer(0.3).timeout
	var paint: Color=purchase.paint
	client.activities.set_menu("garage")
	client.activities.buy(1)
	await wait_for(func(): return purchase.paint!=paint and host.car_by_id(purchase.net_id).paint==purchase.paint)
	host.heat=0
	host.update_dispatch(0)
	client.network.rules.receive_event("spawn",{"position":Vector3(0,0.3,-5)})
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
	host.heat=0
	host.update_dispatch(0)
	host.network.rules.sheets[id].health=100.0
	client.activities.set_menu("")
	host.activities.bank.phase=1
	client.player.position=client.activities.bank.to_global(client.activities.bank.TERMINAL)+Vector3(1,0.2,0)
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
	await create_timer(0.3).timeout
	client.network.rules.send_action("interact",{})
	await wait_for(func(): return host.activities.bank.phase==3)
	for bag in client.activities.bank.BAGS:
		client.player.position=client.activities.bank.to_global(bag)+Vector3(1,0.2,0)
		await create_timer(0.3).timeout
		client.network.rules.send_action("interact",{})
		await create_timer(0.2).timeout
	await wait_for(func(): return host.activities.bank.phase==4)
	client.player.position=client.activities.bank.to_global(client.activities.bank.ENTRY)+Vector3(0,0.2,1)
	await wait_for(func(): return client.activities.bank.phase==5)
	host.cutscene.finish()
	client.cutscene.finish()
	host.heat = 0
	host.update_dispatch(0)
	host.network.rules.sheets[id].protected_until = Time.get_ticks_msec()+15000
	host.network.rules.sheets[id].cash = 50000
	client.player.position = client.activities.HEAVY_SHOP + Vector3.UP*0.3
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
	await create_timer(0.3).timeout
	var remaining: int = host.network.rules.sheets[id].cash
	client.activities.set_menu("heavy_guns")
	client.activities.buy(0)
	await create_timer(0.3).timeout
	assert(host.network.rules.sheets[id].cash == remaining, "Reject remote purchase away from shop")
	client.activities.set_menu("")
	client.player.position = client.activities.SUPPLY_PICKUP + Vector3.UP * 0.3
	await wait_for(func(): return host.network.rules.position_of(id).distance_to(host.activities.SUPPLY_PICKUP) < 2)
	await wait_for(func(): return host.network.avatars[id].node.position.distance_to(host.activities.SUPPLY_PICKUP) < 2)
	client.network.rules.send_action("interact", {})
	await wait_for(func(): return host.activities.supply_stage == 1)
	client.player.position = client.activities.SUPPLY_ALLEY + Vector3.UP * 0.3
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
		await wait_for(func(): return host.network.rules.position_of(id).distance_to(client.PRISON_POINTS[step]) < 2)
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
	client.network.disconnect_room()
	await wait_for(func(): return host.network.members.size()==1)
	client.network.announced_version="old-build"
	client.network.address_field.text=client.network.make_internet_code("127.0.0.1",28960,host.network.code)
	client.network.join_room()
	await create_timer(1.0).timeout
	assert(not client.network.joined and host.network.members.size()==1,"Reject incompatible builds")
	host.network.disconnect_room()
	client.network.disconnect_room()
	host.queue_free()
	client.queue_free()
	await process_frame
	print("PASS: version rejection, police fleet, coop mission, PvP both directions, respawn, car purchase, garage, bank hack and bags")
	quit()
