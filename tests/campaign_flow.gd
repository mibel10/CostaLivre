extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world = load("res://main.tscn").instantiate()
	root.add_child(world)
	await process_frame
	assert(paused and world.activities.menu == "mode", "Launch asks for a game mode")
	world.start_mode("sandbox")
	assert(not paused and world.activities.job == -1, "Sandbox starts free roam")
	world.activities.start_job(0)
	assert(paused and world.cutscene.active, "Missions open with a skippable intro")
	world.cutscene.finish()
	assert(not paused)
	world.activities.game_mode = "campaign"
	world.game_mode = "campaign"
	world.activities.campaign_path = "user://campaign_flow_test.cfg"
	world.activities.campaign_save_path = "user://campaign_flow_full_test.cfg"
	var save := ConfigFile.new()
	save.set_value("story", "next_mission", 2)
	save.save(world.activities.campaign_save_path)
	world.start_mode("campaign")
	assert(world.activities.job == 2 and world.activities.campaign_index == 2, "Campaign resumes its saved chapter")
	world.cutscene.finish()
	world.activities.campaign_index = 0
	world.activities.start_job(0)
	world.cutscene.finish()
	world.activities.complete_job()
	assert(world.activities.campaign_index == 1 and paused, "Chapter completion saves the next mission before its outro")
	world.cutscene.finish()
	assert(world.activities.job == 1 and world.cutscene.active, "Campaign advances in order and introduces the next chapter")
	world.activities.fail_job("test")
	world.cutscene.finish()
	assert(world.activities.job == 1 and world.cutscene.active, "Failed campaign chapters retry in order")
	world.cutscene.finish()
	world.cutscene.finish()
	var chapter: int = world.activities.campaign_index
	var mission: int = world.activities.job
	world.player.position = world.activities.SUPPLY_PICKUP
	assert(world.activities.interact_supply())
	world.player.position = world.activities.SUPPLY_ALLEY
	world.activities.tick_supply()
	assert(world.activities.supply_stage == 2 and world.cutscene.active)
	world.cutscene.finish()
	world.activities.supply_scene_until = 0
	world.activities.tick_supply()
	assert(world.activities.supply_stage == 3 and world.cutscene.active)
	world.cutscene.finish()
	var cash_before: int = world.cash
	assert(world.activities.interact_supply())
	assert(world.activities.supply_stage == 4 and world.cash == cash_before+4500)
	assert(not world.activities.interact_supply(), "No repeated delivery payout")
	assert(world.activities.campaign_index == chapter and world.activities.job == mission, "Side quest preserves campaign")
	world.cash = 5000
	world.life.buy_home(0)
	world.life.buy_home(1)
	assert(world.life.owned_homes == [0] and world.cash == 4000, "Only one apartment per player")
	world.respawn_local()
	assert(world.player.position.y > 6 and world.player.position.y < 7, "Respawn above reception")
	world.player.position = world.activities.HILL_RESIDENT
	assert(world.activities.interact_hill_errand())
	world.player.position = world.activities.HILL_MEDICINE
	assert(world.activities.interact_hill_errand())
	world.player.position = world.activities.HILL_RESIDENT
	var errand_cash: int = world.cash
	assert(world.activities.interact_hill_errand())
	assert(world.cash == errand_cash+1800 and not world.activities.interact_hill_errand(), "Hill errand pays once")
	world.activities.heavy_owned = [true,true,true]
	world.activities.weapon = 7
	world.activities.clips[7] = 11
	world.activities.reserves[7] = 42
	world.activities.purchased_cars = [{"tier":2,"paint":Color.RED,"engine":2.5,"suspension":0.3,"net_id":1234}]
	world.cash = 1234
	assert(world.activities.save_campaign())
	world.activities.heavy_owned = [false,false,false]
	world.activities.load_campaign()
	assert(world.activities.heavy_owned == [true,true,true])
	assert(world.activities.weapon == 7 and world.activities.clips[7] == 11 and world.activities.reserves[7] == 42)
	assert(world.activities.purchased_cars.size() == 1 and world.activities.purchased_cars[0].tier == 2 and world.activities.purchased_cars[0].net_id == -1, "Purchased cars survive campaign reload without stale scene IDs")
	assert(world.cash == 1234, "Campaign retains heavy weapons, ammo and cash")
	world.activities.campaign_index = world.activities.CAMPAIGN_LENGTH - 1
	world.activities.start_job(world.activities.SECRET_DATA_JOB)
	world.cutscene.finish()
	world.finish(false)
	world.respawn_local()
	assert(world.activities.job == world.activities.SECRET_DATA_JOB, "Death retries the final campaign mission instead of a co-op mission")
	world.cutscene.finish()
	world.damage(200.0, true)
	assert(world.finished and world.prison_after_death, "Police death sends the player to prison")
	world.respawn_local()
	assert(world.prison_stage == 0 and world.player.position == world.PRISON_SPAWN)
	for step in world.PRISON_POINTS.size():
		world.player.position = world.PRISON_POINTS[step]
		world.player.is_crouching = false
		if step == 1:
			world.prison_interact(1, world.player.position)
			assert(world.prison_stage == step, "The passage requires crouching")
			world.player.is_crouching = true
		if step in [2, 4]:
			world.tick_prison(1, world.player.position, true, 1.0)
			world.tick_prison(1, world.player.position, false, 1.0)
			assert(world.prison_progress == 0.0 and world.prison_stage == step, "Releasing the interaction resets progress")
			world.tick_prison(1, world.player.position, true, 11.0)
		else:
			world.prison_interact(1, world.player.position)
	world.player.is_crouching = false
	assert(world.prison_stage == -1 and world.activities.job == world.activities.SECRET_DATA_JOB, "Escape resumes the campaign chapter")
	world.cutscene.finish()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://campaign_flow_test.cfg"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://campaign_flow_full_test.cfg"))
	world.queue_free()
	await process_frame
	await create_timer(0.25).timeout
	print("PASS: launch mode, sandbox, skippable mission scenes, saved campaign progression and retry")
	quit(0)
