extends CharacterBody3D

var world: Node3D
var route: Array[Vector3] = []
var point := 0
var hp := 60.0
var model: Node3D
var tint := Color.WHITE
var stationary := false
var shopper := false
var shopping_pause := 0.0
var robbed := false
var scared := false
var appearance_index := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	collision_layer = 4
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = 1.8
	capsule.radius = 0.3
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)
	model = preload("res://scripts/human_visual.gd").new()
	model.outfit_index = appearance_index
	add_child(model)

func _physics_process(delta: float) -> void:
	if hp <= 0 or stationary or route.is_empty() or world.finished:
		return
	if world.network != null and world.network.is_client():
		return
	if shopper and shopping_pause > 0 and world.heat < 20:
		shopping_pause -= delta
		model.animate(0)
		return
	var direction := route[point] - position
	direction.y = 0
	if direction.length() < 0.8:
		if shopper:
			shopping_pause = 2.5 if point in [1,3,5] else 0.0
			if point in [1,5]: model.rotation.y = PI/2
		point = (point + 1) % route.size()
		return
	var speed := 0.4 if scared else (3.8 if world.heat > 20 and position.distance_to(world.subject_position()) < 25 else 1.6)
	velocity = direction.normalized() * speed + Vector3(0, -4, 0)
	move_and_slide()
	model.rotation.y = lerp_angle(model.rotation.y, atan2(-direction.x, -direction.z), delta * 6)
	model.animate(speed)

func take_hit(amount: float, actor := 0) -> void:
	if world.network != null and world.network.is_client():
		if actor >= 0:
			world.network.request_hit.rpc_id(1,world.life.people.find(self),amount,false)
		return
	if hp <= 0:
		return
	hp = maxf(0, hp - amount)
	world.raise_heat(20, actor)
	if hp <= 0:
		model.rotation.z = PI / 2
		model.animate(0)
		collision_layer = 0
