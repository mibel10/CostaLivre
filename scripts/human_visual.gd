extends Node3D

const HUMAN = preload("res://assets/models/HumanoCostaLivre.glb")
const OUTFIT_SHIRTS := [Color("eeeade"),Color("9f4939"),Color("385b79"),Color("6d8052"),Color("b88c50"),Color("6f5271")]
const OUTFIT_PANTS := [Color("264f84"),Color("383b43"),Color("566657"),Color("634c3d"),Color("374c68"),Color("4f5155")]
var animation: AnimationPlayer
var original_meshes := {}
var police := false
var cj_style := false
var outfit_index := -1
static var outfit_cache := {}
var weapon_mesh: MeshInstance3D
var weapon_magazine: MeshInstance3D
var weapon_tween: Tween
var displayed_weapon := -1
var weapon_recoil := 0.0
var rig: Node3D
var crouch_tween: Tween

func _ready() -> void:
	var actor: Node3D = HUMAN.instantiate()
	actor.scale = Vector3.ONE * 1.22
	actor.rotation.y = PI
	add_child(actor)
	rig = actor
	for mesh in actor.find_children("*", "MeshInstance3D", true, false):
		original_meshes[mesh]=mesh.mesh
		apply_street_clothes(mesh)
		if not cj_style and not police:
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

func show_crouch(crouched: bool) -> void:
	if crouch_tween != null:
		crouch_tween.kill()
	crouch_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	crouch_tween.tween_property(rig, "scale:y", 1.22 * (0.66 if crouched else 1.0), 0.16)
	crouch_tween.tween_property(rig, "position:y", -0.28 if crouched else 0.0, 0.16)

func build_weapon(world: Node3D) -> MeshInstance3D:
	var skeleton: Skeleton3D = find_children("*", "Skeleton3D", true, false)[0]
	var hand := BoneAttachment3D.new()
	hand.bone_name = "Skeleton_arm_joint_R__3_"
	skeleton.add_child(hand)
	weapon_mesh = world.box(hand, Vector3.ZERO, Vector3(0.07, 0.09, 0.24), Color("25313a"))
	weapon_magazine = world.box(weapon_mesh, Vector3(0, -0.1, 0.06), Vector3(0.06, 0.16, 0.08), Color("25313a"))
	weapon_mesh.hide()
	return weapon_mesh

func show_weapon(selected: int) -> void:
	if selected == displayed_weapon:
		return
	displayed_weapon = selected
	if weapon_tween != null:
		weapon_tween.kill()
	weapon_recoil = 0.0
	if selected == 0 and not weapon_mesh.visible:
		return
	weapon_mesh.show()
	weapon_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	weapon_tween.tween_property(weapon_mesh, "position:y", -0.13, 0.1)
	weapon_tween.parallel().tween_property(weapon_mesh, "scale:z", 0.2, 0.1)
	if selected > 0:
		var length: float = [1.0, 1.8, 1.35, 1.6, 3.5, 3.0, 4.0][selected - 1]
		weapon_tween.tween_property(weapon_mesh, "position:y", 0.0, 0.14)
		weapon_tween.parallel().tween_property(weapon_mesh, "scale:z", length, 0.14)
	else:
		weapon_tween.tween_callback(weapon_mesh.hide)

func kick_weapon(selected: int) -> void:
	show_weapon(selected)
	weapon_recoil = 0.36 if selected >= 5 else 0.20

func update_weapon_pose(delta: float, reload_fraction: float) -> void:
	var handling := sin(clampf(reload_fraction, 0.0, 1.0) * PI)
	var magazine_drop := smoothstep(0.15, 0.33, reload_fraction) * (1.0 - smoothstep(0.57, 0.82, reload_fraction))
	weapon_mesh.rotation = Vector3(-0.5 * handling - weapon_recoil, 0.18 * handling, 0.34 * handling)
	weapon_magazine.position.y = -0.1 - 0.14 * magazine_drop
	weapon_recoil = move_toward(weapon_recoil, 0.0, delta * 2.8)

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

func start_driver_ragdoll(launch: Vector3) -> void:
	if animation != null:
		animation.stop(true)
	var skeleton: Skeleton3D = find_children("*","Skeleton3D",true,false)[0]
	var simulator := PhysicalBoneSimulator3D.new()
	skeleton.add_child(simulator)
	var bodies: Array[PhysicalBone3D] = []
	for index in skeleton.get_bone_count():
		var bone_name := String(skeleton.get_bone_name(index))
		if not ("torso" in bone_name or "neck_joint_1" in bone_name or ("arm_joint" in bone_name and not "__3_" in bone_name) or ("leg_joint" in bone_name and (bone_name.ends_with("_1") or bone_name.ends_with("_2")))):
			continue
		var rest := skeleton.get_bone_global_pose(index)
		var axis := Vector3(0,0.15,0)
		var children := skeleton.get_bone_children(index)
		if not children.is_empty():
			axis = rest.affine_inverse()*skeleton.get_bone_global_pose(children[0]).origin
		var body := PhysicalBone3D.new()
		body.name = bone_name
		body.collision_layer = 0
		body.collision_mask = 1
		body.mass = 4 if "torso" in bone_name else 1.5
		body.set("bone_name",skeleton.get_bone_name(index))
		simulator.add_child(body)
		if not bodies.is_empty():
			body.joint_type = PhysicalBone3D.JOINT_TYPE_CONE
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.11 if "torso" in bone_name or "neck" in bone_name else 0.065
		capsule.height = maxf(capsule.radius*2,axis.length()+capsule.radius)
		var shape := CollisionShape3D.new()
		shape.shape = capsule
		shape.position = axis*0.5
		if axis.length_squared() > 0.0001:
			shape.basis = Basis(Quaternion(Vector3.UP,axis.normalized()))
		body.add_child(shape)
		bodies.append(body)
	simulator.physical_bones_start_simulation()
	for body in bodies:
		body.linear_velocity = launch
		body.angular_velocity = Vector3(1.4,0.3,2.0)
	await get_tree().create_timer(2.0,false).timeout
	queue_free()

func apply_street_clothes(instance: MeshInstance3D) -> void:
	# The baked UVs encode wardrobe regions and tonal variation, independent of skinning.
	var source: Mesh = instance.mesh
	var index := posmod(outfit_index,6) if outfit_index >= 0 else 0
	var skin_index := 0 if cj_style else index
	var cache_key := "%d:%d:%s" % [index, skin_index, police]
	var clothes := StandardMaterial3D.new()
	clothes.vertex_color_use_as_albedo = true
	clothes.roughness = 0.85
	instance.material_override = clothes
	if outfit_cache.has(cache_key):
		instance.mesh = outfit_cache[cache_key]
		return
	var dressed := ImporterMesh.new()
	var skins := [Color("75482f"),Color("bd8461"),Color("4e3026"),Color("d4a683"),Color("8a593c"),Color("a66d50")]
	var shirt: Color = Color("293e56") if police else OUTFIT_SHIRTS[index]
	var pants: Color = Color("252e39") if police else OUTFIT_PANTS[index]
	var skin: Color = skins[skin_index]
	var hair: Color = [Color("211814"), Color("312117"), Color("161516"), Color("3b271b"), Color("1b1715"), Color("2d211c")][skin_index]
	var palette: Array[Color] = [
		skin, shirt, pants, Color("a9a6a0"), Color("24262b"), hair,
		Color("d3c6bb"), Color("251d19"), skin.darkened(0.22),
		pants.darkened(0.22), shirt.darkened(0.25), skin.darkened(0.3),
		hair.lightened(0.07), Color("78716b")
	]
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var regions: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var colors := PackedColorArray()
		for uv in regions:
			var region := clampi(roundi(uv.x * 16.0), 0, palette.size() - 1)
			colors.append(palette[region].darkened(1.0 - uv.y))
		arrays[Mesh.ARRAY_COLOR] = colors
		dressed.add_surface(source.surface_get_primitive_type(surface), arrays)
	dressed.generate_lods(60.0, 0.0, [])
	var dressed_mesh := dressed.get_mesh()
	instance.mesh = dressed_mesh
	outfit_cache[cache_key] = dressed_mesh

func apply_outfit(selected: int) -> void:
	outfit_index=clampi(selected,0,5)
	for mesh in original_meshes:
		if is_instance_valid(mesh):
			mesh.mesh=original_meshes[mesh]
			apply_street_clothes(mesh)
