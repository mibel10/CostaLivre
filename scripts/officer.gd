extends CharacterBody3D

var world: Node3D
var hp := 80.0
var fire_time := 1.0
var model: Node3D
var mission_stair := false
var mission_stair_route: Array[Vector3]=[]
var mission_stair_index := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	collision_layer = 4
	collision_mask = 7
	platform_floor_layers=1
	platform_wall_layers=0
	var collider := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.33
	shape.height = 1.8
	collider.shape = shape
	collider.position.y = 0.9
	add_child(collider)
	model = preload("res://scripts/human_visual.gd").new()
	model.police = true
	add_child(model)
	model.build_weapon(world)
	model.show_weapon(1)

func _physics_process(delta: float) -> void:
	if world.network!=null and world.network.is_client():
		return
	if hp <= 0 or world.finished:
		return
	var contract: bool = has_meta("mission_contract")
	if contract and int(get_meta("mission_contract")) != world.activities.job: return
	if bool(get_meta("mission_sentinel",false)) and world.activities.stage in [0,1] and world.heat <= 0:
		model.animate(0)
		return
	var player_target: Vector3=world.police_target(self)
	if not player_target.is_finite():
		model.animate(0)
		return
	if contract and position.distance_to(player_target) > 60:
		model.animate(0)
		return
	var target: Vector3=player_target
	if mission_stair and mission_stair_index<mission_stair_route.size():
		if position.distance_to(mission_stair_route[mission_stair_index])<0.85:
			mission_stair_index+=1
		if mission_stair_index<mission_stair_route.size():
			target=mission_stair_route[mission_stair_index]
	var offset: Vector3=target-position
	var direction := offset.normalized()
	var climbing:=mission_stair and mission_stair_index<mission_stair_route.size()
	var prison_guard: bool = bool(get_meta("prison_guard", false))
	var infiltration_tactical: bool = bool(get_meta("mission_heavy", false)) and int(get_meta("mission_contract", -1)) == world.activities.SECRET_DATA_JOB
	var moving: bool = climbing or ((world.heat > 0 or contract or prison_guard) and offset.length() > (7.0 if prison_guard else 10.0))
	if climbing:
		velocity=direction*3.2
	elif prison_guard:
		velocity.x = direction.x * 2.8 if moving else 0.0
		velocity.z = direction.z * 2.8 if moving else 0.0
		velocity.y = -4 if is_on_floor() else velocity.y - delta * 22
	else:
		velocity.x = direction.x * 4 if moving else 0.0
		velocity.z = direction.z * 4 if moving else 0.0
		velocity.y = -4 if is_on_floor() else velocity.y - delta * 22
	if Time.get_ticks_msec() < int(get_meta("stand_slow_until",0)):
		velocity.x *= 0.35
		velocity.z *= 0.35
	move_and_slide()
	model.animate(Vector2(velocity.x, velocity.z).length())
	if world.heat > 0 or contract or prison_guard:
		model.rotation.y = atan2(-offset.x, -offset.z)
	fire_time -= delta
	var response_threshold:=12 if world.network!=null and world.network.active() else 20
	if (world.heat < response_threshold and not mission_stair and not contract and not prison_guard) or position.distance_to(player_target)>32 or fire_time > 0:
		return
	fire_time = 3.2 if prison_guard or infiltration_tactical else 1.8
	var from := position + Vector3(0, 1.4, 0)
	var to: Vector3 = player_target + Vector3(0, 1, 0)
	var query := PhysicsRayQueryParameters3D.create(from, to, 7)
	query.exclude = [get_rid()]
	query.hit_from_inside = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var victim: Node3D = hit.collider
	var online: bool = world.network != null and world.network.active()
	var damage := 5 if prison_guard else (8 if infiltration_tactical else (18 if bool(get_meta("mission_heavy", false)) else 9))
	if contract and int(get_meta("mission_vehicle", -1)) >= 0 and victim == world.car_by_id(int(get_meta("mission_vehicle"))):
		victim.take_hit(12)
	elif online:
		var target_peer := int(victim.get_meta("peer_id", 0))
		if target_peer == 0 and victim.get_script() == preload("res://scripts/car.gd"):
			target_peer = int(world.network.owners.get(victim.net_id, 0))
		if target_peer <= 0 or (not contract and not mission_stair and not prison_guard and world.network.rules.wanted_heat(target_peer) <= 0.0):
			return
		world.network.rules.damage_peer(target_peer, damage, 0, true)
	elif victim == world.player or victim == world.active_car:
		world.damage(4.5 if damage == 9 and world.active_car != null else damage, true)
	else:
		return
	if online:
		world.network.shot_effect.rpc(from, hit.position, 1, 0, (hit.position-from).normalized())
	else:
		world.activities.trace(from, hit.position, Color("ff8264"))

func take_hit(amount: float, actor := 0) -> void:
	if world.network!=null and world.network.is_client():
		if actor >= 0:
			world.network.rules.send_action("ram_officer",{"index":world.activities.officers.find(self)})
		return
	if hp <= 0:
		return
	if actor >= 0 and bool(get_meta("mission_sentinel",false)) and world.activities.job == 29 and world.activities.stage in [0,1]:
		world.activities.trigger_infiltration_alarm()
	hp = maxf(0, hp - amount)
	world.raise_heat(8, actor)
	if hp <= 0:
		if world.network != null:
			world.network.rules.officer_killed(position)
		model.rotation.z = PI / 2
		collision_layer = 0

func is_behind(at: Vector3) -> bool:
	return Vector3.FORWARD.rotated(Vector3.UP,rotation.y).dot((at-position).normalized()) < -0.35

func silent_takedown() -> void:
	if hp <= 0 or not bool(get_meta("mission_sentinel",false)):
		return
	hp = 0
	if world.network != null:
		world.network.rules.officer_killed(position)
	model.rotation.z = PI/2
	collision_layer = 0
	world.activities.mission_sentinel_killed()
