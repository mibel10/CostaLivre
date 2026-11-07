extends SceneTree

var world
var results: Array = []
var checks: Array = []
var tag := "before"

func _initialize() -> void:
	call_deferred("run")

func seconds(value: float) -> void:
	var until := Time.get_ticks_msec()+int(value*1000)
	while Time.get_ticks_msec() < until:
		await process_frame

func press(name: String) -> void:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = true
	world._unhandled_input(event)

func check(condition: bool, label: String) -> void:
	checks.append({"check":label,"pass":condition})
	print("CHECK ",condition," ",label)

func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/playthrough/"+tag+"_"+label+".png")

func sample(label: String, at: Vector3, yaw: float) -> void:
	world.player.position = at
	world.player.velocity = Vector3.ZERO
	world.camera_yaw = yaw
	world.camera_pitch = 0.25
	world.mouse_idle = 0
	await seconds(2)
	var frames: Array[float] = []
	var start := Time.get_ticks_usec()
	var previous := start
	while Time.get_ticks_usec()-start < 3000000:
		world.health = 10000
		world.bust_progress = 0
		await process_frame
		var now := Time.get_ticks_usec()
		frames.append(float(now-previous)/1000)
		previous = now
	frames.sort()
	var row := {"area":label,"fps":snappedf(frames.size()*1000000.0/(previous-start),0.1),"p95_ms":snappedf(frames[int(frames.size()*0.95)],0.1),"draws":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"triangles":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)}
	results.append(row)
	print("AREA ",JSON.stringify(row))
	await capture(label)

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tag="):
			tag = arg.trim_prefix("--tag=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/playthrough"))
	world = load("res://main.tscn").instantiate()
	root.add_child(world)
	world.activities.campaign_path = "res://artifacts/playthrough/campaign_test.cfg"
	world.activities.campaign_save_path = "res://artifacts/playthrough/campaign_save_test.cfg"
	await seconds(0.5)
	await capture("mode_menu")
	check(paused and world.activities.menu == "mode","mode selection")
	world.start_mode("sandbox")
	world.settings.set_quality(3,false)
	world.settings.set_fps_limit(0,false)
	world.player.position = Vector3(0,0.2,12)
	await seconds(2)
	var origin: Vector3 = world.player.position
	Input.action_press("forward")
	await seconds(0.9)
	Input.action_release("forward")
	await seconds(0.4)
	check(world.player.position.distance_to(origin)>2,"walk with physical movement")
	check(world.player.model.animation.current_animation == "Idle","walk returns to idle")
	var car = world.cars[0]
	world.player.position = car.position+Vector3(-2.3,0,0)
	press("interact")
	await seconds(0.6)
	check(world.active_car == car and not world.player.visible,"enter starter car")
	origin = car.position
	Input.action_press("forward")
	await seconds(2)
	Input.action_release("forward")
	Input.action_press("jump")
	await seconds(1)
	Input.action_release("jump")
	check(car.position.distance_to(origin)>5,"drive and brake")
	press("interact")
	await seconds(0.6)
	check(world.active_car == null and world.player.visible and not world.car_transition,"exit car")
	world.heat = 0
	world.update_dispatch(0)
	await sample("spawn",Vector3(-5,0.2,12),0)
	for i in world.life.PLACES.size():
		var center: Vector3 = world.life.PLACES[i]
		world.player.position = center+Vector3(0,0.2,15)
		world.player.velocity = Vector3.ZERO
		world.camera_yaw = 0
		Input.action_press("forward")
		await seconds(1.6)
		Input.action_release("forward")
		check(world.player.position.z < center.z+11.5,"walk through interior "+str(i+1))
		await sample("interior_"+str(i+1),center+Vector3(0,0.2,7),0)
	var bank = world.activities.bank
	await sample("bank",bank.to_global(Vector3(0,0.2,9)),0.3)
	for point in [bank.BREAKER,bank.TERMINAL]:
		world.player.position = bank.to_global(point)
		press("activity")
	for circuit in 3:
		await seconds(2.6)
		var pattern: Array = bank.pattern.duplicate()
		for digit in pattern:
			var key := InputEventKey.new()
			key.physical_keycode = KEY_1+digit-1
			key.pressed = true
			world._unhandled_input(key)
	check(bank.phase == 2,"solve three bank circuits")
	world.player.position = bank.to_global(bank.VAULT_PANEL)
	press("activity")
	await seconds(1.5)
	var money: int = world.cash
	for point in bank.BAGS:
		world.player.position = bank.to_global(point)
		press("activity")
	world.player.position = bank.to_global(bank.ENTRY)
	await seconds(0.3)
	check(world.cash == money+4000,"bank loot pays only at exit")
	world.heat = 0
	world.update_dispatch(0)
	await sample("coast",Vector3(-168,0.2,42),PI/2)
	await sample("east",Vector3(168,0.2,42),-PI/2)
	await sample("downtown",Vector3(84,0.2,-84),PI/4)
	world.player.position = Vector3(0,0.2,50)
	world.raise_heat(100)
	world.update_dispatch(6)
	await sample("pursuit",Vector3(0,0.2,50),PI)
	press("pause")
	check(paused,"pause during pursuit")
	world.pause_menu.show_page("map")
	world.pause_menu.map_view.zoom_at(2,Vector2(400,200))
	await capture("map")
	world.pause_menu.resume()
	check(not paused,"resume")
	var report := {"tag":tag,"adapter":RenderingServer.get_video_adapter_name(),"viewport":str(root.size),"quality":"Baixo","cap":0,"samples":results,"checks":checks,"method":"automated inputs; repositioned between checkpoints; screenshots; 2s warmup + 3s sample per area"}
	var output := FileAccess.open("res://artifacts/playthrough/"+tag+".json",FileAccess.WRITE)
	output.store_string(JSON.stringify(report,"\t"))
	output.close()
	world.queue_free()
	await process_frame
	quit()
