extends Node

const QUALITIES := ["Ultra", "Alto", "Médio", "Baixo", "Batata", "EXTREMO"]
const FPS_LIMITS := [30, 60, 120, 144, 180, 240, 360, 0]
const UPSCALING_MODES := ["Desativado", "Qualidade", "Balanceado", "Performance", "Ultra performance"]
const UPSCALING_SCALES := [1.0, 0.9, 0.8, 0.7, 0.5]
const WINDOW_MODES := [DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN, DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_WINDOWED]
const WINDOW_RESOLUTIONS := [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const NEAR := [60.0, 46.0, 34.0, 22.0, 14.0, 80.0]
const FAR := [420.0, 350.0, 280.0, 220.0, 165.0, 1450.0]
const LOD_BIAS := [1.8, 1.35, 1.0, 0.8, 0.65, 2.35]
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
var upscaling := 2
var window_mode := 2
var window_resolution := Vector2i(1280, 720)
var toggle_crouch := false
var toggle_sprint := false
var camera_sensitivity := 1.0
var texture_cache := {}
var tracked := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	apply_display_settings()
	register_visuals(world)
	apply()

func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(config_path) != OK:
		return
	toggle_crouch=bool(config.get_value("controls","toggle_crouch",false))
	toggle_sprint=bool(config.get_value("controls","toggle_sprint",false))
	var sensitivity = config.get_value("controls", "camera_sensitivity", 1.0)
	if (sensitivity is float or sensitivity is int) and is_finite(float(sensitivity)):
		camera_sensitivity = clampf(sensitivity, 0.5, 2.0)
	var value = config.get_value("video", "quality", 3)
	quality = clampi(value, 0, 5) if typeof(value) == TYPE_INT else 3
	customized=config.get_value("video","custom",false) == true
	value = config.get_value("video", "fps_limit", 30)
	fps_limit = value if typeof(value) == TYPE_INT and value in FPS_LIMITS else 30
	value = config.get_value("video","fps_corner",1)
	fps_corner = value if typeof(value) == TYPE_INT and value >= -1 and value <= 3 else 1
	apply_preset_values()
	if customized:
		texture_quality = video_int(config, "textures", texture_quality, 0, 3)
		shadow_quality = video_int(config, "shadows", shadow_quality, 0, 3)
		antialiasing = video_int(config, "aa", antialiasing, 0, 3)
		if antialiasing == 1:
			antialiasing = 0 # Legacy FXAA setting; Compatibility cannot apply it.
		draw_distance = video_int(config, "distance", draw_distance, 0, 5)
		detail_maps = config.get_value("video", "details", detail_maps) == true
	upscaling = video_int(config, "upscaling", 2, 0, 4)
	window_mode = video_int(config, "window_mode", 2, 0, 2)
	window_resolution = Vector2i(video_int(config, "window_width", 1280, 1, 7680), video_int(config, "window_height", 720, 1, 4320))
	if not OS.has_feature("android"):
		var screen_size := DisplayServer.screen_get_size()
		if screen_size.x > 0 and screen_size.y > 0 and (window_resolution.x > screen_size.x or window_resolution.y > screen_size.y):
			window_resolution = screen_size

func video_int(config: ConfigFile, key: String, fallback: int, minimum: int, maximum: int) -> int:
	var value = config.get_value("video", key, fallback)
	return clampi(value, minimum, maximum) if value is int else fallback

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
	config.set_value("video","upscaling",upscaling)
	config.set_value("controls","toggle_crouch",toggle_crouch)
	config.set_value("controls","toggle_sprint",toggle_sprint)
	config.set_value("controls", "camera_sensitivity", camera_sensitivity)
	config.set_value("video", "fps_limit", fps_limit)
	config.set_value("video","fps_corner",fps_corner)
	config.set_value("video","window_mode",window_mode)
	config.set_value("video","window_width",window_resolution.x)
	config.set_value("video","window_height",window_resolution.y)
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
	customized = false
	apply_preset_values()
	if quality == 5:
		upscaling = 0
	apply()
	if persist:
		save_settings()

func apply_preset_values() -> void:
	texture_quality = 0 if quality == 5 else mini(quality, 3)
	shadow_quality = [3, 2, 1, 0, 0, 3][quality]
	antialiasing = 3 if quality == 5 else 0
	draw_distance = quality
	detail_maps = quality < 3 or quality == 5

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
	if mat is StandardMaterial3D:
		var id := mat.get_instance_id()
		if not tracked.has(id):
			var original := {"material": weakref(mat), "normal": mat.normal_enabled, "shading": mat.shading_mode, "texture": mat.albedo_texture}
			tracked[id] = original
			apply_material(mat, original)

func apply_material(mat: StandardMaterial3D, original: Dictionary) -> void:
	apply_texture(mat, original.texture)
	mat.normal_enabled = original.normal and detail_maps
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if quality == 4 else original.shading

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
	node.lod_bias = LOD_BIAS[draw_distance]
	if node.is_in_group("car_simple"):
		node.lod_bias = 1000.0
		node.visibility_range_end = FAR[draw_distance]
	elif node.is_in_group("car_detail"):
		node.visibility_range_end = minf(NEAR[draw_distance], 14.0) if node.has_meta("police_lod") else NEAR[draw_distance]
	elif node.is_in_group("car_far"):
		node.visibility_range_begin = minf(NEAR[draw_distance], 14.0) if node.has_meta("police_lod") else NEAR[draw_distance]
		node.visibility_range_end = FAR[draw_distance]
	elif node.is_in_group("car_shadow"):
		node.visibility_range_end = 70.0 if quality == 5 and shadow_quality == 3 else [0.1, 22.0, 34.0, 50.0][shadow_quality]
	elif node is Label3D:
		node.visibility_range_end = 110.0 if quality < 3 else 65.0

func apply() -> void:
	var extreme := quality == 5
	var long_shadows := extreme and shadow_quality == 3
	set_fps_limit(fps_limit, false)
	apply_upscaling()
	world.camera.far = FAR[draw_distance]
	world.get_viewport().msaa_3d = Viewport.MSAA_4X if antialiasing == 3 else (Viewport.MSAA_2X if antialiasing == 2 else Viewport.MSAA_DISABLED)
	for id in tracked.keys():
		var original: Dictionary = tracked[id]
		var mat: StandardMaterial3D = original.material.get_ref()
		if mat == null:
			tracked.erase(id)
		else:
			apply_material(mat, original)
	for node in world.find_children("*", "GeometryInstance3D", true, false):
		apply_range(node)
	for child in world.get_children():
		if child is DirectionalLight3D:
			child.shadow_enabled = shadow_quality > 0
			child.directional_shadow_max_distance = (74.0 if OS.has_feature("android") else 105.0) if long_shadows else [0.0, 22.0, 29.0, 35.0][shadow_quality]
			child.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if long_shadows else DirectionalLight3D.SHADOW_ORTHOGONAL
			child.directional_shadow_split_1 = 0.28
			child.directional_shadow_blend_splits = long_shadows
			child.light_color = Color(1, 0.923, 0.815) if extreme else Color(1, 0.94509804, 0.8509804)
			child.light_energy = 1.08 if extreme else 0.85
		elif child is WorldEnvironment:
			var environment: Environment = child.environment
			environment.ambient_light_energy = 0.52 if extreme else 0.4
			environment.tonemap_mode = Environment.TONE_MAPPER_ACES if extreme else Environment.TONE_MAPPER_FILMIC
			environment.tonemap_exposure = 0.89 if extreme else 0.8
			environment.fog_enabled = extreme or quality < 3
			environment.fog_mode = Environment.FOG_MODE_DEPTH if extreme else Environment.FOG_MODE_EXPONENTIAL
			environment.fog_depth_begin = 95.0
			environment.fog_depth_end = 900.0
			environment.fog_density = 0.63 if extreme else (0.0015 if quality < 2 else 0.003)
			environment.fog_sky_affect = 0.08 if extreme else 1.0
			environment.glow_enabled = extreme
			environment.glow_intensity = 0.26
			environment.glow_hdr_threshold = 1.13
			environment.adjustment_enabled = extreme
			environment.adjustment_saturation = 1.07
		elif child.name == &"MarCosta":
			child.material_override.set_shader_parameter(&"extreme_surface", extreme and detail_maps)
	for light in world.find_children("*", "OmniLight3D", true, false):
		light.visible = quality != 4

func set_upscaling(value: int) -> void:
	if value < 0 or value >= UPSCALING_SCALES.size():
		return
	upscaling=value
	apply_upscaling()
	save_settings()

func apply_upscaling() -> void:
	world.get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	world.get_viewport().scaling_3d_scale = UPSCALING_SCALES[upscaling]

func get_window_resolutions() -> Array[Vector2i]:
	var native_size := DisplayServer.screen_get_size()
	var result: Array[Vector2i] = []
	for resolution in WINDOW_RESOLUTIONS:
		if resolution.x <= native_size.x and resolution.y <= native_size.y:
			result.append(resolution)
	if window_resolution.x <= native_size.x and window_resolution.y <= native_size.y and not result.has(window_resolution):
		result.append(window_resolution)
	if not result.has(native_size):
		result.append(native_size)
	return result

func set_window_mode(value: int) -> void:
	if value < 0 or value >= WINDOW_MODES.size() or OS.has_feature("android"):
		return
	window_mode=value
	apply_display_settings()
	save_settings()

func set_window_resolution(value: Vector2i) -> void:
	if value.x <= 0 or value.y <= 0 or OS.has_feature("android"):
		return
	window_resolution=value
	apply_display_settings()
	save_settings()

func apply_display_settings() -> void:
	if OS.has_feature("android"):
		return
	if window_mode == 2:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		DisplayServer.window_set_size(window_resolution)
		var screen := maxi(DisplayServer.window_get_current_screen(), 0)
		DisplayServer.window_set_position(DisplayServer.screen_get_position(screen) + (DisplayServer.screen_get_size(screen) - window_resolution) / 2)
	else:
		DisplayServer.window_set_mode(WINDOW_MODES[window_mode])

func set_custom(key: String, value: int) -> void:
	customized=true
	match key:
		"textures": texture_quality=clampi(value,0,3)
		"shadows": shadow_quality=clampi(value,0,3)
		"aa": antialiasing = 0 if value == 1 else clampi(value, 0, 3)
		"distance": draw_distance=clampi(value,0,5)
		"details": detail_maps=value==1
	apply()
	save_settings()

func apply_texture(mat: StandardMaterial3D, source: Texture2D) -> void:
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
