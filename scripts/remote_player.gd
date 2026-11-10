extends CharacterBody3D
var world: Node3D
var peer_id := 0
var model: Node3D
var roll_time := 0.0
var gun: MeshInstance3D
var is_crouching := false
var weapon_reload_remaining := 0.0
var weapon_reload_duration := 0.0

func _ready() -> void:
	collision_layer=2
	collision_mask=0
	set_meta("peer_id",peer_id)
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius=0.32
	capsule.height=1.8
	collider.shape=capsule
	collider.position.y=0.9
	add_child(collider)
	model=preload("res://scripts/human_visual.gd").new()
	model.cj_style=true
	add_child(model)
	gun = model.build_weapon(world)

func animate(speed: float) -> void:
	model.animate(speed)

func apply_outfit(value: int) -> void:
	model.apply_outfit(value)

func take_hit(amount: float) -> void:
	if world.network.is_client():
		world.network.rules.send_action("ram",{"target":peer_id})
	else:
		world.network.rules.damage_peer(peer_id,amount,world.network.rules.attacker)

func set_weapon(selected: int, inventory: Dictionary) -> void:
	model.show_weapon(selected)
	weapon_reload_duration = world.activities.RELOAD_DURATIONS[selected]
	weapon_reload_remaining = float(inventory.get("reload_time", 0.0)) if int(inventory.get("reload_weapon", 0)) == selected else 0.0

func _process(delta: float) -> void:
	weapon_reload_remaining = maxf(0.0, weapon_reload_remaining - delta)
	if visible:
		model.update_weapon_pose(delta, weapon_reload_remaining / weapon_reload_duration if weapon_reload_duration > 0.0 else 0.0)

func set_crouched(value: bool) -> void:
	if is_crouching==value:
		return
	is_crouching=value
	var collider: CollisionShape3D=get_child(0)
	var capsule: CapsuleShape3D=collider.shape
	capsule.height=1.15 if value else 1.8
	collider.position.y=0.58 if value else 0.9
	model.show_crouch(value)
