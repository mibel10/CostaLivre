extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var vehicle = load("res://assets/models/vehicle.tscn").instantiate()
	for wheel in vehicle.get_children():
		if wheel.name == "Body": continue
		print(wheel.name," bounds=",wheel.mesh.get_aabb()," basis=",wheel.basis," det=",wheel.basis.determinant())
	var source = load("res://assets/models/CarConcept.glb").instantiate()
	for item in source.find_children("*","MeshInstance3D",true,false):
		if str(item.name).begins_with("Body") or str(item.name).begins_with("Wheel"):
			var mat: StandardMaterial3D = item.mesh.surface_get_material(0)
			print(item.name," cull=",mat.cull_mode," ",mat.resource_name)
	vehicle.free()
	source.free()
	quit()
