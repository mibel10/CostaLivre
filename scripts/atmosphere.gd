extends Node3D

var world: Node3D
var planes: Array[Node3D] = []
var clocks := [0.0, 7.0]

func _ready() -> void:
	for i in 2:
		planes.append(world.interiors.get_node("Atmosphere/Plane%d" % i))

func _process(delta: float) -> void:
	for i in planes.size():
		clocks[i] = fposmod(clocks[i] + delta * (0.004 if i == 0 else 0.003), 1.0)
		var plane := planes[i]
		plane.position.x = lerpf(-210,210,clocks[i]) if i == 0 else lerpf(210,-210,clocks[i])
		plane.rotation.y = PI if i == 1 else 0.0
