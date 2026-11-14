extends Node3D

const DAY_LENGTH_SECONDS := 1200.0
var world: Node3D
var planes: Array[Node3D] = []
var clocks := [0.0, 7.0]
var day_time := 9.0
var environment: Environment
var sun: DirectionalLight3D
var storm := 0.0
var rain: CPUParticles3D
var flood_surfaces: Array[MeshInstance3D] = []
const FLOOD_POINTS := [Vector3(0,0,84),Vector3(294,0,126),Vector3(798,0,126)]
var thunder_beat := -1

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
	for at in FLOOD_POINTS:
		var water: MeshInstance3D = world.box(self,at+Vector3.UP*0.12,Vector3(28,0.06,9),Color("486879"))
		water.visible = false
		flood_surfaces.append(water)

func _process(delta: float) -> void:
	day_time = fposmod(day_time + delta * 24.0 / DAY_LENGTH_SECONDS, 24.0)
	update_lighting()
	storm = clampf(minf(day_time-14.0,17.0-day_time)*2.0,0.0,1.0)
	rain.position = world.subject_position()+Vector3.UP*10
	rain.emitting = storm > 0.1 and not world.life.inside_public_interior(world.subject_position())
	for surface in flood_surfaces:
		surface.visible = storm > 0.25
		surface.position.y = 0.05+storm*0.22
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
	for center in FLOOD_POINTS:
		if absf(at.x-center.x)<14 and absf(at.z-center.z)<4.5: return true
	return false

func set_time(value: float) -> void:
	if not is_finite(value):
		return
	day_time = fposmod(value, 24.0)
	update_lighting()

func update_lighting() -> void:
	var sun_height := cos((day_time - 12.0) / 12.0 * PI)
	var daylight := clampf((sun_height + 0.12) / 1.12, 0.0, 1.0)
	var light_color := Color("7085bc").lerp(Color("fff0d1"), daylight)
	if sun != null:
		sun.rotation.x = -sun_height * deg_to_rad(60.0)
		sun.light_color = light_color
		sun.light_energy = lerpf(0.08, 0.85, daylight)
		sun.light_energy *= lerpf(1.0,0.35,storm)
	if environment != null:
		environment.ambient_light_color = Color("38465f").lerp(Color("b4ced8"), daylight)
		environment.ambient_light_energy = lerpf(0.16, 0.4, daylight)
		environment.fog_light_color = Color("29364d").lerp(Color("9aafba"), daylight)
		environment.background_energy_multiplier = lerpf(0.35, 1.0, daylight)
