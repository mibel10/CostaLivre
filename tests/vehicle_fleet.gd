extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	create_timer(35).timeout.connect(func(): quit(1))
	var world = load("res://main.tscn").instantiate()
	root.add_child(world)
	world.start_mode("sandbox")
	world.set_physics_process(false)
	var a = world.activities
	world.profile.outfit = 2
	assert(a.CAR_PRICES[a.Catalog.BUS - 1] == 30000)
	assert(is_equal_approx(a.Catalog.SPEEDS[a.Catalog.BUS] * 3.6, 160.0))
	assert(a.CAR_PRICES[a.Catalog.SUPERCAR - 1] == 75000)
	for tier in range(4,a.Catalog.NAMES.size()):
		var car = world.spawn_car(Vector3(0,0.2,84),Color.RED,false,tier)
		assert(car.model_name == a.Catalog.NAMES[tier])
		assert(car.wheels.size() == (2 if tier == 9 else 4))
		assert(car.steering_hubs.size() == (1 if tier == 9 else 2))
		assert(car.get_node("CustomVehicle/Body").mesh.get_surface_count() <= 6)
		var tire: MeshInstance3D = car.wheels[0].get_child(0)
		assert(tire.material_override.albedo_color.is_equal_approx(Color("252a2e")),"Tires must not inherit the metal rim material")
		if tier != 9:
			var body_arrays: Array = car.get_node("CustomVehicle/Body").mesh.surface_get_arrays(0)
			assert(body_arrays[Mesh.ARRAY_VERTEX].size()>120,"Batching must preserve the body panels together with roof and pillars")
		world.active_car = car
		car.driving = true
		Input.action_press("forward")
		for frame in 25:
			await physics_frame
		Input.action_release("forward")
		assert(car.speed>0 and car.position.z<83.5,"Each new vehicle accelerates on the road")
		if tier == a.Catalog.SUPERCAR:
			var toggle := InputEventAction.new()
			toggle.action = "activity"
			toggle.pressed = true
			car.speed = 0.0
			assert(a.handle_input(toggle) and car.hovering)
			for frame in 65:
				await physics_frame
			assert(car.position.y > a.Catalog.SIZES[a.Catalog.BUS].y, "Hover clears the bus roof")
			assert(a.handle_input(toggle) and not car.hovering)
		if tier == 9:
			assert(car.rider.visible)
			assert(car.rider_outfit == 2 and car.rider.get_child(0).material_override.albedo_color.is_equal_approx(Color("385b79")))
			world.interact()
			await create_timer(0.4).timeout
			assert(world.active_car == null and world.player.visible and not car.rider.visible)
		world.active_car = null
		car.repaint(Color.BLUE)
		assert(car.wheels.size() == (2 if tier == 9 else 4),"Repainting preserves vehicle type")
		world.cars.erase(car)
		car.queue_free()
	for index in range(3,a.CAR_PRICES.size()):
		world.cash = 100000
		a.car_page = index/3
		a.set_menu("cars")
		a.buy(index%3)
		var bought = world.cars.back()
		assert(bought.tier == index+1 and bought.owned,"Dealer pages map to the correct model")
		bought.position = Vector3(0,0.2,-126)
		world.cars.erase(bought)
		bought.queue_free()
	world.queue_free()
	await process_frame
	print("PASS: fleet models including bus, motorcycle rider/exit, acceleration, repaint and dealer pagination")
	quit()
