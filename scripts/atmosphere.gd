extends Node3D

const DAY_LENGTH_SECONDS := 1200.0
var world: Node3D
var planes: Array[Node3D] = []
var clocks := [0.0, 7.0]
var day_time := 9.0
var environment: Environment
var sun: DirectionalLight3D

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

func _process(delta: float) -> void:
	day_time = fposmod(day_time + delta * 24.0 / DAY_LENGTH_SECONDS, 24.0)
	update_lighting()
	for i in planes.size():
		clocks[i] = fposmod(clocks[i] + delta * (0.004 if i == 0 else 0.003), 1.0)
		var plane := planes[i]
		plane.position.x = lerpf(-210, 210, clocks[i]) if i == 0 else lerpf(210, -210, clocks[i])
		plane.rotation.y = PI if i == 1 else 0.0

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
	if environment != null:
		environment.ambient_light_color = Color("38465f").lerp(Color("b4ced8"), daylight)
		environment.ambient_light_energy = lerpf(0.16, 0.4, daylight)
		environment.fog_light_color = Color("29364d").lerp(Color("9aafba"), daylight)
		environment.background_energy_multiplier = lerpf(0.35, 1.0, daylight)
