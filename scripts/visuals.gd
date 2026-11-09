extends RefCounted

var car_body: ArrayMesh
var car_wheels := {}
var paint_cache := {}
var textures := {}
var leaf_mesh: ArrayMesh
var simplified_materials := {}
var beetle_arch: ArrayMesh

func surface(name: String, tint: Color, scale_factor := 0.3) -> StandardMaterial3D:
	var key := name + tint.to_html() + str(scale_factor)
	if textures.has(key):
		return textures[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.albedo_texture = load("res://assets/textures/" + name + "_diff.jpg")
	mat.normal_enabled = name == "asphalt_02"
	if mat.normal_enabled:
		mat.normal_texture = load("res://assets/textures/" + name + "_nor_gl.jpg")
	mat.normal_scale = 0.55
	mat.roughness = 0.95
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3.ONE * scale_factor
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if name == "concrete_wall_006":
		mat.normal_enabled = false
		mat.roughness_texture = null
	else:
		mat.normal_scale = 0.22
		mat.roughness_texture = null
	textures[key] = mat
	return mat

func prepare_car(world: Node3D, use_baked := true) -> void:
	if car_body != null:
		return
	if use_baked and ResourceLoader.exists("res://assets/models/vehicle.tscn"):
		var baked: Node3D = load("res://assets/models/vehicle.tscn").instantiate()
		car_body = baked.get_node("Body").mesh
		for wheel in baked.get_children():
			if wheel.name != "Body":
				car_wheels[str(wheel.name)] = {"mesh": wheel.mesh, "origin": wheel.position, "transform": wheel.transform}
		baked.free()
		return
	var source: Node3D = load("res://assets/models/CarConcept.glb").instantiate()
	world.add_child(source)
	var groups := {"body": {}}
	var origins := {}
	var wheel_transforms := {}
	for item in source.find_children("*", "MeshInstance3D", true, false):
		var part_name := str(item.name)
		if part_name.begins_with("Interior") and not ("Floor" in part_name or "Seats" in part_name or "Dash" in part_name or "Cage" in part_name):
			continue
		if part_name.begins_with("Engine"):
			continue
		var group := "body"
		var wheel: Node3D
		var ancestor: Node = item
		while ancestor != source:
			if str(ancestor.name).begins_with("WheelFront") or str(ancestor.name).begins_with("WheelRear"):
				wheel = ancestor
			ancestor = ancestor.get_parent()
		var transform: Transform3D = source.global_transform.affine_inverse() * item.global_transform
		if wheel != null:
			group = str(wheel.name)
			origins[group] = wheel.global_position - source.global_position
			wheel_transforms[group] = source.global_transform.affine_inverse() * wheel.global_transform
			transform = wheel.global_transform.affine_inverse() * item.global_transform
		if not groups.has(group):
			groups[group] = {}
		for s in item.mesh.get_surface_count():
			var original: Material = item.mesh.surface_get_material(s)
			var mat: Material = simplify_material(original)
			if not groups[group].has(mat):
				var tool := SurfaceTool.new()
				tool.begin(Mesh.PRIMITIVE_TRIANGLES)
				tool.set_material(mat)
				groups[group][mat] = tool
			groups[group][mat].append_from(item.mesh, s, transform)
	for group in groups:
		var mesh := ArrayMesh.new()
		for mat in groups[group]:
			groups[group][mat].commit(mesh)
		if group == "body":
			car_body = mesh
		else:
			car_wheels[group] = {"mesh": mesh, "origin": origins[group], "transform": wheel_transforms[group]}
	source.free()

func simplify_material(original: Material) -> Material:
	if simplified_materials.has(original):
		return simplified_materials[original]
	if not original is StandardMaterial3D:
		return original
	var mat := StandardMaterial3D.new()
	mat.resource_name = original.resource_name
	mat.cull_mode = original.cull_mode
	mat.albedo_color = original.albedo_color
	mat.albedo_texture = original.albedo_texture
	mat.normal_enabled = original.normal_enabled
	mat.normal_texture = original.normal_texture
	mat.metallic = original.metallic
	mat.metallic_texture = original.metallic_texture
	mat.metallic_texture_channel = original.metallic_texture_channel
	mat.roughness_texture = original.roughness_texture
	mat.roughness_texture_channel = original.roughness_texture_channel
	mat.uv1_scale = original.uv1_scale
	mat.uv1_offset = original.uv1_offset
	mat.roughness = maxf(original.roughness, 0.23)
	if "Rim" in original.resource_name:
		mat.albedo_color = Color("828c94")
		mat.metallic = 0.65
		mat.roughness = 0.42
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if "Paint" in original.resource_name:
		mat.normal_enabled = false
	if "Glass" in original.resource_name:
		mat.albedo_color = Color("182c3b")
		mat.albedo_texture = null
		mat.metallic = 0.65
		mat.roughness = 0.18
	if original.emission_enabled:
		mat.emission_enabled = true
		mat.emission = original.emission
		mat.emission_energy_multiplier = 0.7
	simplified_materials[original] = mat
	return mat

func build_car(car: CharacterBody3D) -> void:
	if car.tier >= 4:
		preload("res://scripts/vehicle_catalog.gd").build(car)
		return
	prepare_car(car.world)
	if car.tier == 0:
		build_beetle(car)
		return
	var root := Node3D.new()
	root.name = "DetailedBody"
	root.rotation.y = PI # glTF vehicle faces +Z; game vehicles face -Z.
	root.scale = Vector3.ONE * 0.95
	root.position.y = 0.02
	car.add_child(root)
	var body := MeshInstance3D.new()
	body.mesh = car_body
	body.add_to_group("car_detail")
	if car.police:
		body.set_meta("police_lod", true)
	body.visibility_range_end = 27
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(body)
	for i in car_body.get_surface_count():
		var original: Material = car_body.surface_get_material(i)
		if original is StandardMaterial3D and "Paint" in original.resource_name:
			var color: Color = car.paint
			if car.police and "Paint 2" in original.resource_name:
				color = Color("cdd5d6")
			var key := original.resource_name + color.to_html()
			if not paint_cache.has(key):
				var mat: StandardMaterial3D = original.duplicate()
				mat.albedo_color = color
				mat.metallic = 0.7
				mat.roughness = 0.23
				paint_cache[key] = mat
			body.set_surface_override_material(i, paint_cache[key])
	for key in car_wheels:
		var pivot := Node3D.new()
		pivot.name = key
		pivot.position = car_wheels[key].origin
		root.add_child(pivot)
		if "Front" in key:
			car.steering_hubs.append(pivot)
		var spin := Node3D.new()
		spin.name = "Spin"
		pivot.add_child(spin)
		var wheel := MeshInstance3D.new()
		wheel.mesh = car_wheels[key].mesh
		wheel.add_to_group("car_detail")
		if car.police:
			wheel.set_meta("police_lod", true)
		wheel.visibility_range_end = 27
		wheel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		spin.add_child(wheel)
		car.wheels.append(spin)
	var far_body := MeshInstance3D.new()
	far_body.name = "FarBody"
	far_body.mesh = preload("res://assets/models/vehicle_far.res")
	far_body.add_to_group("car_far")
	if car.police:
		far_body.set_meta("police_lod", true)
	far_body.visibility_range_begin = 27
	far_body.visibility_range_end = 170
	far_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var far_key: String = "far" + car.paint.to_html()
	if not paint_cache.has(far_key):
		var paint := StandardMaterial3D.new()
		paint.albedo_color = car.paint
		paint.metallic = 0.35
		paint.roughness = 0.45
		paint.cull_mode = BaseMaterial3D.CULL_DISABLED
		paint_cache[far_key] = paint
	far_body.set_surface_override_material(0, paint_cache[far_key])
	root.add_child(far_body)
	if car.tier == 1:
		var rack := BoxMesh.new()
		rack.size = Vector3(1.35,0.12,2.6)
		var rack_node := MeshInstance3D.new()
		rack_node.mesh = rack
		rack_node.position = Vector3(0,1.5,0)
		rack_node.material_override = car.world.material(Color("343a3d"))
		root.add_child(rack_node)
	elif car.tier == 2:
		for side in [-1,1]:
			var trim := MeshInstance3D.new()
			var stripe := BoxMesh.new()
			stripe.size = Vector3(0.035,0.16,2.9)
			trim.mesh = stripe
			trim.position = Vector3(side*0.99,0.47,0)
			trim.material_override = car.world.material(Color("efe3ce"))
			root.add_child(trim)
	elif car.tier >= 3:
		var spoiler := MeshInstance3D.new()
		var wing := BoxMesh.new()
		wing.size = Vector3(1.9,0.12,0.34)
		spoiler.mesh = wing
		spoiler.position = Vector3(0,1.35,-1.82)
		spoiler.material_override = car.world.material(Color("272c31"))
		root.add_child(spoiler)
	# Shadow proxy avoids rendering every detailed vehicle again in each cascade.
	var shadow := MeshInstance3D.new()
	var proxy := BoxMesh.new()
	proxy.size = Vector3(1.8, 0.75, 3.9)
	shadow.mesh = proxy
	shadow.position.y = 0.65
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	shadow.add_to_group("car_shadow")
	car.add_child(shadow)
	if car.police:
		car.world.box(car, Vector3(0, 1.55, 0.3), Vector3(1.3, 0.08, 0.28), Color("14202a"))
		for side in [-1, 1]:
			car.lights.append(car.world.box(car, Vector3(side * 0.35, 1.65, 0.3), Vector3(0.6, 0.15, 0.26), Color("438ad7") if side < 0 else Color("df5350"), false, true))
		for side in [-1, 1]:
			var sign := Label3D.new()
			sign.text = "POLÍCIA"
			sign.font_size = 40
			sign.pixel_size = 0.007
			sign.position = Vector3(side * 0.92, 0.75, 0)
			sign.rotation.y = side * PI / 2
			car.add_child(sign)

func build_beetle(car: CharacterBody3D) -> void:
	var root := Node3D.new()
	root.name = "Fusquinha"
	root.rotation.y = PI
	root.scale = Vector3.ONE * 0.95
	root.position.y = 0.02
	car.add_child(root)
	var body := SphereMesh.new()
	body.radial_segments = 16
	body.rings = 8
	body.radius = 1
	body.height = 2
	part(root, body, Vector3(0,0.7,0), Vector3(0.86,0.4,1.65), car.paint)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color("304a56")
	glass.metallic = 0.25
	glass.roughness = 0.3
	part(root,body,Vector3(0,1.04,-0.05),Vector3(0.78,0.48,0.88),Color.WHITE,glass)
	part(root,body,Vector3(0,1.45,-0.05),Vector3(0.74,0.11,0.73),car.paint)
	var pillar := BoxMesh.new()
	pillar.size = Vector3(0.07,0.5,0.09)
	for side in [-1,1]:
		part(root,pillar,Vector3(side*0.74,1.12,0.05),Vector3.ONE,car.paint)
		for axle in [-1.05,1.05]:
			part(root,wheel_arch(),Vector3(side*0.94,0.38,axle),Vector3.ONE,car.paint)
	for side in [-1,1]:
		part(root, body, Vector3(side*0.65,0.78,1.4), Vector3(0.14,0.14,0.06), Color("f4e2ad"))
		part(root, body, Vector3(side*0.78,0.67,-1.23), Vector3(0.16,0.1,0.09), Color("c44135"))
	var bumper := BoxMesh.new()
	bumper.size = Vector3(1.9,0.12,0.16)
	part(root, bumper, Vector3(0,0.48,1.58), Vector3.ONE, Color("aab0b1"))
	part(root, bumper, Vector3(0,0.48,-1.58), Vector3.ONE, Color("aab0b1"))
	var tire := CylinderMesh.new()
	tire.top_radius = 0.36
	tire.bottom_radius = 0.36
	tire.height = 0.2
	tire.radial_segments = 12
	for side in [-1,1]:
		for z in [-1.05,1.05]:
			var hub := Node3D.new()
			hub.position = Vector3(side*0.94,0.38,z)
			root.add_child(hub)
			if z > 0:
				car.steering_hubs.append(hub)
			var spin := Node3D.new()
			hub.add_child(spin)
			var wheel := MeshInstance3D.new()
			wheel.mesh = tire
			wheel.rotation.z = PI/2
			wheel.material_override = car.world.material(Color("25282a"))
			wheel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			spin.add_child(wheel)
			var rim := MeshInstance3D.new()
			var rim_mesh := CylinderMesh.new()
			rim_mesh.top_radius = 0.21
			rim_mesh.bottom_radius = 0.21
			rim_mesh.height = 0.23
			rim_mesh.radial_segments = 16
			rim.mesh = rim_mesh
			rim.rotation.z = PI/2
			rim.material_override = car.world.material(Color("a4adb1"))
			rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			spin.add_child(rim)
			car.wheels.append(spin)
	merge_beetle_body(root)
	var shadow := MeshInstance3D.new()
	var proxy := BoxMesh.new()
	proxy.size = Vector3(1.9,0.7,3.7)
	shadow.mesh = proxy
	shadow.position.y = 0.65
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	shadow.add_to_group("car_shadow")
	car.add_child(shadow)

func wheel_arch() -> ArrayMesh:
	if beetle_arch != null:
		return beetle_arch
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for segment in 16:
		var vertices: Array[Vector3] = []
		for angle in [segment*PI/16,(segment+1)*PI/16]:
			for x in [-0.16,0.16]:
				for radius in [0.38,0.46]:
					vertices.append(Vector3(x,sin(angle)*radius,cos(angle)*radius))
		for face in [[0,4,5,1],[2,3,7,6],[1,5,7,3],[0,2,6,4]]:
			for index in [face[0],face[1],face[2],face[0],face[2],face[3]]:
				tool.add_vertex(vertices[index])
	tool.generate_normals()
	beetle_arch = tool.commit()
	return beetle_arch

func merge_beetle_body(root: Node3D) -> void:
	var surfaces := {}
	for child in root.get_children():
		if not child is MeshInstance3D:
			continue
		var material: Material = child.material_override
		if not surfaces.has(material):
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			tool.set_material(material)
			surfaces[material] = tool
		for surface in child.mesh.get_surface_count():
			var arrays: Array = child.mesh.surface_get_arrays(surface)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var tool: SurfaceTool = surfaces[material]
			var normal_basis: Basis = child.transform.basis.inverse().transposed()
			for index in (indices if not indices.is_empty() else range(points.size())):
				tool.set_normal((normal_basis*normals[index]).normalized())
				tool.set_uv(Vector2.ZERO)
				tool.add_vertex(child.transform*points[index])
		root.remove_child(child)
		child.queue_free()
	var mesh := ArrayMesh.new()
	for material in surfaces:
		surfaces[material].set_material(material)
		surfaces[material].commit(mesh)
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = mesh
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_to_group("car_simple")
	body.visibility_range_end = 170
	root.add_child(body)

func part(parent: Node3D, mesh: Mesh, at: Vector3, scale: Vector3, color: Color, custom: Material = null) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	instance.scale = scale
	if custom != null:
		instance.material_override = custom
	else:
		var key := "beetle_"+color.to_html()
		if not paint_cache.has(key):
			var paint := StandardMaterial3D.new()
			paint.albedo_color = color
			paint.metallic = 0.45
			paint.roughness = 0.28
			paint_cache[key] = paint
		instance.material_override = paint_cache[key]
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.add_to_group("car_simple")
	instance.visibility_range_end = 170
	parent.add_child(instance)

func palm(world: Node3D, at: Vector3) -> void:
	var trunk := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.13
	cylinder.bottom_radius = 0.26
	cylinder.height = 7.3
	cylinder.radial_segments = 14
	trunk.mesh = cylinder
	trunk.material_override = surface("concrete_wall_006", Color("77674e"), 2.0)
	trunk.position = at + Vector3(0, 3.65, 0)
	world.add_child(trunk)
	if leaf_mesh == null:
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for leaf in 9:
			var angle := float(leaf) * TAU / 9
			for segment in 10:
				var t0 := float(segment) / 10
				var t1 := float(segment + 1) / 10
				var points: Array[Vector3] = []
				for t in [t0, t1]:
					var center := Vector3(0, sin(t * PI) * 0.8 - t * t * 1.6, t * 4.2)
					var width := sin(t * PI) * 0.48
					points.append((center + Vector3(-width, 0, 0)).rotated(Vector3.UP, angle))
					points.append((center + Vector3(width, 0, 0)).rotated(Vector3.UP, angle))
				for index in [0, 2, 1, 1, 2, 3]:
					tool.add_vertex(points[index])
		tool.generate_normals()
		leaf_mesh = tool.commit()
	var canopy := MeshInstance3D.new()
	canopy.mesh = leaf_mesh
	var mat: StandardMaterial3D = world.material(Color("386447")).duplicate()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.9
	canopy.material_override = mat
	canopy.position = at + Vector3(0, 7.3, 0)
	world.add_child(canopy)
