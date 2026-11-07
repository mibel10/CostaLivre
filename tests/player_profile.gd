extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world = load("res://main.tscn").instantiate()
	root.add_child(world)
	world.profile.config_path="res://artifacts/profile_isolated_test.cfg"
	var hand: Node=world.player.gun.get_parent()
	assert(world.profile.save_profile("Amigo\n",4))
	assert(world.profile.player_name=="Amigo" and world.player.model.outfit_index==4)
	assert(world.player.gun.get_parent()==hand)
	var save := ConfigFile.new()
	assert(save.load(world.profile.config_path)==OK and save.get_value("player","outfit")==4)
	var state: Dictionary=world.network.local_state()
	assert(state.name=="Amigo" and state.outfit==4)
	state.name="Outro jogador"
	state.outfit=3
	world.network.update_avatars({2:state})
	assert(world.network.avatars[2].tag.text=="Outro jogador")
	assert(world.network.avatars[2].node.model.outfit_index==3)
	state.name="Novo Nome"
	state.outfit=5
	world.network.update_avatars({2:state})
	assert(world.network.avatars[2].tag.text=="Novo Nome" and world.network.avatars[2].node.model.outfit_index==5)
	var tag: Label3D=world.network.avatars[2].tag
	world.network.peer_left(2)
	await process_frame
	assert(not is_instance_valid(tag))
	assert(world.profile.clean_name("\n\u0001")=="Jogador")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(world.profile.config_path))
	world.queue_free()
	await process_frame
	await create_timer(0.25).timeout
	print("PASS: profile saving, outfit changes, weapon attachment, remote names and clothes, nametag cleanup")
	quit()
