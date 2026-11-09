extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func wait_until(condition: Callable, seconds := 8.0) -> bool:
	var deadline := Time.get_ticks_msec()+int(seconds*1000)
	while not condition.call() and Time.get_ticks_msec()<deadline:
		await process_frame
	return condition.call()

func run() -> void:
	create_timer(60).timeout.connect(func(): quit(1))
	var host_api:=SceneMultiplayer.new()
	var client_api:=SceneMultiplayer.new()
	var host_view:=SubViewport.new()
	host_view.name="Host"
	host_view.own_world_3d=true
	root.add_child(host_view)
	var client_view:=SubViewport.new()
	client_view.name="Client"
	client_view.own_world_3d=true
	root.add_child(client_view)
	set_multiplayer(host_api,NodePath("/root/Host/World"))
	set_multiplayer(client_api,NodePath("/root/Client/World"))
	var host=load("res://main.tscn").instantiate()
	host.name="World"
	host_view.add_child(host)
	var client=load("res://main.tscn").instantiate()
	client.name="World"
	client_view.add_child(client)
	host.start_mode("sandbox")
	client.start_mode("sandbox")
	host.network.host()
	client.network.address_field.text=client.network.make_internet_code("127.0.0.1",28960,host.network.code)
	client.network.join_room()
	if not await wait_until(func(): return client.network.joined and host.network.members.size()==2):
		push_error("Multiplayer connection timed out")
		quit(1)
		return
	var id:=client_api.get_unique_id()
	var inv: Dictionary=host.network.rules.sheets[id].inventory
	inv.clips[1]=1
	inv.reserves[1]=10
	inv.reload_weapon=1
	inv.reload_time=0.1
	inv.fire_cooldown=0.1
	host.activities.clips[1]=3
	host.activities.reserves[1]=6
	host.activities.reload_weapon=1
	host.activities.reload_time=0.1
	host.activities.fire_cooldown=0.1
	await create_timer(0.4).timeout
	inv=host.network.rules.sheets[id].inventory
	assert(inv.clips[1]==11 and inv.reserves[1]==0 and inv.fire_cooldown==0,"Client reload and cooldown progress on host")
	assert(host.activities.clips[1]==9 and host.activities.reserves[1]==0 and host.activities.fire_cooldown==0,"Host reload and cooldown progress")
	host.player.position=Vector3(20,0.3,0)
	host.network.members[1]["crouch"]=false
	host.network.members[id]["car_position"]=Vector3(10,0.3,0)
	host.network.members[id]["crouch"]=true
	assert(host.network.rules.police_target_actor(Vector3.ZERO)[0]==1,"Police can target a visible player instead of a hidden crouching player")
	var contact := -1
	for index: int in client.life.building_contacts:
		if client.life.building_contacts[index][0] == "office":
			contact = index
			break
	assert(contact >= 0)
	var wages: int = host.network.rules.sheets[id].cash
	var host_cash: int = host.cash
	client.network.rules.send_action("building_contact",{"contact":contact})
	await create_timer(0.25).timeout
	assert(host.life.building_job_for(id).is_empty(), "The host rejects a request sent far from the NPC")
	var office: Vector3 = client.life.people[contact].position + Vector3.BACK
	client.player.position = office
	assert(await wait_until(func(): return host.network.rules.position_of(id).distance_to(office) < 0.5))
	assert(client.life.interact_building())
	client.life.building_choice.pressed.emit()
	assert(await wait_until(func(): return not client.life.building_job_for(id).is_empty()))
	for step in 3:
		var stop: Vector3 = client.life.building_destination(client.life.building_job_for(id))
		client.player.position = stop
		assert(await wait_until(func(): return host.network.rules.position_of(id).distance_to(stop) < 0.5), "Delivery %d at %s, host player at %s" % [step,stop,host.network.rules.position_of(id)])
		await create_timer(0.18).timeout
		assert(client.life.interact_building())
		assert(await wait_until(func(): return client.life.building_job_for(id).get("step",3) == step+1))
	assert(host.network.rules.sheets[id].cash == wages+200 and host.cash == host_cash, "Only the player who completes the deliveries receives payment")
	for building in ["housing","apartment","tower"]:
		var start: Vector3=client.life.elevator_position(building,0)
		client.player.position=start
		client.player.velocity=Vector3.ZERO
		if not await wait_until(func(): return host.network.members[id].position.distance_to(start)<2):
			push_error("Host did not receive the elevator position")
			quit(1)
			return
		assert(client.life.elevator_building_at(start)==building)
		assert(client.life.prompt().contains("elevador"))
		client.life.use_elevator(5)
		if not await wait_until(func(): return client.player.position.y>29.5):
			push_error("Elevator arrival timed out: "+building)
			quit(1)
			return
		assert(host.network.members[id].position.y>29.5,"Host owns elevator arrival")
		assert(await wait_until(func(): return client.life.elevators[building].phase == "open"))
	var before: Vector3=host.network.members[id].position
	client.network.rules.send_action("elevator",{"to":9})
	await create_timer(0.4).timeout
	assert(host.network.members[id].position.distance_to(before)<2.0,"Tower rejects non-existent floors")
	client.life.use_elevator(client.life.ELEVATOR_BASEMENT)
	assert(await wait_until(func(): return client.life.elevators.tower.floor == client.life.ELEVATOR_BASEMENT and client.life.elevators.tower.phase == "open"))
	assert(absf(host.network.members[id].position.y - client.life.BASEMENT_HEIGHT) < 0.25, "Host accepts the basement landing")
	assert(absf(client.player.position.y - client.life.BASEMENT_HEIGHT) < 0.25, "Client rides to the basement")
	client.life.use_elevator(0)
	assert(await wait_until(func(): return client.life.elevators.tower.floor == 0 and client.life.elevators.tower.phase == "open"))
	assert(await wait_until(func(): return not host.network.members[id].has("elevator_target")))
	var remote_car: Node=client.car_by_id(1)
	client.player.position = remote_car.position+Vector3(2.6,0.3,0)
	assert(await wait_until(func(): return host.network.rules.position_of(id).distance_to(remote_car.position) < 4.5))
	client.network.rules.send_action("vehicle_entry",{"car":1})
	assert(await wait_until(func(): return client.active_car == remote_car))
	remote_car.speed=10.0
	if not await wait_until(func(): return int(host.network.owners.get(1,0))==id):
		push_error("Host did not assign the client's vehicle")
		quit(1)
		return
	assert(await wait_until(func(): return client.engine_audio.pitch_scale>0.7, 2.0),"Engine audio updates in multiplayer")
	host.network.rules.punch_peer(id,0.0)
	assert(not host.network.rules.last_actions.has(str(id)+"punch_hit"),"Host rejects punches from vehicles")
	var host_car: Node=host.car_by_id(1)
	host_car.take_hit(10000)
	host_car.wreck_timer=0.15
	if not await wait_until(func(): return is_instance_valid(host_car) and host_car.exploded, 3.0):
		push_error("Host did not detonate the disabled client vehicle")
		quit(1)
		return
	assert(await wait_until(func(): return not host.network.rules.is_dead(id) and not client.network.rules.is_dead(id)))
	var moving: Node3D = host.spawn_car(Vector3(130,0.3,42),Color.BLUE,false,1)
	var moving_id: int = moving.net_id
	assert(await wait_until(func(): return client.car_by_id(moving_id) != null))
	client.network.rules.receive_event("spawn",{"position":moving.position+Vector3.LEFT*2.5})
	assert(await wait_until(func(): return host.network.rules.position_of(id).distance_to(moving.position)<4.5), "Client reported position beside the car")
	client.network.rules.send_action("vehicle_entry",{"car":moving_id})
	assert(await wait_until(func(): return client.active_car == client.car_by_id(moving_id)))
	client.active_car.speed = 9.0
	assert(await wait_until(func(): return moving.speed > 0.5))
	host.player.position = moving.position+Vector3.LEFT*2.5
	host.network.rules.send_action("vehicle_entry",{"car":moving_id})
	assert(await wait_until(func(): return client.vehicle_falls.has(id) and client.active_car == null))
	assert(not client.player.visible and host.vehicle_falls.has(id))
	assert(await wait_until(func(): return host.active_car == moving and host.network.owners.get(moving_id) == 1))
	assert(await wait_until(func(): return client.player.visible and not client.vehicle_falls.has(id)))
	print("PASS: host-authoritative deliveries, elevators and vehicle explosion")
	client.network.disconnect_room()
	host.network.disconnect_room()
	host.queue_free()
	client.queue_free()
	await process_frame
	await create_timer(0.25).timeout
	quit()
