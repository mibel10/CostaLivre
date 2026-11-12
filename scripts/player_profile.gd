extends Node

const OUTFITS := ["Regata branca / jeans azul","Camiseta vermelha / calca escura","Camiseta azul / calca verde","Camiseta verde / calca marrom","Camiseta mostarda / calca azul","Camiseta roxa / calca cinza"]
const ACCESSORIES := ["Sem acessório", "Boné", "Bandana", "Óculos escuros"]
var world: Node3D
var player_name := "Jogador"
var outfit := 0
var accessory := 0
var style_credits := 2000
var owned_outfits := [0]
var owned_accessories := [0]
var tutorial_seen := false
var config_path := "user://profile.cfg"
var nametag: Label3D

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	var config := ConfigFile.new()
	if config.load(config_path)==OK:
		player_name=clean_name(str(config.get_value("player","name","Jogador")))
		outfit=clampi(int(config.get_value("player","outfit",0)),0,5)
		accessory=clampi(int(config.get_value("player","accessory",0)),0,ACCESSORIES.size()-1)
		style_credits=maxi(0,int(config.get_value("player","style_credits",style_credits)))
		owned_outfits=config.get_value("player","owned_outfits",[0])
		owned_accessories=config.get_value("player","owned_accessories",[0])
		tutorial_seen=bool(config.get_value("player","tutorial_seen",false))
	if not outfit in owned_outfits: owned_outfits.append(outfit)
	if not accessory in owned_accessories: owned_accessories.append(accessory)
	world.player.model.apply_outfit(outfit*8+accessory)
	nametag=create_nametag(world,player_name)

static func clean_name(value: String) -> String:
	var result := ""
	for symbol in value:
		var point := symbol.unicode_at(0)
		if point>=32 and point!=127 and not (point>=0x200b and point<=0x200f) and not (point>=0x202a and point<=0x202e) and not (point>=0x2066 and point<=0x2069):
			result+=symbol
		if result.length()>=20:
			break
	result=result.strip_edges()
	return "Jogador" if result.is_empty() else result

func save_profile(value: String, selected: int, selected_accessory := 0) -> bool:
	var name_value := clean_name(value)
	selected=clampi(selected,0,5)
	selected_accessory=clampi(selected_accessory,0,ACCESSORIES.size()-1)
	var cost := (0 if selected in owned_outfits else 300) + (0 if selected_accessory in owned_accessories else 150)
	if style_credits < cost:
		return false
	var new_credits := style_credits - cost
	var new_outfits: Array = owned_outfits.duplicate()
	var new_accessories: Array = owned_accessories.duplicate()
	if not selected in new_outfits: new_outfits.append(selected)
	if not selected_accessory in new_accessories: new_accessories.append(selected_accessory)
	var config := ConfigFile.new()
	config.set_value("player","name",name_value)
	config.set_value("player","outfit",selected)
	config.set_value("player","accessory",selected_accessory)
	config.set_value("player","style_credits",new_credits)
	config.set_value("player","owned_outfits",new_outfits)
	config.set_value("player","owned_accessories",new_accessories)
	config.set_value("player","tutorial_seen",tutorial_seen)
	if config.save(config_path)!=OK:
		return false
	style_credits=new_credits
	owned_outfits.assign(new_outfits)
	owned_accessories.assign(new_accessories)
	player_name=name_value
	outfit=selected
	accessory=selected_accessory
	world.player.model.apply_outfit(outfit*8+accessory)
	nametag.text=player_name
	return true

func mark_tutorial_seen() -> void:
	tutorial_seen = true
	var config := ConfigFile.new()
	config.load(config_path)
	config.set_value("player","tutorial_seen",true)
	config.save(config_path)

func appearance_code() -> int:
	return outfit*8+accessory

func quick_change() -> bool:
	var styles: Array[Vector2i] = []
	for clothing in owned_outfits:
		for item in owned_accessories:
			styles.append(Vector2i(int(clothing),int(item)))
	if styles.size() < 2:
		return false
	var current := styles.find(Vector2i(outfit,accessory))
	var next: Vector2i = styles[(current+1)%styles.size()]
	return save_profile(player_name,next.x,next.y)

static func create_nametag(parent: Node, value: String) -> Label3D:
	var label := Label3D.new()
	label.text=clean_name(value)
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size=28
	label.outline_size=7
	label.pixel_size=0.008
	label.modulate=Color("e7f9ed")
	label.outline_modulate=Color("13232c")
	label.no_depth_test=false
	label.visibility_range_end=60
	parent.add_child(label)
	return label

func _process(_delta: float) -> void:
	if nametag==null:
		return
	var show_tag: bool=world.network!=null and world.network.active() and not world.finished and not Input.is_action_pressed("aim")
	nametag.visible=show_tag
	if show_tag:
		nametag.position=world.subject_position()+Vector3(0,2.5 if world.active_car==null else 3.0,0)
