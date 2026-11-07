extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	create_timer(30).timeout.connect(func(): quit(1))
	var world = load("res://main.tscn").instantiate()
	root.add_child(world)
	world.start_mode("sandbox")
	world.set_physics_process(false)
	var a = world.activities
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/playthrough"))
	a.game_mode = "campaign"
	a.campaign_index = 0
	a.campaign_path = "res://artifacts/playthrough/full_campaign_test.cfg"
	a.campaign_save_path = "res://artifacts/playthrough/full_campaign_save_test.cfg"
	a.start_job(0)
	var car = world.cars[0]
	for chapter in 17:
		assert(a.job == chapter,"Campaign chapters remain sequential")
		world.cutscene.finish()
		world.active_car = car
		car.speed = 0
		match chapter:
			0:
				for stop in world.STOPS:
					car.position = stop
					a.tick(1.6)
			1:
				world.active_car = null
				world.player.position = a.ROBBERIES[0]
				Input.action_press("activity")
				a.tick_robbery(5.1)
				Input.action_release("activity")
				world.heat = 0
				a.tick(0.1)
			2:
				world.active_car = a.target_car
				a.target_car.position = Vector3(-42,0,84)
				a.tick(0.1)
			3:
				for gate in a.RACE:
					car.position = gate
					a.tick(0.1)
			4:
				for target in a.targets:
					target.take_hit(100)
				a.tick(0.1)
				world.heat = 0
				a.tick(0.1)
			5:
				world.active_car = null
				var bank = a.bank
				for point in [bank.BREAKER,bank.TERMINAL]:
					world.player.position = bank.to_global(point)
					bank.interact()
				for circuit in 3:
					bank.tick(2.6)
					for digit in bank.pattern.duplicate():
						bank.enter_digit(digit)
				world.player.position = bank.to_global(bank.VAULT_PANEL)
				bank.interact()
				for point in bank.BAGS:
					world.player.position = bank.to_global(point)
					bank.interact()
				world.player.position = bank.to_global(bank.ENTRY)
				bank.tick(0.1)
				world.heat = 0
				a.tick(0.1)
			6:
				world.heat = 0
				a.tick(0.1)
			8:
				for step in 3:
					world.active_car = null
					world.player.position = a.destination()
					a.tick_mission(0.1)
			7,9,10,11,12,13,14,15,16:
				world.active_car = null
				for step in 3:
					world.player.position = world.life.mission_position()
					Input.action_press("activity")
					world.life.tick_tasks(world.life.BUILDING_TASK_DURATION+0.1)
					Input.action_release("activity")
		assert(a.job == -1 and a.campaign_index == chapter+1,"Objective must complete and save next chapter")
		print("CHAPTER PASS ",chapter+1)
		world.cutscene.finish()
	world.cutscene.finish()
	assert(a.menu == "campaign_complete")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(a.campaign_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(a.campaign_save_path))
	world.activities.set_menu("")
	world.queue_free()
	await process_frame
	print("PASS: all 17 chapters through objective rules, bank, cutscene transitions and campaign ending")
	quit()
