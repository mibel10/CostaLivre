extends Node

const QUALITIES := ["Ultra", "Alto", "Médio", "Baixo", "Batata"]
const FPS_LIMITS := [30, 60, 120, 144, 180, 240, 360, 0]
const NEAR := [85.0, 65.0, 45.0, 18.0, 12.0]
const FAR := [350.0, 280.0, 220.0, 170.0, 125.0]
var world: Node3D
var quality := 3
var customized := false
var fps_limit := 30
var fps_corner := 1
var config_path := "user://settings.cfg"
var texture_quality := 3
var shadow_quality := 0
var antialiasing := 0
var draw_distance := 3
var detail_maps := false
var toggle_crouch := false
var toggle_sprint := false
var texture_sources := {}
var texture_cache := {}
var tracked := {}
var shading := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	register_visuals(world)
	apply()

func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(config_path) != OK:
		return
	toggle_crouch=bool(config.get_value("controls","toggle_crouch",false))
	toggle_sprint=bool(config.get_value("controls","toggle_sprint",false))
	var value = config.get_value("video", "quality", 3)
	quality = clampi(value, 0, 4) if typeof(value) == TYPE_INT else 3
	customized=config.get_value("video","custom",false)
	value = config.get_value("video", "fps_limit", 30)
	fps_limit = value if typeof(value) == TYPE_INT and value in FPS_LIMITS else 30
	value = config.get_value("video","fps_corner",1)
	fps_corner = value if typeof(value) == TYPE_INT and value >= -1 and value <= 3 else 1
	texture_quality=clampi(config.get_value("video","textures",mini(quality,3)),0,3)
	shadow_quality=clampi(config.get_value("video","shadows",[3,2,1,0,0][quality]),0,3)
	antialiasing=clampi(config.get_value("video","aa",[3,2,0,0,0][quality]),0,3)
	draw_distance=clampi(config.get_value("video","distance",quality),0,4)
	detail_maps=config.get_value("video","details",quality<3)

func save_settings() -> void:
	var config := ConfigFile.new()
	config.load(config_path)
	config.set_value("video", "quality", quality)
	config.set_value("video","custom",customized)
	config.set_value("video","textures",texture_quality)
	config.set_value("video","shadows",shadow_quality)
	config.set_value("video","aa",antialiasing)
	config.set_value("video","distance",draw_distance)
	config.set_value("video","details",detail_maps)
	config.set_value("controls","toggle_crouch",toggle_crouch)
	config.set_value("controls","toggle_sprint",toggle_sprint)
	config.set_value("video", "fps_limit", fps_limit)
	config.set_value("video","fps_corner",fps_corner)
	if config.save(config_path) != OK:
		world.notify("Não foi possível salvar as configurações.")

func save_binding(action: String, keycode: int) -> void:
	var config := ConfigFile.new()
	config.load(config_path)
	config.set_value("controls", action, keycode)
	if config.save(config_path) != OK:
		world.notify("NÃ£o foi possÃ­vel salvar a tecla.")

func set_quality(index: int, persist := true) -> void:
	if index < 0 or index >= QUALITIES.size():
		return
	quality = index
	customized=false
	texture_quality=mini(index,3)
	shadow_quality=[3,2,1,0,0][index]
	antialiasing=[3,2,0,0,0][index]
	draw_distance=index
	detail_maps=index<3
	apply()
	if persist:
		save_settings()

func set_fps_limit(value: int, persist := true) -> void:
	if value not in FPS_LIMITS:
		return
	fps_limit = value
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = value
	if persist:
		save_settings()

func set_fps_corner(value: int, persist := true) -> void:
	if value < -1 or value > 3:
		return
	fps_corner = value
	if world.fps_counter != null:
		world.fps_counter.refresh()
	if persist:
		save_settings()

func register_material(mat: Material) -> void:
	if mat is StandardMaterial3D and not tracked.has(mat):
		tracked[mat] = mat.normal_enabled
		shading[mat] = mat.shading_mode
		texture_sources[mat] = mat.albedo_texture
		apply_texture(mat)
		mat.normal_enabled = tracked[mat] and detail_maps
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if quality == 4 else shading[mat]

func register_visuals(node: Node) -> void:
	if node is GeometryInstance3D:
		register_material(node.material_override)
		if node is MeshInstance3D and node.mesh != null:
			for i in node.mesh.get_surface_count():
				register_material(node.mesh.surface_get_material(i))
				register_material(node.get_surface_override_material(i))
		if node is MultiMeshInstance3D and node.multimesh != null:
			for i in node.multimesh.mesh.get_surface_count():
				register_material(node.multimesh.mesh.surface_get_material(i))
		apply_range(node)
	for child in node.get_children():
		register_visuals(child)

func apply_range(node: GeometryInstance3D) -> void:
	if node.is_in_group("car_simple"):
		node.visibility_range_end = FAR[draw_distance]
	elif node.is_in_group("car_detail"):
		node.visibility_range_end = NEAR[draw_distance]
	elif node.is_in_group("car_far"):
		node.visibility_range_begin = NEAR[draw_distance]
		node.visibility_range_end = FAR[draw_distance]
	elif node.is_in_group("car_shadow"):
		node.visibility_range_end = 55.0 if quality < 3 else 0.1
	elif node is Label3D:
		node.visibility_range_end = 110.0 if quality < 3 else 65.0

func apply() -> void:
	set_fps_limit(fps_limit, false)
	world.camera.far = FAR[draw_distance]
	world.get_viewport().msaa_3d = Viewport.MSAA_4X if antialiasing == 3 else (Viewport.MSAA_2X if antialiasing == 2 else Viewport.MSAA_DISABLED)
	world.get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if antialiasing == 1 else Viewport.SCREEN_SPACE_AA_DISABLED
	# Native resolution avoids an extra upscale pass on this older Compatibility GPU.
	world.get_viewport().scaling_3d_scale = 1.0
	for mat in tracked:
		apply_texture(mat)
		mat.normal_enabled = tracked[mat] and detail_maps
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if quality == 4 else shading[mat]
	for group in ["car_detail", "car_far", "car_shadow", "car_simple"]:
		for node in get_tree().get_nodes_in_group(group):
			apply_range(node)
	for child in world.get_children():
		if child is DirectionalLight3D:
			child.shadow_enabled = shadow_quality > 0
			child.directional_shadow_max_distance = [0.0,35.0,70.0,110.0][shadow_quality]
			child.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		if child is WorldEnvironment:
			child.environment.fog_enabled = quality < 3
			child.environment.fog_density = 0.0015 if quality < 2 else 0.003
	for light in world.find_children("*", "OmniLight3D", true, false):
		light.visible = quality < 4
	for label in world.find_children("*", "Label3D", true, false):
		apply_range(label)

func set_custom(key: String, value: int) -> void:
	customized=true
	match key:
		"textures": texture_quality=clampi(value,0,3)
		"shadows": shadow_quality=clampi(value,0,3)
		"aa": antialiasing=clampi(value,0,3)
		"distance": draw_distance=clampi(value,0,4)
		"details": detail_maps=value==1
	apply()
	save_settings()

func apply_texture(mat: StandardMaterial3D) -> void:
	var source: Texture2D = texture_sources.get(mat)
	if source == null:
		return
	if texture_quality == 0:
		mat.albedo_texture=source
		return
	var key := str(source.get_instance_id())+":"+str(texture_quality)
	if not texture_cache.has(key):
		var image := source.get_image()
		if image == null:
			return
		if image.is_compressed() and image.decompress()!=OK:
			return
		var limit: int = [0,1024,512,256][texture_quality]
		var ratio := minf(1.0,float(limit)/maxi(image.get_width(),image.get_height()))
		if ratio<1:
			image.resize(maxi(1,int(image.get_width()*ratio)),maxi(1,int(image.get_height()*ratio)),Image.INTERPOLATE_BILINEAR)
		image.generate_mipmaps()
		texture_cache[key]=ImageTexture.create_from_image(image)
	mat.albedo_texture=texture_cache[key]
