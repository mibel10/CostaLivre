extends RefCounted

const BUS := 10
const BUS_CAPACITY := 12
const SUPERCAR := 11
const HOVER_SPEED := 160.0 / 3.6
const HOVER_HEIGHT := 3.85
const NAMES := ["Fusquinha","Vento GT","Tempestade","Aurora X","Cometa R","Eclipse V12","Raio RS","Bairro Compact","Litoral LX","Falcão 600","Ônibus Costa","Vórtice X"]
const SPEEDS := [44.45,51.0,63.0,75.0,70.0,78.0,83.0,34.0,42.0,58.0,160.0/3.6,230.0/3.6]
const ACCEL := [10.0,14.0,18.0,22.0,21.0,23.0,25.0,8.5,11.0,19.0,8.0,38.0]
const SIZES := [Vector3(2.15,1.5,3.4),Vector3(2.1,1.25,4.35),Vector3(2.1,1.25,4.35),Vector3(2.1,1.25,4.35),Vector3(2.0,1.25,4.2),Vector3(2.1,1.3,4.7),Vector3(2.2,1.2,4.4),Vector3(1.8,1.65,3.5),Vector3(1.95,1.5,4.4),Vector3(0.75,1.35,2.3),Vector3(2.8,3.4,9.2),Vector3(2.25,1.18,4.6)]

static func build(car: CharacterBody3D) -> void:
	var root := Node3D.new()
	root.name = "CustomVehicle"
	car.add_child(root)
	var world: Node3D = car.world
	var paint := StandardMaterial3D.new()
	paint.albedo_color = car.paint
	paint.metallic = 0.35
	paint.roughness = 0.4
	paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color("273f4b")
	glass.roughness = 0.24
	glass.metallic = 0.3
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	var dark: Material = world.material(Color("222a30"))
	var metal: Material = world.material(Color("9ca8af"))
	if car.tier == BUS:
		box(root, Vector3(0, 1.1, 0), Vector3(2.8, 1.1, 9.2), paint)
		box(root, Vector3(0, 2.42, 0), Vector3(2.72, 1.55, 9.05), glass)
		box(root, Vector3(0, 3.25, 0), Vector3(2.8, 0.3, 9.2), paint)
		for side in [-1, 1]:
			for z in [-4.53, -3.1, -1.55, 0.0, 1.55, 3.1, 4.53]:
				box(root, Vector3(side * 1.37, 2.42, z), Vector3(0.06, 1.55, 0.11), paint)
			box(root, Vector3(side, 1.1, -4.62), Vector3(0.48, 0.22, 0.1), world.material(Color("f3e4b0")))
			box(root, Vector3(side, 1.1, 4.62), Vector3(0.4, 0.25, 0.1), world.material(Color("b84037")))
			make_wheel(car, root, Vector3(side * 1.15, 0.52, -2.85), true, 0.52, 0.4)
			make_wheel(car, root, Vector3(side * 1.15, 0.52, 2.85), false, 0.52, 0.4)
		box(root, Vector3(0, 0.75, -4.63), Vector3(2.75, 0.2, 0.12), dark)
		box(root, Vector3(0, 0.75, 4.63), Vector3(2.75, 0.2, 0.12), dark)
		world.visuals.merge_beetle_body(root)
		shadow(car, SIZES[BUS])
		return
	if car.tier == 9:
		box(root,Vector3(0,0.65,0),Vector3(0.28,0.22,1.4),dark)
		loft(root,[Vector4(-0.75,0.25,0.65,1.05),Vector4(-0.3,0.34,0.6,1.2),Vector4(0.15,0.22,0.65,1.05)],paint)
		box(root,Vector3(0,0.97,0.52),Vector3(0.38,0.13,0.8),dark)
		box(root,Vector3(0,1.2,-0.72),Vector3(0.8,0.07,0.08),metal)
		box(root,Vector3(0,1.02,-0.9),Vector3(0.34,0.24,0.1),world.material(Color("f3e4b0")))
		for side in [-1,1]:
			segment(root,Vector3(side*0.17,0.45,-0.94),Vector3(side*0.17,1.13,-0.65),0.045,metal)
			segment(root,Vector3(side*0.16,0.45,0.95),Vector3(side*0.16,0.75,0.2),0.05,metal)
		make_wheel(car,root,Vector3(0,0.36,-0.95),true,0.36,0.18)
		make_wheel(car,root,Vector3(0,0.36,0.95),false,0.36,0.21)
		world.visuals.merge_beetle_body(root)
		shadow(car,Vector3(0.55,0.7,2.1))
		car.rider = Node3D.new()
		car.rider.name = "Rider"
		root.add_child(car.rider)
		var skin: Material = world.material(Color("75482f"))
		var shirt: Material = world.material(Color("eeeade"))
		var jeans: Material = world.material(Color("264f84"))
		segment(car.rider,Vector3(0,1.13,0.38),Vector3(0,1.53,-0.05),0.18,shirt)
		var head := SphereMesh.new()
		head.radius = 0.13
		head.height = 0.28
		head.radial_segments = 12
		head.rings = 6
		piece(car.rider,head,Transform3D(Basis.IDENTITY,Vector3(0,1.72,-0.17)),skin)
		for side in [-1,1]:
			segment(car.rider,Vector3(side*0.14,1.15,0.4),Vector3(side*0.3,0.81,-0.02),0.095,jeans)
			segment(car.rider,Vector3(side*0.3,0.81,-0.02),Vector3(side*0.25,0.52,0.25),0.08,jeans)
			segment(car.rider,Vector3(side*0.17,1.48,-0.05),Vector3(side*0.35,1.22,-0.72),0.065,skin)
		car.rider.visible = false
		return
	var size: Vector3 = SIZES[car.tier]
	var half := size.z/2
	var width := size.x/2-0.08
	var common: bool = car.tier >= 7
	var deck := 0.8 if common else 0.65
	loft(root,[Vector4(-half,width*0.7,0.35,deck-0.1),Vector4(-half*0.7,width,0.3,deck),Vector4(half*0.7,width,0.3,deck),Vector4(half,width*0.84,0.4,deck-0.05)],paint)
	var front := -0.65 if common else -0.45
	var rear := 0.75 if car.tier != 7 else 1.2
	loft(root,[Vector4(front-0.4,width*0.85,deck,deck+0.05),Vector4(front,width*0.72,deck,size.y-0.1),Vector4(rear,width*0.72,deck,size.y-0.1),Vector4(rear+0.4,width*0.85,deck,deck+0.04)],glass)
	box(root,Vector3(0,size.y-0.08,(front+rear)/2),Vector3(width*1.45,0.08,rear-front),paint)
	for side in [-1,1]:
		box(root,Vector3(side*width*0.74,(deck+size.y)/2,0.2),Vector3(0.07,size.y-deck,0.1),paint)
		box(root,Vector3(side*width*0.65,deck-0.05,-half-0.015),Vector3(0.4,0.11,0.08),world.material(Color("e9e6ce")))
		box(root,Vector3(side*width*0.65,deck-0.05,half+0.015),Vector3(0.35,0.1,0.08),world.material(Color("b84037")))
		for z in [-half*0.64,half*0.64]:
			make_wheel(car,root,Vector3(side*width,0.36,z),z<0,0.36,0.22)
	if car.tier == SUPERCAR:
		for side in [-1, 1]:
			box(root, Vector3(side * width * 0.8, 0.53, 0), Vector3(0.32, 0.19, 3.4), metal)
		box(root, Vector3(0, 0.91, half * 0.82), Vector3(size.x, 0.08, 0.38), dark)
	elif car.tier == 4:
		box(root,Vector3(0,deck+0.02,-1.15),Vector3(0.23,0.025,1.0),dark)
	elif car.tier == 5:
		for side in [-1,1]:
			box(root,Vector3(side*width,0.55,0.75),Vector3(0.05,0.18,0.6),dark)
	elif car.tier == 6:
		box(root,Vector3(0,1.0,half*0.85),Vector3(size.x+0.15,0.09,0.32),dark)
		for side in [-1,1]:
			box(root,Vector3(side*0.65,0.8,half*0.85),Vector3(0.06,0.4,0.1),dark)
	elif car.tier == 7:
		box(root,Vector3(0,0.5,half),Vector3(size.x*0.9,0.16,0.16),dark)
	else:
		box(root,Vector3(0,deck+0.04,half*0.8),Vector3(width*1.8,0.08,0.7),paint)
	world.visuals.merge_beetle_body(root)
	shadow(car,size)

static func shadow(car: CharacterBody3D, size: Vector3) -> void:
	var proxy := BoxMesh.new()
	proxy.size = size*Vector3(0.85,0.65,0.9)
	var node := piece(car,proxy,Transform3D(Basis.IDENTITY,Vector3(0,size.y*0.45,0)),car.world.material(Color("293139")))
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	node.add_to_group("car_shadow")

static func box(parent: Node3D, at: Vector3, size: Vector3, mat: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	piece(parent,mesh,Transform3D(Basis.IDENTITY,at),mat)

static func piece(parent: Node3D, mesh: Mesh, transform: Transform3D, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.transform = transform
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node

static func segment(parent: Node3D, start: Vector3, end: Vector3, radius: float, mat: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = start.distance_to(end)
	mesh.radial_segments = 10
	var node := piece(parent,mesh,Transform3D(Basis.IDENTITY,(start+end)/2),mat)
	node.quaternion = Quaternion(Vector3.UP,(end-start).normalized())

static func loft(parent: Node3D, profiles: Array, mat: Material) -> void:
	var vertices: Array[Vector3] = []
	for p in profiles:
		for xy in [Vector2(-p.y,p.z),Vector2(-p.y,p.w-0.08),Vector2(-p.y*0.7,p.w),Vector2(p.y*0.7,p.w),Vector2(p.y,p.w-0.08),Vector2(p.y,p.z)]:
			vertices.append(Vector3(xy.x,xy.y,p.x))
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in profiles.size()-1:
		for side in 6:
			var a := ring*6+side
			var b := ring*6+(side+1)%6
			for index in [a,b,b+6,a,b+6,a+6]:
				tool.add_vertex(vertices[index])
	for i in range(1,5):
		for index in [0,i+1,i,(profiles.size()-1)*6,(profiles.size()-1)*6+i,(profiles.size()-1)*6+i+1]:
			tool.add_vertex(vertices[index])
	tool.generate_normals()
	piece(parent,tool.commit(),Transform3D.IDENTITY,mat)

static func make_wheel(car: CharacterBody3D, parent: Node3D, at: Vector3, front: bool, radius: float, width: float) -> void:
	var hub := Node3D.new()
	hub.position = at
	parent.add_child(hub)
	if front:
		car.steering_hubs.append(hub)
	var spin := Node3D.new()
	hub.add_child(spin)
	car.wheels.append(spin)
	var sizes := [Vector2(radius,width),Vector2(radius*0.58,width+0.015)]
	for index in sizes.size():
		var size: Vector2 = sizes[index]
		var tire := CylinderMesh.new()
		tire.top_radius = size.x
		tire.bottom_radius = size.x
		tire.height = size.y
		tire.radial_segments = 12
		var wheel := piece(spin,tire,Transform3D(Basis(Vector3.FORWARD,PI/2),Vector3.ZERO),car.world.material(Color("252a2e") if index == 0 else Color("9ca8af")))
		wheel.add_to_group("car_simple")
