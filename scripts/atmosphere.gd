extends Node3D

var world: Node3D
var planes: Array[Node3D] = []
var clocks := [0.0, 7.0]

func _ready() -> void:
	var cloud := SphereMesh.new()
	cloud.radial_segments = 8
	cloud.rings = 4
	cloud.radius = 1
	var cloud_material := StandardMaterial3D.new()
	cloud_material.albedo_color = Color("e6edf0")
	cloud_material.roughness = 1
	var cloud_batch := MultiMesh.new()
	cloud_batch.transform_format = MultiMesh.TRANSFORM_3D
	cloud_batch.mesh = cloud
	cloud_batch.instance_count = 42
	var rng := RandomNumberGenerator.new()
	rng.seed = 581
	for i in cloud_batch.instance_count:
		var at := Vector3(rng.randf_range(-175,175), rng.randf_range(48,78), rng.randf_range(-140,140))
		var size := rng.randf_range(4,9)
		cloud_batch.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(size * 1.7,size * 0.45,size)), at))
	var cloud_instance := MultiMeshInstance3D.new()
	cloud_instance.multimesh = cloud_batch
	cloud_instance.material_override = cloud_material
	cloud_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cloud_instance)
	for i in 2:
		var plane := Node3D.new()
		plane.position = Vector3(-210 if i == 0 else 210, 48 + i * 13, -40 + i * 80)
		add_child(plane)
		var paint := Color("e8e5d8") if i == 0 else Color("a9c2d0")
		_world_box(plane, Vector3.ZERO, Vector3(0.55,0.5,5.2), paint)
		_world_box(plane, Vector3(0,0.08,-0.2), Vector3(9,0.12,1.15), paint)
		_world_box(plane, Vector3(0,0.42,1.75), Vector3(3,0.12,0.65), paint)
		_world_box(plane, Vector3(0,0.38,-2.1), Vector3(2.3,0.1,0.42), paint)
		planes.append(plane)

func _world_box(parent: Node3D, at: Vector3, dimensions: Vector3, color: Color) -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.78
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.position = at
	parent.add_child(mesh_instance)

func _process(delta: float) -> void:
	for i in planes.size():
		clocks[i] = fposmod(clocks[i] + delta * (0.004 if i == 0 else 0.003), 1.0)
		var plane := planes[i]
		plane.position.x = lerpf(-210,210,clocks[i]) if i == 0 else lerpf(210,-210,clocks[i])
		plane.rotation.y = PI if i == 1 else 0.0
