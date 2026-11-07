extends RefCounted

static func cylinder(world: Node3D, parent: Node3D, at: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 24
	node.mesh = mesh
	node.position = at
	node.material_override = world.material(color)
	parent.add_child(node)
	return node

static func chair(world: Node3D, parent: Node3D, at: Vector3) -> void:
	world.box(parent, at + Vector3(0,0.5,0), Vector3(0.7,0.16,0.65),Color("3a6968"))
	world.box(parent, at + Vector3(0,0.9,0.28),Vector3(0.7,0.7,0.12),Color("3a6968"))
	for side in [-1,1]:
		cylinder(world,parent,at + Vector3(side*0.25,0.25,0),0.035,0.5,Color("6a7980"))

static func bank(bank: Node3D, world: Node3D) -> void:
	var decor := Node3D.new()
	bank.add_child(decor)
	var floor_mat := ShaderMaterial.new()
	floor_mat.shader = preload("res://shaders/marble.gdshader")
	var floor_mesh: MeshInstance3D = world.box(decor,Vector3(0,-0.085,0),Vector3(27,0.015,27),Color.WHITE)
	floor_mesh.material_override = floor_mat
	for side in [-1,1]:
		world.box(decor,Vector3(side*13.5,1.1,0),Vector3(0.12,2.2,26),Color("3f574f"))
		world.box(decor,Vector3(side*13.4,2.24,0),Vector3(0.14,0.08,26),Color("b49b62"))
		for z in [-10,-1,9]:
			cylinder(world,decor,Vector3(side*12,2.6,z),0.32,5.2,Color("a4aa9d"))
		for z in [5,7,9]:
			chair(world,decor,Vector3(side*7.0,0,z))
	# Teller counter is off the central entrance-to-vault corridor.
	world.box(decor,Vector3(-7,0.65,0),Vector3(8,1.3,1.3),Color("74513b"),true)
	world.box(decor,Vector3(-7,1.35,0),Vector3(8.3,0.13,1.6),Color("253f3e"))
	for i in 3:
		var x := -10.0 + i*3
		world.box(decor,Vector3(x,2.1,-0.4),Vector3(0.07,1.4,0.12),Color("b7a878"))
		world.box(decor,Vector3(x+0.7,1.8,-0.3),Vector3(1.0,0.65,0.08),Color("284957"))
		bank.label("CAIXA %02d" % (i+1),Vector3(x+0.8,3.1,0.2),20)
		world.box(decor,Vector3(x+0.7,1.42,0.2),Vector3(0.6,0.03,0.3),Color("252b2d"))
	# Office partitions flank an open doorway to the existing security terminal.
	world.box(decor,Vector3(5,1.5,1),Vector3(0.12,3,5),Color("4c6670"))
	bank.label("SALA DE SEGURANÇA",Vector3(8,3.8,3.5),22)
	for z in [-0.3,0.7]:
		for x in [7,8.5,10]:
			world.box(decor,Vector3(x,2.8,z-1),Vector3(1.1,0.7,0.12),Color("193238"))
			world.box(decor,Vector3(x,2.8,z-0.92),Vector3(0.85,0.04,0.02),Color("77b7a8"),false,true)
	# Safe-deposit drawers, rather than featureless boxes at the rear.
	for side in [-1,1]:
		for row in 4:
			for col in 6:
				world.box(decor,Vector3(side*(6+col),0.6+row*0.65,-13.05),Vector3(0.88,0.55,0.12),Color("71858a"))
				world.box(decor,Vector3(side*(6+col),0.6+row*0.65,-12.96),Vector3(0.22,0.06,0.08),Color("b8b398"))
	var wheel := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.47
	ring.outer_radius = 0.56
	wheel.mesh = ring
	wheel.material_override = world.material(Color("b5bab3"))
	wheel.position = Vector3(2.5,1.9,0.48)
	wheel.rotation.x = PI/2
	bank.door.add_child(wheel)
	for angle in [0.0,PI/2]:
		var spoke: MeshInstance3D = world.box(bank.door,Vector3(2.5,1.9,0.5),Vector3(1,0.08,0.08),Color("aeb5ad"))
		spoke.rotation.z = angle
	for z in [4,8,12]:
		world.box(decor,Vector3(0,6.8,z),Vector3(7,0.06,0.3),Color("f5e8c8"),false,true)
	bank.label("COSTA • PRIVATE BANKING",Vector3(0,5.4,13.99),30)

	world.batch_city_geometry(decor)
