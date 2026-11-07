extends Node

const OUTFITS := ["Regata branca / jeans azul","Camiseta vermelha / calca escura","Camiseta azul / calca verde","Camiseta verde / calca marrom","Camiseta mostarda / calca azul","Camiseta roxa / calca cinza"]
var world: Node3D
var player_name := "Jogador"
var outfit := 0
var config_path := "user://profile.cfg"
var nametag: Label3D

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	var config := ConfigFile.new()
	if config.load(config_path)==OK:
		player_name=clean_name(str(config.get_value("player","name","Jogador")))
		outfit=clampi(int(config.get_value("player","outfit",0)),0,5)
	world.player.model.apply_outfit(outfit)
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

func save_profile(value: String, selected: int) -> bool:
	var name_value := clean_name(value)
	selected=clampi(selected,0,5)
	var config := ConfigFile.new()
	config.set_value("player","name",name_value)
	config.set_value("player","outfit",selected)
	if config.save(config_path)!=OK:
		return false
	player_name=name_value
	outfit=selected
	world.player.model.apply_outfit(outfit)
	nametag.text=player_name
	return true

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
