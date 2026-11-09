extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	create_timer(25).timeout.connect(func(): quit(1))
	var world = load("res://main.tscn").instantiate()
	root.add_child(world)
	world.start_mode("sandbox")
	world.set_process(false)
	world.set_physics_process(false)
	var bank = world.activities.bank
	await physics_frame
	await physics_frame
	var entrance := PhysicsRayQueryParameters3D.create(bank.to_global(Vector3(0, 1, 17)), bank.to_global(Vector3(0, 1, 12)), 1)
	assert(world.get_world_3d().direct_space_state.intersect_ray(entrance).is_empty(), "Bank entrance is physically open")
	var vault := PhysicsRayQueryParameters3D.create(bank.to_global(Vector3(0, 1, 0)), bank.to_global(Vector3(0, 1, -7)), 1)
	assert(not world.get_world_3d().direct_space_state.intersect_ray(vault).is_empty(), "Locked vault blocks passage")
	world.player.position = bank.to_global(Vector3(0, 0, 16))
	world.player.velocity = Vector3.ZERO
	world.camera_yaw = 0
	Input.action_press("forward")
	for i in 35:
		await physics_frame
	Input.action_release("forward")
	assert(bank.inside(), "Player can walk through the actual bank entrance")
	world.player.position = bank.to_global(bank.TERMINAL)
	assert(not bank.interact(), "Security must be disabled before hacking")
	world.player.position = bank.to_global(bank.BREAKER)
	bank.interact()
	world.player.position = bank.to_global(bank.TERMINAL)
	bank.interact()
	for failure in 3:
		bank.tick(2.6)
		bank.enter_digit(bank.pattern[0] % 4 + 1)
	assert(bank.lockout == 15 and not bank.hacking and bank.phase == 1 and world.heat == 30, "Three errors trigger alarm and lockout, never open the vault")
	assert(bank.interact() and not bank.hacking, "Lockout prevents retry")
	bank.tick(16)
	bank.interact()
	assert(bank.hacking)
	var cancel := InputEventAction.new()
	cancel.action = "pause"
	cancel.pressed = true
	bank.handle_input(cancel)
	assert(not bank.hacking and bank.phase == 1 and not paused, "Cancel returns to play without granting access")
	bank.interact()
	for circuit in 3:
		bank.tick(2.6)
		var answer: Array = bank.pattern.duplicate()
		for digit in answer:
			bank.enter_digit(digit)
	assert(bank.phase == 2)
	world.player.position = bank.to_global(bank.VAULT_PANEL)
	bank.interact()
	bank.tick(2)
	await physics_frame
	await physics_frame
	assert(world.get_world_3d().direct_space_state.intersect_ray(vault).is_empty(), "Opened vault permits passage")
	var money: int = world.cash
	for at in bank.BAGS:
		world.player.position = bank.to_global(at)
		bank.interact()
		bank.interact()
	assert(bank.phase == 4 and world.cash == money, "Each malote is collected once, payout requires exit")
	world.player.position = bank.to_global(bank.ENTRY)
	bank.tick(0.1)
	assert(world.cash == money + 4000)
	bank.tick(101)
	assert(bank.phase == 0 and bank.taken.count(true) == 0 and bank.bag_models.all(func(b): return b.visible))
	# Dropping a wanted level withdraws extra patrols; walls break police sight.
	world.heat = 100
	world.response_delay = 0
	world.update_dispatch(0)
	assert(world.cops.size() == 7)
	world.heat = 12
	world.update_dispatch(0)
	assert(world.cops.size() == 1)
	world.cops[0].position = Vector3(0, 0.2, 0)
	world.player.position = Vector3(0, 0, 15)
	assert(world.police_can_see(world.cops[0]))
	var wall = world.box(world, Vector3(0, 2, 8), Vector3(8, 5, 1), Color.GRAY, true)
	await physics_frame
	await physics_frame
	assert(not world.police_can_see(world.cops[0]), "Hiding behind cover breaks police sight even nearby")
	world.heat = 0
	world.update_dispatch(0)
	assert(world.cops.is_empty())
	wall.queue_free()
	print("PASS: walk-in bank, physical vault, hack errors/cancel/retry, circuits, loot, exit, cooldown, proportional police and cover")
	world.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	quit(0)
