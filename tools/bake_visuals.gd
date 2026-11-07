extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func reduce(mesh: ArrayMesh) -> ArrayMesh:
	var importer := ImporterMesh.new()
	for i in mesh.get_surface_count():
		importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, mesh.surface_get_arrays(i), [], {}, mesh.surface_get_material(i))
	importer.generate_lods(60, 0, [])
	var result := ArrayMesh.new()
	var triangles := 0
	for i in importer.get_surface_count():
		var arrays: Array = importer.get_surface_arrays(i)
		var original_count: int = arrays[Mesh.ARRAY_INDEX].size()
		var material: Material = importer.get_surface_material(i)
		var ratio := 0.3 if material != null and ("Paint" in material.resource_name or "Glass" in material.resource_name) else 0.055
		var target := maxi(120, int(original_count * ratio))
		for lod in importer.get_surface_lod_count(i):
			var indices := importer.get_surface_lod_indices(i, lod)
			if indices.size() < target:
				break
			arrays[Mesh.ARRAY_INDEX] = indices
		triangles += arrays[Mesh.ARRAY_INDEX].size() / 3
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		result.surface_set_material(i, importer.get_surface_material(i))
	print("Baked triangles: ", triangles)
	return result

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var visuals = load("res://scripts/visuals.gd").new()
	visuals.prepare_car(world, false)
	var vehicle := Node3D.new()
	vehicle.name = "Vehicle"
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = reduce(visuals.car_body)
	ResourceSaver.save(body.mesh, "res://assets/models/vehicle_body.res")
	vehicle.add_child(body)
	body.owner = vehicle
	for name in visuals.car_wheels:
		var wheel := MeshInstance3D.new()
		wheel.name = name
		# Geometry is already in a local frame with X along the axle. Remove
		# the presentation-only steering/spin rotations authored in the source.
		wheel.position = visuals.car_wheels[name].origin
		wheel.mesh = reduce(visuals.car_wheels[name].mesh)
		ResourceSaver.save(wheel.mesh, "res://assets/models/" + name + ".res")
		vehicle.add_child(wheel)
		wheel.owner = vehicle
	var scene := PackedScene.new()
	scene.pack(vehicle)
	ResourceSaver.save(scene, "res://assets/models/vehicle.tscn")
	vehicle.free()
	quit()
