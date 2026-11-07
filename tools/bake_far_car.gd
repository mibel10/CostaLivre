extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var vehicle: Node3D = load("res://assets/models/vehicle.tscn").instantiate()
	var tools: Array[SurfaceTool] = []
	for i in 2:
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		tools.append(tool)
	for part in vehicle.get_children():
		for s in part.mesh.get_surface_count():
			var mat: Material = part.mesh.surface_get_material(s)
			var group := 0 if "Paint" in mat.resource_name else 1
			tools[group].append_from(part.mesh, s, part.transform)
	var importer := ImporterMesh.new()
	for tool in tools:
		tool.index()
		var mesh := tool.commit()
		importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, mesh.surface_get_arrays(0))
	importer.generate_lods(60, 0, [])
	var result := ArrayMesh.new()
	var total := 0
	for i in 2:
		var arrays := importer.get_surface_arrays(i)
		var target := maxi(120, int(arrays[Mesh.ARRAY_INDEX].size() * 0.12))
		for lod in importer.get_surface_lod_count(i):
			var indices := importer.get_surface_lod_indices(i, lod)
			if indices.size() < target:
				break
			arrays[Mesh.ARRAY_INDEX] = indices
		total += arrays[Mesh.ARRAY_INDEX].size() / 3
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var trim := StandardMaterial3D.new()
	trim.albedo_color = Color("18252c")
	trim.roughness = 0.6
	trim.cull_mode = BaseMaterial3D.CULL_DISABLED
	result.surface_set_material(1, trim)
	ResourceSaver.save(result, "res://assets/models/vehicle_far.res")
	print("Far car triangles: ", total, " surfaces: 2")
	vehicle.free()
	quit()
