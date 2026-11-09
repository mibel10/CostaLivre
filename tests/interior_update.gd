extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world = load("res://main.tscn").instantiate()
	root.add_child(world)
	world.start_mode("sandbox")
	assert(world.life.rooms.size() == 22)
	await physics_frame
	for building: String in world.life.ELEVATOR_FLOORS:
		var bottom: Vector3 = world.life.elevator_position(building,0) + Vector3.UP * 3
		var top: Vector3 = world.life.elevator_position(building,world.life.ELEVATOR_FLOORS[building]-1) + Vector3.UP * 2.7
		for offset in [Vector3.ZERO,Vector3(1.25,0,1.25),Vector3(-1.25,0,-1.25)]:
			var hit := root.world_3d.direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(bottom+offset,top+offset))
			assert(hit.is_empty(), "Clear elevator shaft: %s %s" % [building,hit])
	var landing: Vector3 = world.life.elevator_position("apartment",0) + Vector3(0,0,2)
	world.player.position = landing
	world.life.use_elevator(9)
	assert(world.life.elevators.apartment.phase == "closed", "Floor selection requires boarding")
	world.life.use_elevator(-1)
	await create_timer(0.4).timeout
	assert(world.life.elevators.apartment.phase == "open")
	world.player.position=world.life.elevator_position("apartment",0)
	world.life.use_elevator(9)
	await create_timer(1.1).timeout
	assert(world.player.position.y > 2.0 and world.player.position.y < 53.7, "Cabin carries the player between floors")
	await create_timer(6.6).timeout
	assert(world.life.elevators.apartment.phase == "open")
	assert(world.player.position.y > 53.7 and world.life.inside_room(world.player.position))
	world.life.refresh_room_visibility(world.player.position)
	assert(world.life.rooms[14].visible, "The floor reached by elevator stays furnished")
	assert(not world.life.rooms[2].visible, "The distant ground floor is culled")
	world.life.elevators.apartment.time = 14.99
	await create_timer(0.4).timeout
	assert(world.life.elevators.apartment.phase == "closed")
	var touch = load("res://scripts/touch_controls.gd").new()
	touch.world = world
	root.add_child(touch)
	var previous: float = touch.control_radius("map")
	touch.selected_button = "shoot"
	touch.resize_selected(0.2)
	assert(is_equal_approx(previous,touch.control_radius("map")))
	touch.queue_free()
	world.queue_free()
	await process_frame
	await create_timer(0.25).timeout
	print("PASS: ten floors, elevator, nearby room visibility and independent touch sizes")
	quit()
