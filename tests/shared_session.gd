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
	assert(host.car_by_id(1).owned and host.heat>=12)
	var theft_heat: float=host.heat
	host.network.accept_state(id,theft)
	assert(is_equal_approx(host.heat,theft_heat),"No repeat theft alert")
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
	client.interact()
	await create_timer(0.5).timeout
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
	client.interact()
	await create_timer(0.5).timeout
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
		for index in pattern.size():
			client.network.rules.send_action("digit",{"digit":pattern[index]})
			await create_timer(0.1).timeout
			if index+1 < pattern.size():
				await wait_for(func(): return host.activities.bank.entered == index+1)
			else:
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
