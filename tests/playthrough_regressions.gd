extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	create_timer(30).timeout.connect(func(): quit(1))
	var world = load("res://main.tscn").instantiate()
	root.add_child(world)
	world.start_mode("sandbox")
	assert(world.life.PLACES.size() == world.life.TITLES.size(),"Every interior needs a map label")
	var bystander = world.life.people[0]
	bystander.stationary = true
	bystander.position = Vector3(900, 12, 0)
	var wreck = world.spawn_car(bystander.position + Vector3(2, 0, 0), Color.RED)
	await physics_frame
	await physics_frame
	wreck.explode()
	assert(bystander.hp == 0 and world.heat == 0.0, "An unoccupied car explosion does not blame the player")
	var car = world.cars[0]
	var body = car.get_node("Fusquinha/Body")
	assert(body.mesh.get_surface_count() <= 6)
	var original: Material = body.material_override
	car.take_hit(car.MAX_HP)
	assert(body.material_override != original)
	car.repair()
	assert(car.hp == car.MAX_HP and body.material_override == original,"Repair restores paint and windows")
	world.player.position = car.position+Vector3(-2.3,0,0)
	world.interact()
	assert(world.player.model.position == Vector3.ZERO,"Entry begins at the character rather than teleporting to the door")
	await create_timer(2.15).timeout
	assert(not world.car_transition and not world.player.visible)
	world.interact()
	await create_timer(0.45).timeout
	assert(world.active_car == null and world.player.visible)
	world.player.position = world.life.PLACES[0]+Vector3(0,0.2,7)
	world.player.velocity = Vector3.ZERO
	world.camera_yaw = 0
	world.camera_pitch = 0.25
	for i in 35:
		await process_frame
	assert(world.camera.position.z < world.life.PLACES[0].z+11.7,"Interior camera stays behind the doorway header")
	world.activities.set_menu("pause")
	world.pause_menu.show_page("map")
	world.pause_menu.map_view.queue_redraw()
	await process_frame
	world.pause_menu.begin_rebind("forward")
	world.pause_menu.show_page("map")
	assert(world.pause_menu.awaiting_action == "","Leaving controls cancels key capture")
	world.pause_menu.resume()
	world.queue_free()
	await process_frame
	print("PASS: all map labels, batched body, repair appearance, entry/exit, interior camera and rebind cancellation")
	quit()
