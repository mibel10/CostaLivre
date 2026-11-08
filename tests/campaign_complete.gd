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
	for chapter in 24:
		assert(a.job == chapter,"Campaign chapters remain sequential")
		world.cutscene.finish()
		world.active_car = car
		car.speed = 0
		if a.ACTION_JOBS.has(chapter):
			finish_action(world,car)
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
				a.target_car.position = a.GARAGE
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
				world.active_car = car
				car.position = a.INFORMANT_PICKUP
				assert(a.interact_campaign())
				car.position = a.INFORMANT_SAFEHOUSE
				a.tick_mission(0.1)
				assert(a.job == 8, "Rescue needs an escape before delivery")
				world.heat = 0
				a.tick_mission(0.1)
			11,12,13,14,15,16,17,18,19,20,21,22,23:
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
	print("PASS: all 24 chapters through objective rules, bank, cutscene transitions and campaign ending")
	quit()

func finish_action(world: Node, car: Node) -> void:
	var a: Node = world.activities
	var spec: Dictionary = a.ACTION_JOBS[a.job]
	var original_stage: int = a.stage
	Input.action_press("activity")
	world.life.tick_tasks(1000)
	Input.action_release("activity")
	assert(a.stage == original_stage, "Holding the old service button cannot finish the new mission")
	match str(spec.kind):
		"drive":
			world.active_car = a.target_car
			a.target_car.speed = 0
			for point in spec.points:
				a.target_car.position = point
				a.tick_mission(0.1)
		"rescue":
			world.active_car = a.target_car if a.target_car != null else car
			world.active_car.position = spec.pickup
			world.active_car.speed = 0
			assert(a.interact_campaign())
			world.active_car.position = spec.drop
			a.tick_mission(0.1)
		"intercept":
			a.target_car.take_hit(102)
			a.tick_mission(0.1)
			assert(a.stage == 1)
			world.active_car = null
			world.player.position = a.target_car.position+Vector3(3,0,0)
			assert(a.interact_campaign())
			world.player.position = spec.drop
			world.heat = 0
			a.tick_mission(0.1)
