extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	create_timer(30).timeout.connect(func():quit(1))
	var world = load("res://main.tscn").instantiate()
	root.add_child(world)
	world.start_mode("sandbox")
	var car = world.cars[0]
	world.player.position = car.position + Vector3(-2,0,0)
	world.player.roll_time = 0.3
	world.player.model.rotation.x = 2
	world.player.model.position.y = 0.8
	world.interact()
	assert(world.player.roll_time == 0 and world.car_transition)
	assert(world.player.model.rotation.x == 0)
	var visual: Node3D = car.get_node("Fusquinha" if car.tier == 0 else "DetailedBody")
	assert(visual.scale.is_equal_approx(Vector3.ONE*0.95),"Tires must not be stretched")
	assert(car.wheels.size() == 4 and car.steering_hubs.size() == 2)
	for hub in car.steering_hubs:
		assert(hub.rotation.is_zero_approx(),"Source presentation steering must not leak into gameplay")
	var body: ArrayMesh = world.visuals.car_body
	var tested := 0
	for i in body.get_surface_count():
		var mat: Material = body.surface_get_material(i)
		if "Paint" in mat.resource_name or "Glass" in mat.resource_name:
			assert(mat.cull_mode == BaseMaterial3D.CULL_DISABLED,"Keep the source shell's double-sided surfaces")
			tested += 1
	assert(tested >= 3)
	while world.car_transition:
		await process_frame
	Input.action_press("forward")
	Input.action_press("left")
	for i in 24:
		await physics_frame
	Input.action_release("forward")
	Input.action_release("left")
	assert(car.wheel_angle != 0 and car.steering_angle > 0)
	for wheel in car.wheels:
		assert(wheel.basis.x.is_equal_approx(Vector3.RIGHT),"Wheel spin must preserve its local axle")
	for hub in car.steering_hubs:
		assert(hub.basis.y.is_equal_approx(Vector3.UP),"Steering cannot tilt the axle")
	var wall: Node3D = world.box(world,Vector3(0,2,-8),Vector3(12,4,0.5),Color.GRAY,true)
	car.position = Vector3(0,0.3,-3)
	car.heading = 0
	car.speed = 200
	var health_before: float = world.health
	var bounced := false
	for i in 20:
		await physics_frame
		if car.speed < 0:
			bounced = true
			assert(absf(car.speed) <= 4.0, "Wall bounce is small")
			break
	assert(bounced and world.health == health_before, "Fast wall impact bounces without killing driver")
	wall.queue_free()
	car.position = world.activities.GARAGE+Vector3.UP*0.3
	world.cash = 5000
	var wheel_y: float = car.wheels[0].global_position.y
	world.activities.menu = "garage"
	world.activities.buy(3)
	assert(is_equal_approx(car.suspension_height,0.15) and world.cash == 4200)
	assert(absf(car.wheels[0].global_position.y-wheel_y)<0.001, "Suspension raises body while wheels stay grounded")
	car.repaint(car.paint)
	assert(is_equal_approx(car.suspension_height,0.15))
	car.apply_network_health(car.MAX_HP * 0.3)
	assert(car.body_damage_marks[0].visible and car.glass_damage_marks[0].visible)
	car.repaint(car.paint)
	await process_frame
	car.apply_network_health(car.MAX_HP * 0.5)
	assert(is_instance_valid(car.body_damage_marks[0]) and car.body_damage_marks[0].visible, "Repaint preserves valid damage marks")
	assert(not car.glass_damage_marks[0].visible)
	car.apply_network_health(car.MAX_HP)
	assert(not car.body_damage_marks[0].visible and not car.glass_damage_marks[0].visible, "Replicated repairs clear damage marks")
	world.active_car = null
	car.driving = false
	world.cash = 10000
	world.activities.menu = "cars"
	world.activities.buy(0)
	assert(world.activities.purchased_cars.size() == 1)
	var bought: Node = world.car_by_id(world.activities.purchased_cars[0].net_id)
	world.player.position = world.activities.CAR_SPAWNERS[0][0]
	var car_count: int = world.cars.size()
	var saved_cash: int = world.cash
	world.activities.recall_car(0)
	assert(bought.position.distance_to(world.activities.CAR_SPAWNERS[0][1]) < 0.1)
	world.activities.recall_car(0)
	assert(world.cars.size() == car_count and world.cash == saved_cash, "Recalling purchased car does not duplicate or charge again")
	world.extra.play("cash")
	var stream: AudioStream = world.extra.audio.stream
	world.extra.play("step")
	world.extra.play("siren")
	assert(world.extra.audio.stream == stream,"Ambient effects must not interrupt rewards")
	world.life.people[0].position = Vector3(170,0,-130)
	world.life._process(1)
	assert(world.life.people[0].model.process_mode == Node.PROCESS_MODE_DISABLED)
	print("PASS: closed body materials, round wheels, stable spin/steer axes, roll-to-car reset, independent audio and sleeping animations")
	world.queue_free()
	await process_frame
	await create_timer(0.3).timeout
	quit()
