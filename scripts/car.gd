extends CharacterBody3D

const Catalog = preload("res://scripts/vehicle_catalog.gd")

var world: Node3D
var net_id := -1
var police_home := Vector3.ZERO
var police_phase := "pursuit"
var last_grounded := Vector3.ZERO
var paint := Color("dd7542")
var police := false
var traffic := false
var speed := 0.0
var heading := 0.0
var driving := false
var wheels: Array[Node3D] = []
var lights: Array[MeshInstance3D] = []
var route: Array[Vector3] = []
var route_index := 0
var siren_clock := 0.0
var hit_cooldown := 0.0
var tier := 0
var owned := false
const MAX_HP := 200.0
var hp := MAX_HP
var model_name := "Sedã"
var stuck_time := 0.0
var steering_hubs: Array[Node3D] = []
var wheel_angle := 0.0
var steering_angle := 0.0
var engine_upgrade := 0.0
var intact_materials := {}
var rider: Node3D
var wreck_timer := -1.0
var exploded := false
var despawn_timer := -1.0
var fire_particles: GPUParticles3D
var smoke_particles: GPUParticles3D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	collision_layer = 4
	collision_mask = 7
	floor_snap_length = 0.5
	platform_floor_layers=0
	platform_wall_layers=0
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	tier = clampi(tier,0,Catalog.NAMES.size()-1)
	shape.size = Catalog.SIZES[tier]
	collider.shape = shape
	collider.position.y = shape.size.y / 2
	collider.position.z = -0.2 if tier in [1,2,3] else 0.0
	add_child(collider)
	world.visuals.build_car(self)
	heading = rotation.y
	model_name = Catalog.NAMES[tier]

func _physics_process(delta: float) -> void:
	if world.network != null and world.network.active():
		var owner_id: int = world.network.owners.get(net_id,0)
		if (world.network.is_client() and (self != world.active_car or hp <= 0)) or (not world.network.is_client() and hp > 0 and owner_id > 0 and owner_id != multiplayer.get_unique_id()):
			if rider != null:
				rider.visible = owner_id > 0
			return
	if rider != null:
		rider.visible = driving and hp > 0
		if not driving:
			get_node("CustomVehicle").rotation.z = 0
	# Parked colliders stay active without repeating floor queries every physics tick.
	if hp > 0 and not driving and not traffic and (not police or police_phase=="parked") and absf(speed)<0.01 and is_on_floor() and Vector2(velocity.x,velocity.z).length_squared()<0.01:
		return
	if hp <= 0:
		if exploded and despawn_timer >= 0 and (world.network == null or not world.network.active() or multiplayer.is_server()):
			despawn_timer = maxf(0.0, despawn_timer - delta)
			if despawn_timer <= 0:
				world.cars.erase(self)
				world.cops.erase(self)
				if police and world.station != null:
					world.station.car_destroyed(self)
				if world.network != null and world.network.active():
					world.network.owners.erase(net_id)
				queue_free()
				return
		if wreck_timer>=0 and not exploded:
			wreck_timer=maxf(0,wreck_timer-delta)
			if wreck_timer<=0:
				explode()
		speed = 0
		velocity.x = move_toward(velocity.x,0,delta*12)
		velocity.z = move_toward(velocity.z,0,delta*12)
		velocity.y = -5 if is_on_floor() else velocity.y-delta*22
		move_and_slide()
		return
	hit_cooldown = maxf(0, hit_cooldown - delta)
	var steer := 0.0
	if driving and world.finished:
		speed = move_toward(speed, 0, delta * 2)
	elif driving and not world.finished:
		var throttle := (Input.get_action_strength("forward") - Input.get_action_strength("back")) if world.activities.menu=="" and not (world.network!=null and world.network.active() and world.network.rules.is_dead(multiplayer.get_unique_id())) else 0.0
		var top_speed: float = Catalog.SPEEDS[tier]*(1.0 if Input.is_action_pressed("sprint") else 0.76)+engine_upgrade
		if throttle != 0:
			speed = move_toward(speed, throttle * (top_speed if throttle > 0 else (5.0 if tier == 9 else 12.0)), delta * (22 if speed * throttle < 0 else Catalog.ACCEL[tier]))
		else:
			speed = move_toward(speed, 0, delta * 3.5)
		if Input.is_action_pressed("jump"):
			speed = move_toward(speed, 0, delta * 23)
		steer = Input.get_action_strength("left") - Input.get_action_strength("right")
	elif police and police_phase=="parked":
		speed=0
		velocity=Vector3(0,-4,0)
	elif police and police_phase in ["exit","return","dock"]:
		var aim := Vector3(position.x,0,42) if police_phase=="exit" else (Vector3(police_home.x,0,42) if police_phase=="return" else police_home)
		steer=ai_steer(aim)
		speed=move_toward(speed,7.0,delta*6)
		if position.distance_to(aim)<3:
			if police_phase=="exit":
				police_phase="pursuit"
			elif police_phase=="return":
				police_phase="dock"
			elif position.distance_to(police_home)<3:
				police_phase="parked"
				speed=0
	elif police and police_phase=="pursuit" and world.heat > 0 and not world.finished:
		var target: Vector3 = world.police_target(self)
		var aim := target
		# ponytail: street-grid steering; navigation meshes when the map stops being a grid.
		var near_x := roundf(position.x / 42.0) * 42.0
		var near_z := roundf(position.z / 42.0) * 42.0
		if absf(target.x - position.x) > 16 and absf(target.z - position.z) > 16:
			if absf(position.x - near_x) < absf(position.z - near_z):
				aim = Vector3(near_x, 0, roundf(target.z / 42.0) * 42.0)
			else:
				aim = Vector3(roundf(target.x / 42.0) * 42.0, 0, near_z)
		steer = ai_steer(aim)
		var chase_speed: float = 14.0 if world.heat <= 20 else 18.0 + world.heat * 0.07
		var distance := position.distance_to(target)
		if distance < 10:
			chase_speed = 0.0 if world.heat <= 20 else 4.0
		speed = move_toward(speed, chase_speed, delta * 6)
	elif traffic and not route.is_empty():
		if position.distance_to(route[route_index]) < 5:
			route_index = (route_index + 1) % route.size()
		steer = ai_steer(route[route_index])
		speed = move_toward(speed, 10.0, delta * 4)
	else:
		speed = move_toward(speed, 0, delta * 9)
	var turn := clampf(absf(speed) / 7.0, 0, 1) * (1 if speed >= 0 else -1)
	heading += steer * delta * (2.0 if tier == 9 else 1.65) * turn
	if tier == 9:
		get_node("CustomVehicle").rotation.z = lerpf(get_node("CustomVehicle").rotation.z,-steer*minf(absf(speed)/30,1)*0.2,delta*6)
	rotation.y = heading
	var forward := -global_transform.basis.z
	velocity.x = forward.x * speed
	velocity.z = forward.z * speed
	velocity.y = -5 if is_on_floor() else velocity.y - 22 * delta
	move_and_slide()
	if is_on_floor() and position.y<1.5:
		last_grounded=position
	if position.y>5 or position.y < -6:
		position=last_grounded if last_grounded!=Vector3.ZERO else (police_home if police else Vector3(0,0.3,0))
		velocity=Vector3.ZERO
		speed=0
	if police and police_phase=="pursuit" and world.heat > 0:
		stuck_time = stuck_time + delta if get_real_velocity().length() < 1.5 else 0.0
		if stuck_time > 2.5:
			heading += PI * 0.65
			speed = -8
			stuck_time = 0
	for i in get_slide_collision_count():
		var hit := get_slide_collision(i)
		var victim: Object = hit.get_collider()
		if victim is CharacterBody3D and world.life != null and (victim in world.life.people or victim in world.activities.officers or victim.has_meta("peer_id")) and absf(speed) > 3:
			if world.network!=null and world.network.active() and victim.has_meta("peer_id"):
				world.network.rules.send_action("ram",{"target":int(victim.get_meta("peer_id"))})
			else:
				victim.take_hit(absf(speed)*5.0)
			speed *= 0.85
			continue
		if absf(hit.get_normal().y) < 0.5 and absf(speed) > 6:
			if driving and hit_cooldown <= 0:
				world.damage(absf(speed) * 0.48)
				hit_cooldown = 1
				if hit.get_collider() is CharacterBody3D and absf(speed) > 12:
					world.raise_heat(3)
			speed *= -0.25
	# Use actual travel, so wheels do not keep spinning when blocked by a wall.
	var travel := Vector2(get_real_velocity().x,get_real_velocity().z).length() * delta
	wheel_angle = fposmod(wheel_angle + travel / (0.36 if tier >= 4 else 0.384 * 0.95) * signf(speed),TAU)
	steering_angle = move_toward(steering_angle,steer * 0.38,delta * 2)
	var detail_distance: float = world.settings.NEAR[world.settings.draw_distance] + 3 if world.settings != null else 30.0
	if world.camera != null and position.distance_squared_to(world.camera.position) < detail_distance * detail_distance:
		for hub in steering_hubs:
			hub.rotation.y = steering_angle
		for wheel in wheels:
			wheel.rotation.x = wheel_angle
	if police:
		siren_clock += delta
		for i in lights.size():
			lights[i].visible = police_phase in ["exit","pursuit"] and fmod(siren_clock + i * 0.2, 0.4) < 0.25
	if position.y < -8:
		position = Vector3(0, 1, 0)
		speed = 0

func ai_steer(target: Vector3) -> float:
	var offset := target - position
	var desired := atan2(-offset.x, -offset.z)
	return clampf(angle_difference(heading, desired) * 2.5, -1, 1)

func take_hit(amount: float) -> void:
	if world.network != null and world.network.is_client():
		world.network.request_hit.rpc_id(1,net_id,amount,true)
		return
	if hp <= 0:
		return
	hp = maxf(0, hp - amount)
	if hp <= 0:
		show_wreck()

func show_wreck() -> void:
	speed = 0
	traffic = false
	if not exploded:
		wreck_timer=5.0
		start_wreck_effects()
	for child in find_children("*", "MeshInstance3D", true, false):
		if child is MeshInstance3D:
			intact_materials[child] = child.material_override
			child.material_override = world.material(Color("353638"))
	world.notify("Veículo inutilizado.")

func start_wreck_effects() -> void:
	if is_instance_valid(fire_particles): return
	fire_particles=make_particles(Color(1.0,0.31,0.035),0.7,16,1.0)
	smoke_particles=make_particles(Color(0.16,0.17,0.18),0.55,10,1.8)

func make_particles(color: Color,radius: float,count: int,lifetime: float) -> GPUParticles3D:
	var p:=GPUParticles3D.new()
	p.amount=count
	p.lifetime=lifetime
	p.emitting=true
	var process_material:=ParticleProcessMaterial.new()
	process_material.direction=Vector3.UP
	process_material.spread=22
	process_material.initial_velocity_min=0.4
	process_material.initial_velocity_max=1.8
	process_material.gravity=Vector3(0,1,0)
	process_material.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process_material.emission_sphere_radius=radius
	p.process_material=process_material
	var mesh:=SphereMesh.new()
	mesh.radius=0.14
	mesh.height=0.28
	var mat:=StandardMaterial3D.new()
	mat.albedo_color=color
	mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED
	if color.r>0.5:
		mat.emission_enabled=true
		mat.emission=color
		mat.emission_energy_multiplier=1.8
	mesh.material=mat
	p.draw_pass_1=mesh
	p.position.y=0.6
	add_child(p)
	return p

func explode() -> void:
	if exploded: return
	exploded=true
	wreck_timer=0
	despawn_timer=3.0
	if is_instance_valid(fire_particles): fire_particles.emitting=false
	if is_instance_valid(smoke_particles): smoke_particles.emitting=false
	show_explosion_effect()
	if world.network!=null and world.network.active() and not multiplayer.is_server(): return
	var query:=PhysicsShapeQueryParameters3D.new()
	var shape:=SphereShape3D.new()
	shape.radius=10
	query.shape=shape
	query.transform=Transform3D(Basis.IDENTITY,global_position+Vector3(0,1,0))
	query.collision_mask=7
	query.exclude=[get_rid()]
	var struck:={}
	for result in get_world_3d().direct_space_state.intersect_shape(query,32):
		var victim:Node=result.collider
		if victim==self or not is_instance_valid(victim): continue
		var id:=int(victim.get_meta("peer_id",0)) if victim.has_meta("peer_id") else 0
		if id==0 and victim is CharacterBody3D and victim.get_script()==preload("res://scripts/car.gd") and world.network!=null and world.network.active():
			id=int(world.network.owners.get(victim.net_id,0))
		if id>0:
			if struck.has(id): continue
			struck[id]=true
			var distance := global_position.distance_to(victim.global_position)
			var damage := 200.0 if distance <= 5.0 else lerpf(200.0, 80.0, clampf((distance - 5.0) / 5.0, 0.0, 1.0))
			if world.network!=null and world.network.active(): world.network.rules.damage_peer(id,damage,0)
			elif victim==world.player or victim==world.active_car: world.damage(damage)
		elif victim.has_method("take_hit") and not struck.has(victim.get_instance_id()):
			struck[victim.get_instance_id()]=true
			victim.take_hit(200)
	if world.network!=null and world.network.active() and multiplayer.is_server():
		for id in world.network.members:
			if struck.has(id):
				continue
			var state: Dictionary=world.network.members[id]
			var key: String="car_position" if int(state.get("car",-1))>=0 else "position"
			var at: Vector3=state.get(key,Vector3.ZERO)
			var distance:=global_position.distance_to(at)
			if distance>10.0:
				continue
			var damage:=200.0 if distance<=5.0 else lerpf(200.0,80.0,(distance-5.0)/5.0)
			struck[id]=true
			world.network.rules.damage_peer(id,damage,0)
	if world.network==null or not world.network.active() or multiplayer.is_server():
		world.extra.play("explosion",-8)
		if world.network!=null and world.network.active():
			for peer_id in world.network.members:
				if peer_id!=1: world.network.personal.rpc_id(peer_id,"sound",{"name":"explosion"})

func repair() -> void:
	hp = MAX_HP
	wreck_timer=-1
	exploded=false
	despawn_timer=-1
	if is_instance_valid(fire_particles): fire_particles.queue_free()
	if is_instance_valid(smoke_particles): smoke_particles.queue_free()
	fire_particles=null
	smoke_particles=null
	for mesh in intact_materials:
		if is_instance_valid(mesh):
			mesh.material_override = intact_materials[mesh]
	intact_materials.clear()

func repaint(color: Color) -> void:
	paint = color
	rider = null
	for child in get_children():
		if child is CollisionShape3D:
			continue
		remove_child(child)
		child.queue_free()
	wheels.clear()
	steering_hubs.clear()
	lights.clear()
	intact_materials.clear()
	world.visuals.build_car(self)
	world.settings.register_visuals(self)

func apply_network_health(value: float) -> void:
	if value<=0 and hp>0:
		show_wreck()
	elif value>0 and hp<=0:
		repair()
	hp=value

func apply_network_damage(timer: float,has_exploded: bool) -> void:
	if hp<=0 and not has_exploded and not is_instance_valid(fire_particles):
		start_wreck_effects()
	if has_exploded:
		if not exploded:
			show_explosion_effect()
		exploded=true
		wreck_timer=0
		despawn_timer=maxf(despawn_timer,3.0)
		if is_instance_valid(fire_particles): fire_particles.emitting=false
		if is_instance_valid(smoke_particles): smoke_particles.emitting=false
	else:
		wreck_timer=timer

func show_explosion_effect() -> void:
	var flash := OmniLight3D.new()
	flash.light_color=Color(1.0,0.3,0.05)
	flash.light_energy=8.0
	flash.omni_range=16.0
	world.add_child(flash)
	flash.global_position=global_position+Vector3.UP
	var tween:=world.create_tween()
	tween.tween_property(flash,"light_energy",0.0,0.55)
	tween.tween_callback(flash.queue_free)
	var burst:=GPUParticles3D.new()
	burst.one_shot=true
	burst.amount=42
	burst.lifetime=0.8
	burst.explosiveness=1.0
	var process_material:=ParticleProcessMaterial.new()
	process_material.direction=Vector3.UP
	process_material.spread=180.0
	process_material.initial_velocity_min=7.0
	process_material.initial_velocity_max=19.0
	process_material.gravity=Vector3(0,-9.0,0)
	process_material.scale_min=0.35
	process_material.scale_max=1.8
	process_material.color=Color(1.0,0.32,0.04,0.95)
	burst.process_material=process_material
	var particle_mesh:=SphereMesh.new()
	particle_mesh.radius=0.12
	particle_mesh.height=0.24
	var particle_material:=StandardMaterial3D.new()
	particle_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	particle_material.albedo_color=Color(1.0,0.37,0.04)
	particle_material.emission_enabled=true
	particle_material.emission=Color(1.0,0.16,0.01)
	particle_material.emission_energy_multiplier=3.0
	particle_mesh.material=particle_material
	burst.draw_pass_1=particle_mesh
	world.add_child(burst)
	burst.global_position=global_position+Vector3.UP
	burst.finished.connect(burst.queue_free)
	burst.emitting=true
	var ring:=MeshInstance3D.new()
	var ring_mesh:=TorusMesh.new()
	ring_mesh.inner_radius=0.45
	ring_mesh.outer_radius=0.7
	ring.mesh=ring_mesh
	ring.rotation.x=PI/2
	var ring_material:=StandardMaterial3D.new()
	ring_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.albedo_color=Color(1.0,0.45,0.12,0.8)
	ring_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override=ring_material
	world.add_child(ring)
	ring.global_position=global_position+Vector3.UP*0.12
	var ring_tween:=world.create_tween().set_parallel(true)
	ring_tween.tween_property(ring,"scale",Vector3(14,0.18,14),0.65)
	ring_tween.tween_property(ring_material,"albedo_color:a",0.0,0.65)
	ring_tween.chain().tween_callback(ring.queue_free)
