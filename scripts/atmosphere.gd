extends Node3D

const DAY_LENGTH_SECONDS := 600.0
const STORM_CHECK_SECONDS := 120.0
const STORM_CHANCE := 0.05
const STORM_DURATION := 90.0
var world: Node3D
var planes: Array[Node3D] = []
var clocks := [0.0, 7.0]
var day_time := 9.0
var environment: Environment
var sun: DirectionalLight3D
var storm := 0.0
var rain: CPUParticles3D
var flood_surface: MultiMeshInstance3D
var flood_regions: Array[Rect2] = []
var storm_remaining := 0.0
var storm_check := STORM_CHECK_SECONDS
var thunder_beat := -1
var shelter_check := 0.0
var sheltered := false

func _ready() -> void:
	for i in 2:
		planes.append(world.interiors.get_node("Atmosphere/Plane%d" % i))
	var environments := world.find_children("*", "WorldEnvironment", true, false)
	var lights := world.find_children("*", "DirectionalLight3D", true, false)
	if not environments.is_empty():
		environment = environments[0].environment
	if not lights.is_empty():
		sun = lights[0]
	update_lighting()
	rain = CPUParticles3D.new()
	rain.amount = 180
	rain.lifetime = 0.65
	rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain.emission_box_extents = Vector3(13,2,13)
	rain.direction = Vector3(0.15,-1,0)
	rain.spread = 5
	rain.initial_velocity_min = 22
	rain.initial_velocity_max = 28
	var drop := BoxMesh.new()
	drop.size = Vector3(0.018,0.45,0.018)
	rain.mesh = drop
	rain.emitting = false
	add_child(rain)
	# Road strips cover the fixed city without a giant water slab over buildings.
	for z in [-126,-84,-42,0,42,84,126]:
		flood_regions.append(Rect2(-147,z-4,world.MAP_EAST+147,8))
	var columns: Array = [-126,-84,-42,0,42,84,126]
	for x in range(210,1345,84): columns.append(x)
	for x in columns:
		for z in range(-126,126,42):
			flood_regions.append(Rect2(x-4,z+4,8,34))
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	var water_material := ShaderMaterial.new()
	water_material.shader = preload("res://shaders/water.gdshader")
	flood_surface = MultiMeshInstance3D.new()
	flood_surface.material_override = water_material
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = mesh
	batch.instance_count = flood_regions.size()
	for i in flood_regions.size():
		var region: Rect2 = flood_regions[i]
		var center := region.get_center()
		batch.set_instance_transform(i,Transform3D(Basis.from_scale(Vector3(region.size.x,0.04,region.size.y)),Vector3(center.x,0,center.y)))
	flood_surface.multimesh = batch
	flood_surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flood_surface.visible = false
	add_child(flood_surface)

func _process(delta: float) -> void:
	day_time = fposmod(day_time + delta * 24.0 / DAY_LENGTH_SECONDS, 24.0)
	if not world.network.is_client():
		if storm_remaining > 0.0:
			storm_remaining = maxf(0.0,storm_remaining-delta)
		else:
			storm_check -= delta
			if storm_check <= 0.0:
				storm_check = STORM_CHECK_SECONDS
				if randf() < STORM_CHANCE: storm_remaining = STORM_DURATION
	else:
		storm_remaining = maxf(0.0,storm_remaining-delta)
	storm = clampf(minf(STORM_DURATION-storm_remaining,storm_remaining)/15.0,0.0,1.0)
	update_lighting()
	shelter_check -= delta
	if shelter_check <= 0.0:
		shelter_check = 0.25
		var at: Vector3 = world.subject_position()
		var roof := PhysicsRayQueryParameters3D.create(at+Vector3.UP*1.5,at+Vector3.UP*20,1)
		sheltered = world.life.inside_public_interior(at) or world.PRISON_INTERIOR.has_point(at) or not get_world_3d().direct_space_state.intersect_ray(roof).is_empty()
	rain.position = world.subject_position()+Vector3.UP*10
	rain.emitting = storm > 0.1 and not sheltered
	flood_surface.visible = storm > 0.25
	flood_surface.position.y = 0.05+storm*0.22
	var beat := int(day_time*20.0)
	if storm > 0.5 and beat%7 == 0 and beat != thunder_beat:
		thunder_beat = beat
		world.extra.play("thunder",-15)
	for i in planes.size():
		clocks[i] = fposmod(clocks[i] + delta * (0.004 if i == 0 else 0.003), 1.0)
		var plane := planes[i]
		plane.position.x = lerpf(-210, 210, clocks[i]) if i == 0 else lerpf(210, -210, clocks[i])
		plane.rotation.y = PI if i == 1 else 0.0

func flooded(at: Vector3) -> bool:
	if storm < 0.5 or at.y > 0.8 or at.y < -0.5: return false
	# Same fixed road grid as the water batch, without scanning every strip per car.
	var row := clampf(roundf(at.z/42.0)*42.0,-126,126)
	if at.x >= -147 and at.x < world.MAP_EAST and at.z >= row-4 and at.z < row+4: return true
	if at.z >= -126 and at.z < 126:
		var column := clampf(roundf(at.x/42.0)*42.0,-126,126) if at.x < 168 else clampf(210+roundf((at.x-210)/84.0)*84.0,210,1302)
		return at.x >= column-4 and at.x < column+4
	return false

func set_time(value: float) -> void:
	if not is_finite(value):
		return
	day_time = fposmod(value, 24.0)
	update_lighting()

func update_lighting() -> void:
	var sun_height := cos((day_time - 12.0) / 12.0 * PI)
	var daylight := clampf((sun_height + 0.12) / 1.12, 0.0, 1.0)
	var extreme: bool = world.settings != null and world.settings.quality == 5
	var light_color := Color("7085bc").lerp(Color("fff0d1"), daylight)
	if sun != null:
		sun.rotation.x = -sun_height * deg_to_rad(60.0)
		sun.light_color = light_color
		sun.light_energy = lerpf(0.08, 0.85, daylight)
		sun.light_energy *= lerpf(1.0,0.35,storm)
		if extreme:
			sun.light_energy *= 1.25
			sun.light_color = sun.light_color.lerp(Color("ffd7aa"),clampf(1.0-absf(sun_height)*2.0,0.0,1.0)*0.35)
	if environment != null:
		environment.ambient_light_color = Color("38465f").lerp(Color("b4ced8"), daylight)
		environment.ambient_light_energy = lerpf(0.16, 0.4, daylight)
		if extreme: environment.ambient_light_energy = lerpf(0.18,0.55,daylight)
		environment.fog_light_color = Color("29364d").lerp(Color("9aafba"), daylight)
		environment.background_energy_multiplier = lerpf(0.35, 1.0, daylight)
		environment.background_energy_multiplier *= lerpf(1.0,0.4,storm)
		environment.fog_light_color = environment.fog_light_color.lerp(Color("384858"),storm*0.7)
