extends CharacterBody3D

const ROLL_DURATION := 0.85
const ROLL_SPEED := 16.0

var world: Node3D
var model: Node3D
var gun: MeshInstance3D
var roll_time := 0.0
var roll_cooldown := 0.0
var roll_direction := Vector3.FORWARD
var is_crouching := false
var crouch_latched := false
var sprint_latched := false
var body_collider: CollisionShape3D
var aim_weapon := false
var weapon_pitch := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	collision_layer = 2
	collision_mask = 5
	var shape := CollisionShape3D.new()
	body_collider=shape
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)
	model = preload("res://scripts/human_visual.gd").new()
	model.cj_style = true
	add_child(model)
	gun = model.build_weapon(world)

func _physics_process(delta: float) -> void:
	aim_weapon = false
	if world.life != null:
		var id := multiplayer.get_unique_id() if world.network != null and world.network.active() else 1
		if world.life.elevator_rider_position(id) != null or world.vehicle_falls.has(id):
			velocity = Vector3.ZERO
			model.set_weapon_aim(false, 0.0, delta)
			return
	if world.network!=null and world.network.active() and world.network.rules.is_dead(multiplayer.get_unique_id()):
		velocity=Vector3.ZERO
		model.set_weapon_aim(false, 0.0, delta)
		return
	if world.active_car != null or world.car_transition or world.finished or world.activities == null or world.activities.menu != "" or world.activities.bank.local_hacking() or (world.network!=null and world.network.active() and world.network.rules.local_mission_hacking()):
		model.set_weapon_aim(false, 0.0, delta)
		return
	roll_cooldown = maxf(0,roll_cooldown-delta)
	if Input.is_physical_key_pressed(KEY_CTRL):
		start_roll()
	if world.settings.toggle_crouch and Input.is_action_just_pressed("crouch"):
		crouch_latched = not crouch_latched
	if world.settings.toggle_sprint and Input.is_action_just_pressed("sprint"):
		sprint_latched = not sprint_latched
	if not world.settings.toggle_crouch:
		crouch_latched = false
	if not world.settings.toggle_sprint:
		sprint_latched = false
	set_crouched(crouch_latched if world.settings.toggle_crouch else Input.is_action_pressed("crouch"))
	if roll_time > 0:
		model.set_weapon_aim(false, 0.0, delta)
		roll_time = maxf(0,roll_time-delta)
		velocity = roll_direction.normalized()*ROLL_SPEED + Vector3(0,-4,0)
		move_and_slide()
		model.rotation.x = (1-roll_time/ROLL_DURATION)*TAU
		var pivot := Vector3(0,0.92,0)
		model.position = pivot - Basis.from_euler(model.rotation) * pivot
		if roll_time <= 0:
			model.rotation.x = 0
			model.position = Vector3.ZERO
		return
	var selected: int = world.activities.weapon
	model.show_weapon(selected)
	var remaining: float = world.activities.reload_time if world.activities.reload_weapon == selected else 0.0
	var duration: float = world.activities.RELOAD_DURATIONS[selected]
	model.update_weapon_pose(delta, remaining / duration if duration > 0.0 else 0.0)
	var input := Input.get_vector("left", "right", "forward", "back")
	var direction := Vector3(input.x, 0, input.y).rotated(Vector3.UP, world.camera_yaw)
	var sprinting: bool = sprint_latched if world.settings.toggle_sprint else Input.is_action_pressed("sprint")
	var speed := (1.8 if is_crouching else (9.0 if sprinting else 5.0))
	if float(world.network.rules.stand_sheet(multiplayer.get_unique_id()).get("stand_slow",0.0)) > 0.0:
		speed *= 0.22
	velocity.x = move_toward(velocity.x, direction.x * speed, delta * 30)
	velocity.z = move_toward(velocity.z, direction.z * speed, delta * 30)
	if not is_on_floor():
		velocity.y -= 24 * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = 8
	move_and_slide()
	if direction.length() > 0.1:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(-direction.x, -direction.z), delta * 12)
	model.animate(Vector2(velocity.x, velocity.z).length())
	var aim_input := Input.is_action_pressed("aim") or Input.is_action_pressed("shoot")
	aim_weapon = selected > 0 and aim_input
	var pointing: bool = aim_weapon or model.weapon_aim_hold > 0.0
	var camera_forward: Vector3 = -world.camera.global_basis.z
	weapon_pitch = clampf(asin(clampf(camera_forward.y, -1.0, 1.0)), -1.35, 1.35)
	if pointing:
		model.rotation.y = atan2(-camera_forward.x, -camera_forward.z)
	elif aim_input:
		model.rotation.y = world.camera_yaw
	model.set_weapon_aim(pointing, weapon_pitch, delta)
	if position.y < -10:
		position = Vector3(-5, 2, 12)

func start_roll() -> bool:
	if float(world.network.rules.stand_sheet(multiplayer.get_unique_id()).get("stand_slow",0.0)) > 0.0:
		return false
	if roll_cooldown > 0 or not is_on_floor() or world.active_car != null or world.car_transition or world.finished:
		return false
	roll_time = ROLL_DURATION
	roll_cooldown = 1.1
	var direction := Input.get_vector("left","right","forward","back")
	roll_direction = Vector3(direction.x,0,direction.y).rotated(Vector3.UP,world.camera_yaw)
	if roll_direction.length() < 0.1:
		roll_direction = Vector3.FORWARD.rotated(Vector3.UP,world.camera_yaw)
	return true

func set_crouched(value: bool) -> void:
	if is_crouching==value:
		return
	is_crouching=value
	var capsule: CapsuleShape3D=body_collider.shape
	capsule.height=1.15 if value else 1.8
	body_collider.position.y=0.58 if value else 0.9
	model.show_crouch(value)

func take_hit(amount: float) -> void:
	if world.network!=null and world.network.active():
		world.network.rules.damage_peer(multiplayer.get_unique_id(),amount,world.network.rules.attacker)
	else:
		world.damage(amount)
