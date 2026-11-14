extends Node3D

const HUMAN = preload("res://assets/models/HumanoCostaLivre.glb")
const OUTFIT_SHIRTS := [Color("eeeade"),Color("9f4939"),Color("385b79"),Color("6d8052"),Color("b88c50"),Color("6f5271")]
const OUTFIT_PANTS := [Color("264f84"),Color("383b43"),Color("566657"),Color("634c3d"),Color("374c68"),Color("4f5155")]
var animation: AnimationPlayer
var original_meshes := {}
var police := false
var cj_style := false
var outfit_index := -1
var accessory_index := 0
var cosmetic_attachment: Node3D
static var outfit_cache := {}
var weapon_mesh: MeshInstance3D
var weapon_magazine: MeshInstance3D
var weapon_tween: Tween
var displayed_weapon := -1
var weapon_recoil := 0.0
var weapon_aim_hold := 0.0
var weapon_aim: WeaponAim
var rig: Node3D
var crouch_tween: Tween
var emote_lock := 0.0
var golden_dancing := false
var idle_sleep := 0.0

class WeaponAim extends SkeletonModifier3D:
	var visual: Node3D
	var shoulder: int
	var elbow: int
	var wrist: int
	var pitch := 0.0

	func _process_modification_with_delta(_delta: float) -> void:
		if influence <= 0.0:
			return
		var skeleton := get_skeleton()
		var to_skeleton := skeleton.global_basis.inverse()
		var forward := visual.global_basis.orthonormalized() * Vector3(0, sin(pitch), -cos(pitch))
		var aim := (to_skeleton * forward).normalized()
		var up := (to_skeleton * Vector3.UP).normalized()
		# Keep a slight bend in the elbow while the wrist lines up with the sight.
		align_segment(skeleton, shoulder, elbow, (aim - up * 0.19).normalized())
		align_segment(skeleton, elbow, wrist, (aim + up * 0.12).normalized())
		var grip := skeleton.get_bone_global_pose(wrist)
		grip.basis = Basis.looking_at(aim, up).scaled_local(grip.basis.get_scale())
		skeleton.set_bone_global_pose(wrist, grip)

	func align_segment(skeleton: Skeleton3D, bone: int, child: int, direction: Vector3) -> void:
		var pose := skeleton.get_bone_global_pose(bone)
		var offset := skeleton.get_bone_global_pose(child).origin - pose.origin
		pose.basis = Basis(Quaternion(offset.normalized(), direction)) * pose.basis
		skeleton.set_bone_global_pose(bone, pose)

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
	for emote in ["Wave","Griddy","TakeTheL","Dance","GoldenWind","Flinch"]:
		if not library.has_animation(emote):
			var gesture: Animation = library.get_animation("Idle").duplicate()
			gesture.length = 8.0 if emote == "GoldenWind" else 1.4
			gesture.loop_mode = Animation.LOOP_LINEAR if emote in ["Griddy","Dance"] else Animation.LOOP_NONE
			if emote == "GoldenWind":
				gesture.loop_mode = Animation.LOOP_LINEAR
				# Slide, air guitar, arms up/down, crossed hug, spin, hands on thighs.
				var arm_swing := [0.0,0.35,-0.35,0.45,-0.45,0.3,-0.3,0.15,0.15,-1.0,-1.0,-1.0,0.2,-0.2,0.35,-0.35,0.0]
				var arm_lift := [0.0,0.5,0.85,0.5,0.85,0.5,0.85,2.5,0.2,1.1,1.1,1.1,-0.25,-0.25,0.65,0.85,0.0]
				var leg_step := [0.0,0.4,-0.4,0.4,-0.4,0.35,-0.35,0.2,0.35,0.4,-0.4,0.2,0.4,0.35,-0.35,0.3,0.0]
				var torso_sway := [0.0,0.08,-0.08,0.12,-0.12,0.08,-0.08,0.0,0.12,0.1,-0.1,0.0,0.12,-0.12,0.08,-0.08,0.0]
				for track in gesture.get_track_count():
					var path := String(gesture.track_get_path(track)).to_lower()
					if gesture.track_get_type(track) != Animation.TYPE_ROTATION_3D:
						continue
					var arm := "arm_joint" in path and ("__2_" in path or "__3_" in path)
					var leg := "leg_joint" in path
					var torso := "torso_joint" in path
					if not arm and not leg and not torso:
						continue
					var rest: Quaternion = gesture.track_get_key_value(track,0)
					var side := -1.0 if "_l_" in path else 1.0
					while gesture.track_get_key_count(track) > 0:
						gesture.track_remove_key(track,0)
					for beat in arm_swing.size():
						var pose := rest
						if arm:
							if "__2_" in path:
								pose = rest*Quaternion(Vector3.RIGHT,arm_lift[beat])*Quaternion(Vector3.FORWARD,side*arm_swing[beat])
							else:
								pose = rest*Quaternion(Vector3.RIGHT,0.35+absf(arm_lift[beat])*0.5)*Quaternion(Vector3.FORWARD,-side*arm_swing[beat]*0.45)
						elif leg:
							var step: float = leg_step[beat]*side
							if "leg_joint_l_2" in path or "leg_joint_r_2" in path:
								step = maxf(0.0,-step)*0.8
							elif "leg_joint_l_3" in path or "leg_joint_r_3" in path or "leg_joint_l_5" in path or "leg_joint_r_5" in path:
								step *= -0.3
							pose = rest*Quaternion(Vector3.RIGHT,step)*Quaternion(Vector3.FORWARD,side*absf(leg_step[beat])*0.35)
						else:
							pose = rest*Quaternion(Vector3.FORWARD,torso_sway[beat])*Quaternion(Vector3.RIGHT,-0.1 if beat % 2 == 1 else 0.0)
						gesture.track_insert_key(track,beat*0.5,pose)
			else:
				for track in gesture.get_track_count():
					var path := String(gesture.track_get_path(track))
					if gesture.track_get_type(track) != Animation.TYPE_ROTATION_3D or not ("arm_joint" in path and ("__2_" in path or "__3_" in path)):
						continue
					var side := -1.0 if "joint_L" in path else 1.0
					var raises_arm: bool = emote in ["Griddy","Dance","Flinch"] or (emote == "Wave" and side > 0) or (emote == "TakeTheL" and side < 0)
					if not raises_arm:
						continue
					var rest: Quaternion = gesture.track_get_key_value(track,0)
					while gesture.track_get_key_count(track) > 0:
						gesture.track_remove_key(track,0)
					var angle := 0.75 if emote == "Griddy" else (0.55 if emote == "Dance" else 1.35)
					gesture.track_insert_key(track,0.0,rest)
					var first_pose: Quaternion = rest*Quaternion(Vector3.FORWARD,side*0.75) if emote == "Dance" else rest*Quaternion(Vector3.RIGHT,angle)*Quaternion(Vector3.FORWARD,side*0.35)
					gesture.track_insert_key(track,0.35,first_pose)
					gesture.track_insert_key(track,0.7,rest)
					if emote in ["Griddy","Dance"]:
						var second_pose: Quaternion = rest*Quaternion(Vector3.FORWARD,-side*0.75) if emote == "Dance" else rest*Quaternion(Vector3.RIGHT,-angle)*Quaternion(Vector3.FORWARD,-side*0.35)
						gesture.track_insert_key(track,1.05,second_pose)
						gesture.track_insert_key(track,1.4,rest)
			library.add_animation(emote,gesture)
	animation.play("Idle")
	animation.advance(0)
	animation.pause()
	set_process(false)
	if police:
		var skeleton: Skeleton3D = actor.find_children("*", "Skeleton3D", true, false)[0]
		var world: Node3D = get_parent().world
		var chest := uniform_attachment(skeleton, "torso_joint_3")
		world.box(chest, Vector3(0, -0.08, 0), Vector3(0.30, 0.33, 0.21), Color("111d30"))
		for side in [-1.0, 1.0]:
			world.box(chest, Vector3(side * 0.15, 0.065, 0), Vector3(0.045, 0.018, 0.19), Color("b8c9d5"))
		world.box(chest, Vector3(-0.09, 0.02, -0.13), Vector3(0.05, 0.065, 0.012), Color("e4bc55"))
		world.box(chest, Vector3(0.11, -0.01, -0.14), Vector3(0.045, 0.1, 0.04), Color("22282d"))
		for back in [false, true]:
			var label := Label3D.new()
			label.text = "POLÍCIA"
			label.font_size = 32
			label.pixel_size = 0.0014
			label.outline_size = 0
			label.double_sided = false
			label.modulate = Color("e1e8ec")
			label.position = Vector3(0, -0.08, 0.114 if back else -0.114)
			label.rotation.y = PI if not back else 0.0
			chest.add_child(label)
		var head := uniform_attachment(skeleton, "Skeleton_neck_joint_2")
		var cap := MeshInstance3D.new()
		var shape := CylinderMesh.new()
		shape.top_radius = 0.094
		shape.bottom_radius = 0.106
		shape.height = 0.065
		shape.radial_segments = 12
		cap.mesh = shape
		cap.material_override = world.material(Color("183659"))
		cap.position = Vector3(0, 0.24, -0.015)
		head.add_child(cap)
		world.box(head, Vector3(0, 0.205, -0.09), Vector3(0.18, 0.018, 0.14), Color("101e32"))
		world.box(head, Vector3(0, 0.24, -0.115), Vector3(0.035, 0.038, 0.008), Color("e4bc55"))

func uniform_attachment(skeleton: Skeleton3D, bone_name: String) -> Node3D:
	var attachment := BoneAttachment3D.new()
	attachment.bone_name = bone_name
	skeleton.add_child(attachment)
	var pivot := Node3D.new()
	var pose := skeleton.get_bone_global_pose(skeleton.find_bone(bone_name))
	var world_pose := skeleton.global_transform * pose
	pivot.transform = world_pose.affine_inverse() * Transform3D(global_basis.orthonormalized(), world_pose.origin)
	attachment.add_child(pivot)
	return pivot

func animate(speed: float) -> void:
	if animation == null or emote_lock > 0.0:
		return
	if speed < 0.2:
		animation.speed_scale = 1
		if animation.assigned_animation != "Idle":
			animation.play("Idle",0.18)
			idle_sleep = 0.22
			set_process(true)
	else:
		idle_sleep = 0.0
		set_process(false)
		animation.speed_scale = clampf(speed / 3.0, 0.55, 2.5)
		if animation.assigned_animation != "Animation" or not animation.is_playing():
			animation.play("Animation",0.18)

func play_emote(name: String) -> void:
	if animation == null:
		return
	var gesture: String = str({"wave":"Wave","griddy":"Griddy","take_l":"TakeTheL","dance":"Dance","torture_dance":"GoldenWind"}.get(name,""))
	if gesture.is_empty() or not animation.has_animation(gesture):
		return
	golden_dancing = gesture == "GoldenWind"
	rig.rotation.y = PI
	emote_lock = 8.0 if golden_dancing else (1.8 if gesture != "Griddy" else 2.4)
	set_process(true)
	animation.speed_scale = 1.0
	animation.play(gesture,0.12)

func play_pickup_animation() -> void:
	if animation == null or not animation.has_animation("DoorWork"):
		return
	emote_lock = 0.8
	set_process(true)
	animation.speed_scale = 1.0
	animation.play("DoorWork",0.1)

func _process(delta: float) -> void:
	if emote_lock <= 0.0:
		idle_sleep = maxf(0.0,idle_sleep-delta)
		if idle_sleep == 0.0:
			if animation != null and animation.assigned_animation == "Idle": animation.pause()
			set_process(false)
		return
	if emote_lock > 0.0:
		emote_lock = maxf(0.0,emote_lock-delta)
		if golden_dancing:
			var elapsed := 8.0-emote_lock
			rig.rotation.y = PI+TAU*clampf((elapsed-5.0)/0.5,0.0,1.0)
		if emote_lock == 0.0:
			golden_dancing = false
			rig.rotation.y = PI
			animate(0.0)

func show_crouch(crouched: bool) -> void:
	if crouch_tween != null:
		crouch_tween.kill()
	crouch_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	crouch_tween.tween_property(rig, "scale:y", 1.22 * (0.66 if crouched else 1.0), 0.16)
	crouch_tween.tween_property(rig, "position:y", -0.28 if crouched else 0.0, 0.16)

func build_weapon(world: Node3D) -> MeshInstance3D:
	var skeleton: Skeleton3D = find_children("*", "Skeleton3D", true, false)[0]
	weapon_aim = WeaponAim.new()
	weapon_aim.visual = self
	weapon_aim.wrist = skeleton.find_bone("Skeleton_arm_joint_R__3_")
	weapon_aim.elbow = skeleton.get_bone_parent(weapon_aim.wrist)
	weapon_aim.shoulder = skeleton.get_bone_parent(weapon_aim.elbow)
	weapon_aim.influence = 0.0
	skeleton.add_child(weapon_aim)
	var hand := BoneAttachment3D.new()
	hand.bone_idx = weapon_aim.wrist
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
	weapon_aim_hold = 0.0
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
	weapon_aim_hold = 0.18
	weapon_aim.influence = maxf(weapon_aim.influence, 0.75)

func set_weapon_aim(active: bool, pitch: float, delta: float) -> void:
	weapon_aim_hold = maxf(0.0, weapon_aim_hold - delta)
	weapon_aim.pitch = move_toward(weapon_aim.pitch, pitch, delta * 12.0)
	weapon_aim.influence = move_toward(weapon_aim.influence, 1.0 if active else 0.0, delta * 11.0)

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
	clothes.roughness = 0.74
	clothes.metallic_specular = 0.28
	instance.material_override = clothes
	if outfit_cache.has(cache_key):
		instance.mesh = outfit_cache[cache_key]
		return
	var dressed := ImporterMesh.new()
	var skins := [Color("75482f"),Color("bd8461"),Color("4e3026"),Color("d4a683"),Color("8a593c"),Color("a66d50")]
	var shirt: Color = Color("345778") if police else OUTFIT_SHIRTS[index]
	var pants: Color = Color("142339") if police else OUTFIT_PANTS[index]
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
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var seams := {}
		for i in vertices.size():
			var vertex: Vector3 = vertices[i].snapped(Vector3.ONE*0.0001)
			var key := Vector4(vertex.x,vertex.y,vertex.z,roundf(regions[i].x*16.0))
			if not seams.has(key): seams[key] = []
			seams[key].append(i)
		var smooth := normals.duplicate()
		for group in seams.values():
			for i in group:
				var normal := Vector3.ZERO
				for other in group:
					if normals[i].dot(normals[other])>0.55: normal += normals[other]
				if normal.length_squared()>0.001: smooth[i] = normal.normalized()
		arrays[Mesh.ARRAY_NORMAL] = smooth
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
	outfit_index=clampi(int(selected / 8),0,5)
	accessory_index=clampi(selected % 8,0,3)
	for mesh in original_meshes:
		if is_instance_valid(mesh):
			mesh.mesh=original_meshes[mesh]
			apply_street_clothes(mesh)
	apply_accessory()

func apply_accessory() -> void:
	if is_instance_valid(cosmetic_attachment):
		cosmetic_attachment.queue_free()
	cosmetic_attachment = null
	if accessory_index == 0 or rig == null:
		return
	var skeletons := rig.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return
	var skeleton: Skeleton3D = skeletons[0]
	cosmetic_attachment = uniform_attachment(skeleton, "Skeleton_neck_joint_2")
	var material := StandardMaterial3D.new()
	material.albedo_color = [Color.TRANSPARENT,Color("263b55"),Color("a84342"),Color("101820")][accessory_index]
	if accessory_index == 1:
		var cap := MeshInstance3D.new()
		var shape := CylinderMesh.new()
		shape.top_radius = 0.075
		shape.bottom_radius = 0.12
		shape.height = 0.08
		shape.radial_segments = 12
		cap.mesh = shape
		cap.material_override = material
		cap.position = Vector3(0,0.2,0)
		cosmetic_attachment.add_child(cap)
		var brim := MeshInstance3D.new()
		var brim_shape := BoxMesh.new()
		brim_shape.size = Vector3(0.19,0.015,0.1)
		brim.mesh = brim_shape
		brim.material_override = material
		brim.position = Vector3(0,0.175,-0.1)
		cosmetic_attachment.add_child(brim)
	elif accessory_index == 2:
		var band := MeshInstance3D.new()
		var shape := BoxMesh.new()
		shape.size = Vector3(0.2,0.065,0.19)
		band.mesh = shape
		band.material_override = material
		band.position = Vector3(0,0.08,-0.02)
		cosmetic_attachment.add_child(band)
		var knot := MeshInstance3D.new()
		var knot_shape := BoxMesh.new()
		knot_shape.size = Vector3(0.055,0.095,0.035)
		knot.mesh = knot_shape
		knot.material_override = material
		knot.position = Vector3(0,0.045,0.09)
		knot.rotation.z = 0.25
		cosmetic_attachment.add_child(knot)
	else:
		for side in [-1.0,1.0]:
			var lens := MeshInstance3D.new()
			var shape := BoxMesh.new()
			shape.size = Vector3(0.075,0.045,0.018)
			lens.mesh = shape
			lens.material_override = material
			lens.position = Vector3(side*0.045,0.105,-0.09)
			cosmetic_attachment.add_child(lens)
			var temple := MeshInstance3D.new()
			var temple_shape := BoxMesh.new()
			temple_shape.size = Vector3(0.012,0.012,0.14)
			temple.mesh = temple_shape
			temple.material_override = material
			temple.position = Vector3(side*0.09,0.11,-0.025)
			cosmetic_attachment.add_child(temple)
