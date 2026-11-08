extends CharacterBody3D
var world: Node3D
var peer_id := 0
var model: Node3D
var roll_time := 0.0
var gun: MeshInstance3D
var is_crouching := false

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
	var skeleton: Skeleton3D=model.find_children("*","Skeleton3D",true,false)[0]
	var hand := BoneAttachment3D.new()
	hand.bone_name="Skeleton_arm_joint_R__3_"
	skeleton.add_child(hand)
	gun=world.box(hand,Vector3.ZERO,Vector3(0.07,0.09,0.24),Color("25313a"))
	world.box(gun,Vector3(0,-0.1,0.06),Vector3(0.06,0.16,0.08),Color("25313a"))

func animate(speed: float) -> void:
	model.animate(speed)

func apply_outfit(value: int) -> void:
	model.apply_outfit(value)

func take_hit(amount: float) -> void:
	if world.network.is_client():
		world.network.rules.send_action("ram",{"target":peer_id})
	else:
		world.network.rules.damage_peer(peer_id,amount,world.network.rules.attacker)

func set_weapon(selected: int) -> void:
	gun.visible=selected>0
	gun.scale=Vector3(1,1,[1.0,1.0,1.8,1.35,1.6,3.5,3.0,4.0][clampi(selected,0,7)])

func set_crouched(value: bool) -> void:
	if is_crouching==value:
		return
	is_crouching=value
	var collider: CollisionShape3D=get_child(0)
	var capsule: CapsuleShape3D=collider.shape
	capsule.height=1.15 if value else 1.8
	collider.position.y=0.58 if value else 0.9
	model.scale.y=0.66 if value else 1.0
	model.position.y=-0.28 if value else 0.0
