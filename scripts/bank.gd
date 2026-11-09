extends Node3D

const ENTRY := Vector3(0, 0, 16)
const BREAKER := Vector3(-9, 0, 7)
const TERMINAL := Vector3(8, 0, 2)
const VAULT_PANEL := Vector3(-4, 0, -1)
const BAGS := [Vector3(-5, 0, -10), Vector3(0, 0, -11), Vector3(5, 0, -10)]
var world: Node3D
var phase := 0 # security, terminal, vault panel, loot, escape, cooldown
var hacking := false
var pattern: Array[int] = []
var entered := 0
var round_index := 0
var mistakes := 0
var reveal_time := 0.0
var round_time := 0.0
var lockout := 0.0
var cooldown := 0.0
var taken := [false, false, false]
var bag_models: Array[MeshInstance3D] = []
var door: Node3D
var security_light: MeshInstance3D
var screen: MeshInstance3D

func _ready() -> void:
	position = Vector3(21, 0, -105)
	var fixed_bank: Node = world.interiors.get_node("Bank")
	door = fixed_bank.get_node("VaultDoor")
	security_light = fixed_bank.get_node("SecurityLight")
	screen = fixed_bank.get_node("TerminalScreen")
	for i in 3:
		bag_models.append(fixed_bank.get_node("Bag%d" % i))

func inside() -> bool:
	return world.active_car == null and contains_position(world.player.position)

func contains_position(at: Vector3) -> bool:
	var p := to_local(at)
	return absf(p.x) < 13.6 and p.z > -13.5 and p.z < 13.7 and p.y < 7

func near(local_point: Vector3) -> bool:
	return world.active_car == null and world.player.position.distance_to(to_global(local_point)) < 2.4

func next_position() -> Vector3:
	if not inside():
		return to_global(ENTRY)
	match phase:
		0: return to_global(BREAKER)
		1: return to_global(TERMINAL)
		2: return to_global(VAULT_PANEL)
		3:
			for i in BAGS.size():
				if not taken[i]:
					return to_global(BAGS[i])
	return to_global(ENTRY)

func objective() -> String:
	if phase == 5:
		return "Banco em recuperação · %ds" % ceili(cooldown)
	if not inside() and phase < 4:
		return "Entre no Banco Costa pela porta da frente"
	return ["Desligue a segurança no painel", "Hackeie o terminal do banco", "Acione o painel da porta do cofre", "Pegue os malotes · %d/3" % taken.count(true), "Saia do banco com o dinheiro"][mini(phase, 4)]

func prompt() -> String:
	if phase == 5 or hacking:
		return ""
	if near(BREAKER) and phase == 0:
		return "F · Desligar segurança"
	if near(TERMINAL) and phase == 1:
		return "F · Hackear terminal" if lockout <= 0 else "Terminal bloqueado · %ds" % ceili(lockout)
	if near(VAULT_PANEL) and phase == 2:
		return "F · Abrir cofre"
	if phase == 3:
		for i in BAGS.size():
			if not taken[i] and near(BAGS[i]):
				return "F · Pegar malote"
	return ""

func interact() -> bool:
	if prompt() == "":
		return false
	match phase:
		0:
			phase = 1
			security_light.material_override = world.material(Color("6acbaa"), true)
			world.notify("Segurança desligada. Procure o terminal no salão.")
		1:
			if lockout <= 0:
				hacking = true
				round_index = 0
				new_round()
		2:
			phase = 3
			world.raise_heat(55)
			world.notify("Cofre liberado! Alarme disparado. Pegue os três malotes e saia.")
		3:
			for i in BAGS.size():
				if not taken[i] and near(BAGS[i]):
					taken[i] = true
					bag_models[i].visible = false
					world.notify("Malote %d/3 na mochila." % taken.count(true))
					if taken.count(true) == 3:
						phase = 4
					return true
	return true

func new_round() -> void:
	pattern.clear()
	for i in 3 + round_index:
		pattern.append(world.rng.randi_range(1, 4))
	entered = 0
	reveal_time = 2.5
	round_time = 14

func handle_input(event: InputEvent) -> bool:
	if not hacking:
		return false
	if event.is_action_pressed("pause"):
		hacking = false
		world.notify("Hack cancelado. F no terminal para tentar novamente.")
	elif event is InputEventKey and event.pressed and not event.echo and reveal_time <= 0:
		var digit: int = event.physical_keycode - KEY_1 + 1
		if digit >= 1 and digit <= 4:
			enter_digit(digit)
	return true

func enter_digit(digit: int) -> void:
	if not hacking or reveal_time > 0:
		return
	if digit != pattern[entered]:
		fail_round()
		return
	entered += 1
	if entered == pattern.size():
		round_index += 1
		if round_index >= 3:
			phase = 2
			hacking = false
			screen.material_override = world.material(Color("66cba3"), true)
			world.notify("Hack concluído. Vá até o painel do cofre.")
		else:
			new_round()

func fail_round() -> void:
	mistakes += 1
	world.notify("Sequência incorreta. Falhas: %d/3." % mistakes)
	if mistakes >= 3:
		hacking = false
		lockout = 15
		mistakes = 0
		world.raise_heat(30)
		world.notify("Alarme de segurança! Terminal bloqueado por 15 segundos.")
	else:
		new_round()

func tick(delta: float) -> void:
	lockout = maxf(0, lockout - delta)
	if hacking:
		if not near(TERMINAL):
			hacking = false
		else:
			if reveal_time > 0:
				reveal_time = maxf(0, reveal_time - delta)
			else:
				round_time -= delta
				if round_time <= 0:
					fail_round()
	door.rotation.y = move_toward(door.rotation.y, PI / 2 if phase >= 3 else 0.0, delta * 1.2)
	if phase == 4 and not inside() and world.player.position.distance_to(to_global(ENTRY)) < 5:
		world.cash += 4000
		phase = 5
		cooldown = 100
		if world.activities.job == 5:
			world.activities.stage = 1
		world.notify("+$4000! Agora despiste a polícia para concluir o golpe.")
	if phase == 5:
		cooldown = maxf(0, cooldown - delta)
		if cooldown <= 0 and not inside():
			phase = 0
			taken = [false, false, false]
			mistakes = 0
			for bag in bag_models:
				bag.visible = true
			security_light.material_override = world.material(Color("ef9d6b"), true)
			screen.material_override = world.material(Color("66bbcc"), true)

func local_hacking() -> bool:
	return hacking and (world.network==null or not world.network.active() or world.network.rules.bank_owner==multiplayer.get_unique_id())
