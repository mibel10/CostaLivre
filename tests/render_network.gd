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
	assert(host.life.people.size()==171)
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
	client.network.discovery.set_dest_address("127.0.0.1", host.network.DISCOVERY)
	client.network.discovery.put_packet(var_to_bytes({"game": "costa_query"}))
	var discovery_deadline := Time.get_ticks_msec()+5000
	while not client.network.rooms.has(code) and Time.get_ticks_msec()<discovery_deadline:
		await process_frame
	assert(client.network.rooms.has(code),"UDP discovery finds advertised room")
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
	assert(host.network.avatars[remote_id].outfit==4*8)
	assert(client.network.avatars[1].tag.text=="Anfitriao")
	assert(client.network.chat_toggle.visible, "Chat is available inside an active room")
	client.network.open_chat()
	assert(client.network.chat_panel.visible and client.activities.menu=="chat" and not client.get_tree().paused, "Opening chat blocks local controls without pausing the online world")
	client.network.chat_input.text="Oi, sala!"
	client.network.send_chat()
	await create_timer(0.2).timeout
	assert(host.network.chat_history == ["Amigo: Oi, sala!"] and client.network.chat_history == ["Você: Oi, sala!"], "The host relays chat with the correct local names")
	client.network.chat_input.text="Mensagem repetida"
	client.network.send_chat()
	await create_timer(0.15).timeout
	assert(host.network.chat_history.size()==1 and client.network.chat_history.size()==1, "The host rate-limits repeated chat")
	client.network.close_chat()
	assert(not client.network.chat_panel.visible and client.activities.menu=="", "Closing chat returns the player to gameplay")
	host.network.chat_input.text="Teste do host"
	host.network.send_chat()
	await create_timer(0.2).timeout
	assert(host.network.chat_history == ["Amigo: Oi, sala!", "Você: Teste do host"] and client.network.chat_history == ["Você: Oi, sala!", "Anfitriao: Teste do host"], "Host messages reach the client without changing sender identity")
	var remote: Node3D = host.network.avatars[remote_id].node
	host.player.position = client.player.position + Vector3(-5.0, 0.0, 0.0)
	await create_timer(0.3).timeout
	assert(remote.visible)
	client.activities.clips[1] = 4
	host.network.rules.sheets[remote_id].inventory.clips[1] = 4
	client.network.rules.send_action("reload")
	await create_timer(0.68).timeout
	assert(remote.gun.rotation.z > 0.15 and remote.model.weapon_magazine.position.y < -0.16, "The remote reload follows the host timer")
	await create_timer(0.8).timeout
	assert(remote.gun.rotation.is_zero_approx(), "The weapon returns to its resting pose")
	client.set_process(false)
	var aim_direction := Vector3(0, 0.43, -0.9).normalized()
	client.camera.look_at(client.camera.global_position + aim_direction)
	Input.action_press("aim")
	await create_timer(0.55).timeout
	var remote_barrel: Vector3 = -remote.gun.global_basis.z.normalized()
	assert(remote_barrel.dot(aim_direction) > 0.96, "Other players see the raised arm and aim elevation")
	Input.action_release("aim")
	await create_timer(0.35).timeout
	assert(remote.model.weapon_aim.influence == 0.0, "The replicated arm returns to rest")
	client.set_process(true)
	client.player.set_crouched(true)
	assert(is_equal_approx(client.player.body_collider.shape.height, 1.15), "Crouch collision changes immediately")
	assert(client.player.model.rig.scale.y > 1.0, "Crouch starts a visual transition")
	await create_timer(0.23).timeout
	client.player.set_crouched(false)
	assert(client.profile.save_profile("Novo Nome",5))
	await create_timer(0.4).timeout
	assert(host.network.avatars[remote_id].tag.text=="Novo Nome" and host.network.avatars[remote_id].outfit==5*8)
	var previous_tag: Label3D=host.network.avatars[remote_id].tag
	client.player.position+=Vector3(1,0,0)
	await create_timer(0.5).timeout
	var client_id: int=client_api.get_unique_id()
	assert(host.network.members[client_id].position.distance_to(client.player.position)<2)
	var wrong_model: Node = client.car_by_id(1)
	wrong_model.tier = 6
	await create_timer(0.7).timeout
	assert(not is_instance_valid(wrong_model) and client.car_by_id(1).tier == host.car_by_id(1).tier)
	var loan: Node = host.spawn_car(client.player.position + Vector3(0, 0.3, 2.0), Color.BLUE, false, 4)
	var loan_id: int = loan.net_id
	await create_timer(0.3).timeout
	var remote_loan: Node = client.car_by_id(loan_id)
	client.interact()
	await create_timer(2.35).timeout
	assert(client.active_car == remote_loan)
	host.activities.remove_car(loan)
	await create_timer(0.3).timeout
	assert(not is_instance_valid(remote_loan) and client.active_car == null and client.player.visible)
	client.activities.bank.hacking = true
	client.network.rules.mission_hacking_peer = client_id
	client.network.disconnect_room()
	assert(not client.activities.bank.hacking and client.network.rules.mission_hacking_peer == 0)
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
	print("PASS: independent graphics, stable aim, expanded NPC population, discovery, direct invite, two peers, profiles, nametags, live outfit changes, cleanup")
	quit()
