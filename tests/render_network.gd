extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	create_timer(25).timeout.connect(func(): push_error("Networking timed out"); quit(1))
	var host_api := SceneMultiplayer.new()
	var client_api := SceneMultiplayer.new()
	var host_view := SubViewport.new()
	host_view.name="Host"
	host_view.size=Vector2i(1280,720)
	host_view.own_world_3d=true
	root.add_child(host_view)
	var client_view := SubViewport.new()
	client_view.name="Client"
	client_view.size=Vector2i(1280,720)
	client_view.own_world_3d=true
	root.add_child(client_view)
	set_multiplayer(host_api,NodePath("/root/Host/World"))
	set_multiplayer(client_api,NodePath("/root/Client/World"))
	var host = load("res://main.tscn").instantiate()
	host.name="World"
	host_view.add_child(host)
	var client = load("res://main.tscn").instantiate()
	client.name="World"
	client_view.add_child(client)
	host.settings.config_path="res://artifacts/custom_graphics_test.cfg"
	host.settings.set_quality(1,false)
	var shadows: int=host.settings.shadow_quality
	host.settings.set_custom("textures",3)
	assert(host.settings.shadow_quality==shadows and host.settings.texture_quality==3)
	assert(host.life.people.size()==41)
	host.start_mode("sandbox")
	Input.action_press("aim")
	host._process(0.016)
	var forward: Vector3=-host.camera.global_basis.z
	host.player.position+=Vector3(3,1,0)
	host._process(0.016)
	assert(forward.angle_to(-host.camera.global_basis.z)<0.001,"Aim orientation stays fixed while moving/jumping")
	Input.action_release("aim")
	host.profile.player_name="Anfitriao"
	client.profile.config_path="res://artifacts/profile_test.cfg"
	var gun_parent: Node=client.player.gun.get_parent()
	assert(client.profile.save_profile("Amigo",4))
	assert(client.player.model.outfit_index==4 and client.player.gun.get_parent()==gun_parent)
	var saved := ConfigFile.new()
	assert(saved.load(client.profile.config_path)==OK and saved.get_value("player","outfit")==4)
	host.network.host()
	assert(host.network.active(),"Host creates a room")
	var code: String=host.network.code
	assert(code.length()==5)
	var discovery_deadline := Time.get_ticks_msec()+5000
	while not client.network.rooms.has(code) and Time.get_ticks_msec()<discovery_deadline:
		await process_frame
	assert(client.network.rooms.has(code),"UDP discovery finds advertised room")
	client.network.rooms[code]={"ip":"127.0.0.1","time":Time.get_ticks_msec()}
	client.network.refresh_room_list()
	assert(client.network.room_list.item_count>0)
	client.network.room_list.select(0)
	client.network.join_selected_room()
	while host.network.members.size()<2 or client.network.members.size()<2:
		await process_frame
	await create_timer(0.4).timeout
	assert(host.network.avatars.size()==1 and client.network.avatars.size()==1)
	var remote_id: int=client_api.get_unique_id()
	assert(host.network.avatars[remote_id].tag.text=="Amigo")
	assert(host.network.avatars[remote_id].outfit==4)
	assert(client.network.avatars[1].tag.text=="Anfitriao")
	assert(client.profile.save_profile("Novo Nome",5))
	await create_timer(0.4).timeout
	assert(host.network.avatars[remote_id].tag.text=="Novo Nome" and host.network.avatars[remote_id].outfit==5)
	var previous_tag: Label3D=host.network.avatars[remote_id].tag
	client.player.position=Vector3(0,0.3,12)
	await create_timer(0.5).timeout
	var client_id: int=client_api.get_unique_id()
	assert(host.network.members[client_id].position.distance_to(client.player.position)<2)
	client.network.disconnect_room()
	await create_timer(0.3).timeout
	assert(host.network.members.size()==1)
	assert(not is_instance_valid(previous_tag))
	client.network.address_field.text=client.network.make_internet_code("127.0.0.1",28960,code)
	client.network.join_room()
	while host.network.members.size()<2 or client.network.members.size()<2:
		await process_frame
	assert(client.network.code==code)
	client.network.disconnect_room()
	await create_timer(0.3).timeout
	host.network.disconnect_room()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(host.settings.config_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(client.profile.config_path))
	host.queue_free()
	client.queue_free()
	await process_frame
	print("PASS: independent graphics, stable aim, 41 NPCs, discovery, direct invite, two peers, profiles, nametags, live outfit changes, cleanup")
	quit()
