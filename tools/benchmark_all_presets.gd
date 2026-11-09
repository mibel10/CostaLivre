extends SceneTree

var results: Array[Dictionary] = []
var all_frames: Array[float] = []

func _initialize() -> void:
	call_deferred("run")

func sample(world: Node3D, name: String) -> Dictionary:
	var warm := Time.get_ticks_msec()
	var warm_frames := 0
	while Time.get_ticks_msec()-warm < 5000 or warm_frames < 60:
		await process_frame
		warm_frames += 1
	var times: Array[float] = []
	var start := Time.get_ticks_usec()
	var previous := start
	while Time.get_ticks_usec()-start < 6000000:
		world.health = 10000
		world.bust_progress = 0
		if name == "perseguicao":
			world.heat = 100
			world.crime_grace = 10
		await process_frame
		var now := Time.get_ticks_usec()
		times.append((now-previous)/1000.0)
		previous = now
	all_frames.append_array(times)
	var elapsed := float(previous-start)/1000000
	times.sort()
	var row := {"scene":name,"frames":times.size(),"seconds":elapsed,"average_fps":snappedf(times.size()/elapsed,0.1),"p99_ms":snappedf(times[mini(times.size()-1,int(times.size()*0.99))],0.01),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
	print(world.settings.QUALITIES[world.settings.quality]," ",JSON.stringify(row))
	return row

func run() -> void:
	var metadata := {"adapter":RenderingServer.get_video_adapter_name(),"godot":Engine.get_version_info().string,"viewport":str(root.size),"vsync":"disabled","fps_limit":0,"sample_seconds_per_scene":6,"warmup_seconds_per_scene":5,"samples":results}
	var low_only := OS.get_cmdline_user_args().has("--low-only")
	for quality in ([3] if low_only else [4,3,2,1,0]):
		var world = load("res://main.tscn").instantiate()
		root.add_child(world)
		world.start_mode("sandbox")
		world.set_process_unhandled_input(false)
		world.settings.set_fps_limit(0,false)
		world.settings.set_quality(quality,false)
		assert(Engine.max_fps == 0 and DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_DISABLED)
		world.camera_yaw = 0
		world.camera_pitch = 0.25
		all_frames.clear()
		var scenes: Array[Dictionary] = []
		scenes.append(await sample(world,"rua"))
		world.player.position = world.activities.bank.to_global(Vector3(3,0,9))
		world.camera_yaw = 0.35
		scenes.append(await sample(world,"banco"))
		world.player.position = Vector3(0,0.2,50)
		world.camera_yaw = PI
		world.raise_heat(100)
		world.update_dispatch(6)
		for i in world.cops.size():
			world.cops[i].position = Vector3(-3+(i%2)*6,0.3,65+i*8)
		scenes.append(await sample(world,"perseguicao"))
		all_frames.sort()
		var total := 0.0
		for time in all_frames:
			total += time
		var slow_count := maxi(1,ceili(all_frames.size()*0.01))
		var slow_total := 0.0
		for i in range(all_frames.size()-slow_count,all_frames.size()):
			slow_total += all_frames[i]
		var row := {"quality":world.settings.QUALITIES[quality],"average_fps":snappedf(1000*all_frames.size()/total,0.1),"one_percent_low_fps":snappedf(1000*slow_count/slow_total,0.1),"scenes":scenes}
		results.append(row)
		print("RESULT ",JSON.stringify(row))
		var result_path := "res://benchmark_fleet.json" if OS.get_cmdline_user_args().has("--fleet") else ("res://benchmark_polish.json" if low_only else "res://benchmark_all_presets.json")
		var file := FileAccess.open(result_path,FileAccess.WRITE)
		metadata.viewport = str(root.size)
		file.store_string(JSON.stringify(metadata,"\t"))
		file.close()
		# Restore shared source materials so each fresh scene starts identically.
		for original in world.settings.tracked.values():
			var mat: StandardMaterial3D = original.material.get_ref()
			if mat != null:
				mat.normal_enabled = original.normal
				mat.shading_mode = original.shading
				mat.albedo_texture = original.texture
		world.queue_free()
		await process_frame
		await create_timer(0.25).timeout
	quit()
