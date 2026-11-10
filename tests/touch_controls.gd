extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world = load("res://main.tscn").instantiate()
	root.add_child(world)
	world.start_mode("sandbox")
	var touch = load("res://scripts/touch_controls.gd").new()
	touch.world = world
	world.hud.get_parent().add_child(touch)
	assert(not touch.visible, "Desktop never shows mobile controls")
	touch.move_stick(Vector2(180,440))
	assert(Input.is_action_pressed("forward"))
	touch.fingers[0] = "stick"
	touch.release_all()
	assert(not Input.is_action_pressed("forward"))
	touch.action("shoot",true)
	await process_frame
	assert(Input.is_action_pressed("shoot"))
	touch.fingers[1] = "shoot"
	touch.release_all()
	await process_frame
	assert(not Input.is_action_pressed("shoot"))
	world.activities.set_menu("jobs")
	var page_tap := InputEventScreenTouch.new()
	page_tap.pressed = true
	page_tap.position = world.hud.MENU_NEXT.get_center() * root.get_visible_rect().size / Vector2(1280, 720)
	touch._input(page_tap)
	assert(world.activities.job_page == 1, "Touching the next button changes the contracts page")
	world.activities.set_menu("cars")
	for i in 3:
		touch._input(page_tap)
	assert(world.activities.car_page == 3 and world.activities.menu_page_count() == 4, "Touch reaches the last dealer page")
	world.activities.set_menu("owned_cars")
	assert(world.activities.car_page == 0, "A short inventory cannot inherit an invalid dealer page")
	world.activities.set_menu("")
	world.activities.weapon = 0
	touch.action("weapon", true)
	assert(world.extra.wheel and touch.context() == "weapon_wheel")
	var tap := InputEventScreenTouch.new()
	tap.pressed = true
	tap.position = Vector2(734, 266) * root.get_visible_rect().size / Vector2(1280, 720)
	touch._input(tap)
	assert(world.activities.weapon == 1 and not world.extra.wheel, "Tapping the pistol equips it and closes the wheel")
	world.activities.clips[1] = 1
	world.activities.reserves[1] = 12
	assert("reload" in touch.gameplay_actions(), "Reload appears with a pistol and spare ammo")
	world.activities.weapon = 0
	assert("reload" not in touch.gameplay_actions(), "Fists cannot reload")
	world.player.position = Vector3(900, 0.3, 0)
	assert("interact" not in touch.gameplay_actions(), "No entry button away from vehicles")
	var car: Node3D = world.cars.filter(func(vehicle): return not vehicle.police)[0]
	world.player.position = car.position + Vector3.RIGHT * 2.0
	assert("interact" in touch.gameplay_actions(), "Entry button appears near a vehicle")
	world.active_car = car
	assert("interact" in touch.gameplay_actions() and "weapon" not in touch.gameplay_actions(), "Driving shows exit and hides the weapon wheel")
	assert("flip" not in touch.gameplay_actions(), "An upright car does not show the recovery button")
	car.position = world.FUEL_STATIONS[0] + Vector3.RIGHT * 6.0
	car.fuel = 0.5
	assert("activity" not in touch.gameplay_actions(), "The fuel action uses the same radius as the pump")
	car.position = world.FUEL_STATIONS[0]
	car.speed = -1.0
	touch.action("activity", true)
	touch.action("activity", false)
	assert(car.refuel_time == 0.0, "Reversing at the pump cannot start refueling")
	car.speed = 0.0
	assert("activity" in touch.gameplay_actions(), "A parked car with a low tank can use the pump")
	touch.action("activity", true)
	touch.action("activity", false)
	world._physics_process(1.0)
	assert(is_equal_approx(car.refuel_time, 4.0))
	touch.action("activity", true)
	touch.action("activity", false)
	assert(is_equal_approx(car.refuel_time, 4.0), "Repeated taps do not reset the timer")
	car.speed = -1.0
	world._physics_process(0.1)
	assert(car.refuel_time == 0.0 and car.fuel == 0.5, "Reversing cancels refueling")
	car.tumbling = true
	car.rotation.z = PI
	assert("flip" in touch.gameplay_actions(), "The Android recovery button appears when the car is overturned")
	car.tumbling = false
	car.rotation.z = 0
	world.active_car = null
	world.activities.weapon = 6
	Input.action_press("aim")
	world._process(0.2)
	assert(not world.player.model.visible and world.camera.fov < 68, "Sniper aiming zooms and hides the local model")
	Input.action_release("aim")
	world._process(0.2)
	assert(world.player.model.visible, "Leaving sniper aim restores the model")
	world.queue_free()
	await process_frame
	await create_timer(0.25).timeout
	print("PASS: Android-only UI, analog movement, held fire release, touch contract navigation and weapon wheel")
	quit()
