extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world = load("res://main.tscn").instantiate()
	root.add_child(world)
	world.start_mode("sandbox")
	var actor = world.player.model
	assert(actor.cj_style)
	var clothed := false
	var triangle_count := 0
	for mesh in actor.find_children("*","MeshInstance3D",true,false):
		if mesh.material_override is StandardMaterial3D and mesh.material_override.vertex_color_use_as_albedo:
			var arrays: Array = mesh.mesh.surface_get_arrays(0)
			assert(arrays[Mesh.ARRAY_COLOR].size() == arrays[Mesh.ARRAY_VERTEX].size())
			assert(arrays[Mesh.ARRAY_BONES].size() > 0 and arrays[Mesh.ARRAY_WEIGHTS].size() > 0, "Wardrobe preserves the skeletal skin")
			triangle_count += arrays[Mesh.ARRAY_INDEX].size() / 3
			clothed = true
	assert(clothed, "Player wears a colored outfit instead of the gray demo material")
	assert(triangle_count > 0 and triangle_count <= 3000, "The human model stays under its 3,000 triangle budget")
	actor.animate(5)
	actor.animation.advance(0.35)
	assert(actor.animation.current_animation == "Animation")
	actor.animate(0)
	actor.animation.advance(0.3)
	actor._process(0.3)
	assert(actor.animation.assigned_animation == "Idle" and not actor.animation.is_playing(), "The single-pose idle sleeps after its walk-to-idle blend")
	actor.animate(5)
	assert(actor.animation.is_playing() and actor.animation.current_animation == "Animation", "Walking wakes the animator")
	actor.play_emote("wave")
	assert(actor.is_processing() and actor.animation.current_animation == "Wave", "Emotes wake the model timer")
	for mesh in actor.find_children("*","MeshInstance3D",true,false):
		if mesh.material_override is StandardMaterial3D:
			assert(mesh.material_override.albedo_texture == null, "Demo labels must not cover the character")
	var car = world.cars[0]
	assert(car.get_node("Fusquinha") != null and car.wheels.size() == 4)
	assert(car.get_node("Fusquinha/Body").mesh.get_surface_count() <= 6, "Body geometry is batched without changing the independent wheels")
	for mesh in car.get_node("Fusquinha").find_children("*","MeshInstance3D",true,false):
		if mesh.mesh is SphereMesh:
			assert(is_equal_approx(mesh.mesh.height,mesh.mesh.radius*2), "Rounded body surfaces need consistent sphere dimensions")
	world.queue_free()
	await process_frame
	await create_timer(0.25).timeout
	print("PASS: walk-to-idle blend, clean character materials and consistent Beetle geometry")
	quit()
