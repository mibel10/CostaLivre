extends Node3D
const CENTER := Vector3(105,0,21)
var world: Node3D
var fleet: Array[CharacterBody3D] = []
var repair_clock := 0.0

func _ready() -> void:
	position=CENTER
	for i in 5:
		var home := CENTER+Vector3(-10+i*5,0.15,8)
		var car: CharacterBody3D=world.spawn_car(home,Color("24394b"),true,1)
		world.cops.erase(car)
		car.police_home=home
		car.police_phase="parked"
		car.heading=PI
		car.rotation.y=PI
		fleet.append(car)

func dispatch(delta: float) -> void:
	world.response_delay=maxf(0,world.response_delay-delta)
	world.crime_grace=maxf(0,world.crime_grace-delta)
	for car in world.cops.duplicate():
		if car.hp<=0:
			world.cops.erase(car)
			car.police_phase="parked"
	var needed := ceili(world.heat/20.0) if world.response_delay<=0 else 0
	while world.cops.size()>needed:
		var car: CharacterBody3D=world.cops.pop_back()
		car.police_phase="return"
	for car in fleet:
		if not is_instance_valid(car):
			continue
		if world.cops.size()>=needed:
			break
		if car.hp>0 and car.police_phase in ["parked","return","dock"]:
			if car.police_phase=="parked":
				car.heading=PI
				car.rotation.y=PI
			car.police_phase="exit" if car.police_phase=="parked" else "pursuit"
			world.cops.append(car)
	repair_clock+=delta
	if repair_clock>60 and world.heat<=0:
		repair_clock=0
		for car in fleet:
			if is_instance_valid(car) and car.hp<=0:
				car.repair()
				car.position=car.police_home
				car.velocity=Vector3.ZERO
				car.police_phase="parked"

func car_destroyed(car: CharacterBody3D) -> void:
	var index:=fleet.find(car)
	if index<0:
		return
	fleet.remove_at(index)
	var home: Vector3=car.police_home
	var replacement: CharacterBody3D=world.spawn_car(home,Color("24394b"),true,1)
	world.cops.erase(replacement)
	replacement.police_home=home
	replacement.police_phase="parked"
	replacement.heading=PI
	replacement.rotation.y=PI
	fleet.insert(index,replacement)
