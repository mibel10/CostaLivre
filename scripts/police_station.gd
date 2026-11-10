extends Node3D
const CENTER := Vector3(105,0,21)
var world: Node3D
var fleet: Array[CharacterBody3D] = []
var repair_clock := 0.0

const STATIONS := [
	{"center":CENTER,"count":5,"columns":5,"home_z":8,"spacing":7,"exit_z":42},
	{"center":Vector3(483,0,21),"count":15,"columns":5,"home_z":-4,"spacing":7,"exit_z":42},
	{"center":Vector3(735,0,105),"count":7,"columns":4,"home_z":-4,"spacing":11,"exit_z":126}]

func _ready() -> void:
	position = CENTER
	for station in STATIONS:
		for i in int(station.count):
			var home: Vector3 = station.center+Vector3((i%int(station.columns)-(int(station.columns)-1)*0.5)*5,0.15,int(station.home_z)+(i/int(station.columns))*int(station.spacing))
			var car: CharacterBody3D = world.spawn_car(home,Color("24394b"),true,1)
			world.cops.erase(car)
			car.police_home = home
			car.police_phase = "parked"
			car.heading = PI
			car.rotation.y = PI
			car.set_meta("station_center",station.center)
			car.set_meta("station_exit",Vector3(home.x,0,station.exit_z))
			fleet.append(car)

func dispatch(delta: float) -> void:
	world.response_delay = maxf(0,world.response_delay-delta)
	world.crime_grace = maxf(0,world.crime_grace-delta)
	var quotas := {}
	if world.response_delay <= 0 and world.heat > 0:
		var online: bool = world.network != null and world.network.active()
		var actors: Array = world.network.rules.wanted_participants() if online else [0]
		for actor in actors:
			var wanted: float = world.network.rules.wanted_heat(actor) if online else world.heat
			quotas[actor] = 7 if wanted > 80 else ceili(wanted / 20.0)
	var assigned := {}
	for car in world.cops.duplicate():
		if not is_instance_valid(car):
			world.cops.erase(car)
			continue
		var actor: int = int(car.get_meta("police_target_peer",0))
		if car.hp <= 0 or int(assigned.get(actor,0)) >= int(quotas.get(actor, 0)):
			world.cops.erase(car)
			car.police_phase = "return" if car.hp > 0 else "parked"
			car.remove_meta("police_target_peer")
		else:
			assigned[actor] = int(assigned.get(actor,0))+1
	for actor in quotas:
		var quota: int = quotas[actor]
		if int(assigned.get(actor, 0)) >= quota:
			continue
		var target: Vector3 = world.network.rules.position_of(actor) if actor > 0 else world.subject_position()
		var available := fleet.filter(func(car): return is_instance_valid(car) and car.hp > 0 and car.police_phase in ["parked","return","dock"])
		available.sort_custom(func(a,b):
			var da: float = a.get_meta("station_center").distance_squared_to(target)
			var db: float = b.get_meta("station_center").distance_squared_to(target)
			return a.police_home.z > b.police_home.z if is_equal_approx(da,db) else da < db
		)
		for car in available:
			if int(assigned.get(actor,0)) >= quota: break
			car.set_meta("police_target_peer",actor)
			if car.police_phase == "parked":
				car.heading = PI
				car.rotation.y = PI
				car.police_phase = "exit"
			else:
				car.police_phase = "pursuit"
			world.cops.append(car)
			assigned[actor] = int(assigned.get(actor,0))+1
	repair_clock += delta
	if repair_clock > 60 and world.heat <= 0:
		repair_clock = 0
		for car in fleet:
			if is_instance_valid(car) and car.hp <= 0:
				car.repair()
				car.position = car.police_home
				car.velocity = Vector3.ZERO
				car.police_phase = "parked"

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
	replacement.set_meta("station_center",car.get_meta("station_center",CENTER))
	replacement.set_meta("station_exit",car.get_meta("station_exit",Vector3(home.x,0,42)))
	fleet.insert(index,replacement)
