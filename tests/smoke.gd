extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func action(name: String) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = true
	return event

func run() -> void:
	create_timer(30).timeout.connect(func():
		push_error("Smoke check timed out")
		quit(1)
	)
	var world = load("res://main.tscn").instantiate()
	root.add_child(world)
	world.start_mode("sandbox")
	world.set_process(false)
	await physics_frame
	await physics_frame
	var a = world.activities
	world.hud.previous_health = -1.0
	world.health = 80.0
	world.hud._process(0.0)
	assert(world.hud.damage_flash == 0.0, "Initial health does not flash as damage")
	world.health = 70.0
	world.hud._process(0.0)
	assert(world.hud.damage_flash > 0.0, "Actual damage flashes")
	world.hud.damage_flash = 0.0
	world.health = 100.0
	var saved_cutscene = world.cutscene
	world.cutscene = null
	world.hud._process(0.0)
	world.cutscene = saved_cutscene
	assert(world.extra.sounds.has("horn"), "Horn has a dedicated sound")
	assert(world.cars.size() == 92 and world.station.fleet.size() == 27, "Expanded city traffic, parked cars and police fleet")
	world.player.position = Vector3(-5, 0.3, 7)
	world.interact()
	assert(world.active_car == null and world.car_transition)
	await create_timer(1.0).timeout
	assert(world.active_car == null and world.player.visible, "Driver stays outside during the entry animation")
	await create_timer(1.15).timeout
	assert(world.active_car != null and not world.player.visible)
	assert(world.cops.is_empty() and world.heat == 0, "The starter car is owned")
	world.raise_heat(12)
	world.update_dispatch(6)
	assert(world.cops.size() == 2 and world.heat == 24.0, "A witness escalates a car theft to two patrols")
	var starter = world.active_car
	world.active_car.speed = 10
	world.interact()
	assert(world.active_car == null, "Moving exit is allowed")
	await create_timer(0.4).timeout
	starter.speed = 0
	assert(world.active_car == null and world.player.visible)
	world.player.position = starter.position + Vector3(-2,0,0)
	var heat_before: float = world.heat
	world.interact()
	await create_timer(2.15).timeout
	assert(world.active_car == starter and world.heat <= heat_before, "Re-entering your car is legal without adding heat")
	Input.action_press("forward")
	var before: Vector3 = starter.position
	for frame in 50:
		await physics_frame
	Input.action_release("forward")
	assert(starter.position.distance_to(before) > 1, "Throttle moves vehicle")
	world._unhandled_input(action("pause"))
	assert(paused)
	var elapsed_before: float = world.elapsed
	world._physics_process(2)
	assert(world.elapsed == elapsed_before)
	world._unhandled_input(action("pause"))
	assert(not paused)
	a.handle_input(action("jobs"))
	assert(paused and a.menu == "jobs")
	a.handle_input(action("pause"))
	assert(not paused and a.menu == "")
	a.handle_input(action("map"))
	assert(paused and a.menu == "map")
	a.handle_input(action("map"))
	assert(not paused)
	starter.speed = 0
	world.heat = 0
	var money: int = world.cash
	a.start_job(0)
	world.cutscene.finish()
	for stop in world.STOPS:
		starter.position = stop + Vector3(0, 0.2, 0)
		a.tick(1.6)
	assert(a.job == -1 and a.completed == 1 and world.cash == money + 2400)
	world.cutscene.finish()
	assert(not world.finished, "Completing contracts keeps free roam running")
	a.set_menu("guns")
	a.buy(1)
	assert(a.rifle_owned and a.weapon == 2 and a.reserves[2] == 90)
	assert(not paused and world.cash == money + 600)
	a.clips[2] = 4
	a.reload()
	world.player.model.show_weapon(a.weapon)
	world.player.model.update_weapon_pose(0.0, 0.5)
	assert(world.player.model.weapon_magazine.position.y < -0.2 and world.player.gun.rotation.z > 0.25)
	a.tick(2)
	world.player.model.update_weapon_pose(0.0, 0.0)
	assert(is_equal_approx(world.player.model.weapon_magazine.position.y, -0.1))
	world.player.model.kick_weapon(a.weapon)
	world.player.model.update_weapon_pose(0.01, 0.0)
	assert(world.player.gun.rotation.x < -0.1)
	world.player.model.update_weapon_pose(0.2, 0.0)
	world.player.model.update_weapon_pose(0.0, 0.0)
	assert(world.player.gun.rotation.is_zero_approx())
	assert(a.clips[2] == 30 and a.reserves[2] == 64, "Reload transfers actual reserve ammo")
	world.cash = 0
	a.set_menu("guns")
	a.buy(2)
	assert(world.cash == 0 and a.menu == "guns", "Insufficient funds cannot purchase")
	a.set_menu("")
	world.active_car = null
	starter.driving = false
	world.player.visible = true
	world.player.collision_layer = 2
	world.player.position = a.ROBBERIES[0]
	a.start_job(1)
	world.cutscene.finish()
	Input.action_press("activity")
	a.tick_robbery(5.1)
	Input.action_release("activity")
	assert(world.cash == 1200 and a.stage == 1 and world.heat > 0)
	Input.action_press("activity")
	a.tick_robbery(6)
	Input.action_release("activity")
	assert(world.cash == 1200, "Robbed register has a cooldown")
	world.heat = 0
	a.tick(0.1)
	assert(a.job == -1 and world.cash == 2000, "Robbery bonus requires escape")
	world.cutscene.finish()
	a.start_job(5)
	world.cutscene.finish()
	world.player.position = a.ROBBERIES[2]
	Input.action_press("activity")
	a.tick_robbery(12.1)
	Input.action_release("activity")
	assert(a.stage == 0 and world.cash == 2000, "Holding F outside cannot rob the bank")
	var bank = a.bank
	world.player.position = bank.to_global(bank.BREAKER)
	assert(bank.interact() and bank.phase == 1)
	world.player.position = bank.to_global(bank.TERMINAL)
	assert(bank.interact() and bank.hacking)
	bank.enter_digit(bank.pattern[0])
	assert(bank.entered == 0, "Cannot enter the answer while it is being revealed")
	for round_number in 3:
		bank.tick(2.6)
		var sequence: Array = bank.pattern.duplicate()
		for digit in sequence:
			var key := InputEventKey.new()
			key.physical_keycode = KEY_1 + digit - 1
			key.pressed = true
			a.handle_input(key)
	assert(bank.phase == 2 and not bank.hacking, "Three remembered circuits unlock vault controls")
	world.player.position = bank.to_global(bank.VAULT_PANEL)
	assert(bank.interact() and bank.phase == 3)
	world.update_dispatch(6)
	assert(world.cops.size() == 3, "Bank heist dispatches three units, not the entire force")
	bank.tick(2)
	for point in bank.BAGS:
		world.player.position = bank.to_global(point)
		bank.interact()
	assert(bank.phase == 4 and world.cash == 2000, "Money must physically leave the bank")
	world.player.position = bank.to_global(bank.ENTRY)
	bank.tick(0.1)
	assert(a.stage == 1 and world.cash == 6000 and bank.phase == 5)
	bank.tick(0.1)
	assert(world.cash == 6000, "Bank pays only once per heist")
	world.heat = 0
	a.tick(0.1)
	assert(world.cash == 8000 and a.job == -1)
	world.cutscene.finish()
	a.start_job(2)
	world.cutscene.finish()
	world.player.position = a.target_car.position + Vector3(2, 0, 0)
	world.interact()
	await create_timer(2.15).timeout
	assert(world.active_car == a.target_car, "Marked supercar can be stolen")
	a.target_car.position = a.GARAGE + Vector3.UP * 0.2
	a.target_car.speed = 0
	a.tick(0.1)
	assert(a.job == -1, "Stolen luxury car can be delivered")
	world.cutscene.finish()
	a.start_job(3)
	world.cutscene.finish()
	for gate in a.RACE:
		world.active_car.position = gate + Vector3(0, 0.2, 0)
		a.tick(0.1)
	assert(a.job == -1, "Five race checkpoints complete")
	world.cutscene.finish()
	a.start_job(3)
	world.cutscene.finish()
	a.clock = 0.01
	a.tick(0.1)
	assert(a.job == -1, "Race timer can expire")
	a.start_job(4)
	world.cutscene.finish()
	for target in a.targets:
		target.take_hit(100)
	a.tick(0.1)
	assert(a.stage == 1 and a.job == 4)
	world.heat = 0
	a.tick(0.1)
	assert(a.job == -1, "Sabotage requires destruction and escape")
	world.cutscene.finish()
	a.start_job(6)
	world.cutscene.finish()
	assert(world.heat >= 80)
	world.heat = 0
	a.tick(0.1)
	assert(a.job == -1)
	world.cutscene.finish()
	world.cash = 10000
	a.set_menu("cars")
	a.buy(2)
	var purchased = world.cars.back()
	assert(purchased.tier == 3 and purchased.owned and world.cash == 1500)
	a.set_menu("cars")
	a.buy(0)
	assert(world.cash == 1500 and a.menu == "cars", "Occupied delivery bay blocks purchase without charging")
	a.set_menu("")
	# Aim a real physics ray at a car; this checks ammo and collision damage together.
	world.active_car = null
	world.player.collision_layer = 2
	world.player.visible = true
	world.player.position = Vector3(126, 0, 16)
	var target = world.spawn_car(Vector3(126, 0.2, 0), Color.RED)
	await create_timer(0.4).timeout
	await physics_frame
	world.camera.position = Vector3(126, 2.8, 15)
	world.camera.look_at(target.position + Vector3(0, 1, 0))
	a.weapon = 1
	a.clips[1] = 12
	a.fire_cooldown = 0
	a.reload_time = 0
	a.shoot()
	assert(a.clips[1] == 11 and target.hp < target.MAX_HP, "Shot consumes ammo and damages the actual hit collider")
	var hp_before: float = target.hp
	var cover = world.box(world, Vector3(126, 1.7, 8), Vector3(12, 4, 1), Color.GRAY, true)
	await physics_frame
	a.fire_cooldown = 0
	a.shoot()
	assert(target.hp == hp_before, "Walls block bullets")
	cover.queue_free()
	var officer = load("res://scripts/officer.gd").new()
	officer.world = world
	world.add_child(officer)
	officer.position = Vector3(126, 0.3, 24)
	await physics_frame
	world.heat = 12
	world.health = 100
	officer.fire_time = 0
	officer._physics_process(0.1)
	assert(world.health == 100, "Minor theft does not authorize police gunfire")
	world.heat = 80
	officer.fire_time = 0
	officer._physics_process(0.1)
	assert(world.health < 100, "Officers shoot only at high threat levels")
	officer.take_hit(100)
	assert(officer.hp == 0 and officer.collision_layer == 0, "Officers take weapon damage")
	world.update_dispatch(6)
	world.active_car = starter
	starter.position = Vector3(0, 0.2, 42)
	starter.speed = 0
	world.cops[0].position = starter.position + Vector3(3, 0, 0)
	world.bust_progress = 0
	world._physics_process(9.1)
	assert(world.finished, "Police arrest a stationary driver")
	world.finished = false
	world.health = 1
	world.damage(2)
	assert(world.finished)
	print("PASS: driving, pause, menus, 7 contracts, robbery cooldown, police escalation, weapons, reload, cover, economy, supercars, free roam and defeat")
	world.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	quit(0)
