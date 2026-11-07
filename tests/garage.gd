extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world = load("res://main.tscn").instantiate()
	root.add_child(world)
	world.start_mode("sandbox")
	world.cash = 2000
	var car = world.cars[0]
	world.active_car = car
	var color: Color = car.paint
	world.activities.set_menu("garage")
	world.activities.buy(1)
	assert(car.paint != color and world.cash == 1700 and car.wheels.size() == 4)
	world.activities.set_menu("garage")
	world.activities.buy(2)
	assert(car.engine_upgrade == 2.5 and world.cash == 1200)
	car.take_hit(100)
	world.activities.set_menu("garage")
	world.activities.buy(0)
	assert(car.hp == car.MAX_HP and world.cash == 950)
	assert(world.player.gun.get_parent() is BoneAttachment3D)
	world.active_car = null
	world.queue_free()
	await process_frame
	await create_timer(0.25).timeout
	print("PASS: garage paint, motor, repair and weapon attachment")
	quit()
