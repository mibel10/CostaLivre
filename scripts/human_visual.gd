extends Node3D

const HUMAN = preload("res://assets/models/CesiumMan.glb")
const OUTFIT_SHIRTS := [Color("eeeade"),Color("9f4939"),Color("385b79"),Color("6d8052"),Color("b88c50"),Color("6f5271")]
const OUTFIT_PANTS := [Color("264f84"),Color("383b43"),Color("566657"),Color("634c3d"),Color("374c68"),Color("4f5155")]
var animation: AnimationPlayer
var original_meshes := {}
var police := false
var cj_style := false
var outfit_index := -1
static var outfit_cache := {}

func _ready() -> void:
	var actor: Node3D = HUMAN.instantiate()
	actor.scale = Vector3.ONE * 1.22
	actor.rotation.y = PI
	add_child(actor)
	for mesh in actor.find_children("*", "MeshInstance3D", true, false):
		original_meshes[mesh]=mesh.mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("78909c") if not police else Color("405b80")
		material.roughness = 0.9
		mesh.material_override = material
		if cj_style or outfit_index >= 0:
			apply_street_clothes(mesh)
			if not cj_style:
				mesh.lod_bias = 0.5
	var players := actor.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return
	animation = players[0]
	if not animation.get_animation_list().has("Animation"):
		animation = null
		return
	var walk := animation.get_animation("Animation")
	if walk == null:
		animation = null
		return
	walk.loop_mode = Animation.LOOP_LINEAR
	var library: AnimationLibrary = animation.get_animation_library("")
	if not library.has_animation("Idle"):
		var idle := Animation.new()
		idle.length = 1
		idle.loop_mode = Animation.LOOP_LINEAR
		for i in walk.get_track_count():
			var type := walk.track_get_type(i)
			if type not in [Animation.TYPE_ROTATION_3D,Animation.TYPE_POSITION_3D,Animation.TYPE_SCALE_3D]:
				continue
			var track := idle.add_track(type)
			idle.track_set_path(track,walk.track_get_path(i))
			if type == Animation.TYPE_ROTATION_3D:
				var pose := walk.rotation_track_interpolate(i,0).slerp(walk.rotation_track_interpolate(i,walk.length/2),0.5)
				idle.track_insert_key(track,0,pose)
			elif type == Animation.TYPE_POSITION_3D:
				idle.track_insert_key(track,0,walk.position_track_interpolate(i,0).lerp(walk.position_track_interpolate(i,walk.length/2),0.5))
			else:
				idle.track_insert_key(track,0,walk.scale_track_interpolate(i,0))
		library.add_animation("Idle",idle)
	if not library.has_animation("DoorWork"):
		var work: Animation = library.get_animation("Idle").duplicate()
		work.length = 0.42
		for i in work.get_track_count():
			var path := String(work.track_get_path(i))
			if work.track_get_type(i) != Animation.TYPE_ROTATION_3D or not ("arm_joint" in path and ("__2_" in path or "__3_" in path)):
				continue
			var rest: Quaternion = work.track_get_key_value(i,0)
			var side := -1.0 if "joint_L" in path else 1.0
			work.track_insert_key(i,0.0,rest*Quaternion(Vector3.RIGHT,0.38)*Quaternion(Vector3.FORWARD,side*0.15))
			work.track_insert_key(i,0.21,rest*Quaternion(Vector3.RIGHT,0.68)*Quaternion(Vector3.FORWARD,side*0.27))
			work.track_insert_key(i,0.42,work.track_get_key_value(i,0))
		library.add_animation("DoorWork",work)
	animation.play("Idle")
	animation.advance(0)

func animate(speed: float) -> void:
	if animation == null:
		return
	if speed < 0.2:
		animation.speed_scale = 1
		if animation.current_animation != "Idle":
			animation.play("Idle",0.18)
	else:
		animation.speed_scale = clampf(speed / 3.0, 0.55, 2.5)
		if animation.current_animation != "Animation":
			animation.play("Animation",0.18)

func pose_vehicle_entry(actor: Node3D, car: Node3D, side: float, elapsed: float) -> void:
	var width: float = car.Catalog.SIZES[car.tier].x
	var target := actor.to_local(car.to_global(Vector3(side*(width/2+0.3),0,-0.35)))
	var approach := smoothstep(0.0,0.4,elapsed)
	var slip := smoothstep(1.6,2.0,elapsed)
	var working := sin(elapsed*17.0)*0.055*approach*(1.0-slip)
	position = target*approach + Vector3(0,-0.15*approach,-working).rotated(Vector3.UP,car.heading)
	position = position.lerp(actor.to_local(car.global_position),slip)
	var facing := car.global_position-actor.to_global(position)
	rotation.y = atan2(-facing.x,-facing.z)-actor.rotation.y
	rotation.x = (0.27+working)*approach*(1.0-slip)
	if animation != null and elapsed >= 0.4 and elapsed < 1.65:
		animation.speed_scale = 1.0
		if animation.current_animation != "DoorWork":
			animation.play("DoorWork",0.12)
	else:
		animate(1.0)

func apply_street_clothes(instance: MeshInstance3D) -> void:
	# Color the rest-pose vertices, so clothes follow the existing skin and bones.
	var source: Mesh = instance.mesh
	var dressed := ImporterMesh.new()
	var index := posmod(outfit_index,6) if outfit_index >= 0 else 0
	var skin_index := 0 if cj_style else index
	var cache_key := str(index)+":"+str(skin_index)
	var skins := [Color("75482f"),Color("bd8461"),Color("4e3026"),Color("d4a683"),Color("8a593c"),Color("a66d50")]
	if outfit_cache.has(cache_key):
		instance.mesh = outfit_cache[cache_key]
		var cached_mat: StandardMaterial3D=instance.material_override
		if cached_mat==null:
			cached_mat=StandardMaterial3D.new()
		cached_mat.vertex_color_use_as_albedo = true
		cached_mat.roughness = 0.92
		instance.material_override = cached_mat
		return
	var bounds := source.get_aabb()
	var up := bounds.size.max_axis_index()
	var side := 1 if up == 2 else 0
	var forward := 0 if up == 2 else 2
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX].duplicate()
		var colors := PackedColorArray()
		for i in vertices.size():
			var point := vertices[i]
			var height: float = (point[up]-bounds.position[up])/bounds.size[up]
			var lateral: float = absf(point[side]-bounds.get_center()[side])
			var color: Color = skins[skin_index]
			if height < 0.055:
				color = Color("202025") if height > 0.018 else Color("b5b2a7")
			elif height < 0.49:
				color = OUTFIT_PANTS[index]
			elif height < 0.515:
				color = Color("27241f")
			elif height < 0.81 and lateral < 0.18:
				color = OUTFIT_SHIRTS[index]
				if height > 0.765 and lateral < 0.075:
					color = skins[skin_index]
			elif height > 0.945:
				color = Color("181612")
			if height > 0.835:
				point[side] = bounds.get_center()[side]+(point[side]-bounds.get_center()[side])*0.6
				point[forward] = bounds.get_center()[forward]+(point[forward]-bounds.get_center()[forward])*0.6
				var neck: float = bounds.position[up]+bounds.size[up]*0.835
				point[up] = neck+(point[up]-neck)*0.85
				vertices[i] = point
			colors.append(color)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_COLOR] = colors
		dressed.add_surface(source.surface_get_primitive_type(surface), arrays)
	dressed.generate_lods(60.0, 0.0, [])
	var dressed_mesh := dressed.get_mesh()
	instance.mesh = dressed_mesh
	outfit_cache[cache_key] = dressed_mesh
	var clothes: StandardMaterial3D=instance.material_override
	if clothes==null:
		clothes=StandardMaterial3D.new()
	clothes.vertex_color_use_as_albedo = true
	clothes.roughness = 0.92
	instance.material_override = clothes

func apply_outfit(selected: int) -> void:
	outfit_index=clampi(selected,0,5)
	for mesh in original_meshes:
		if is_instance_valid(mesh):
			mesh.mesh=original_meshes[mesh]
			apply_street_clothes(mesh)
