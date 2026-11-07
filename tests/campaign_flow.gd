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
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://campaign_flow_test.cfg"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://campaign_flow_full_test.cfg"))
	world.queue_free()
	await process_frame
	await create_timer(0.25).timeout
	print("PASS: launch mode, sandbox, skippable mission scenes, saved campaign progression and retry")
	quit(0)
