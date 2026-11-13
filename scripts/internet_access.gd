extends Node

signal registered(open_id: String, local_port: int)
signal relayed(address: String, port: int, local_port: int)
signal failed(message: String)

const SERVER := "foxssake.studio"
const CONTROL_PORT := 8890
const REGISTRATION_PORT := 8809
var control: StreamPeerTCP
var udp: PacketPeerUDP
var address := ""
var open_id := ""
var private_id := ""
var local_port := 0
var hosting := false
var registered_remote := false
var sent_registration := false
var buffer := ""
var deadline := 0
var retry_at := 0
var relay_port := 0
var host_peer: ENetMultiplayerPeer
var handshakes: Array[Dictionary] = []
var resolver := IP.RESOLVER_INVALID_ID

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func start_online(as_host: bool) -> void:
	stop()
	hosting = as_host
	deadline = Time.get_ticks_msec() + 12000
	resolver = IP.resolve_hostname_queue_item(SERVER, IP.TYPE_IPV4)
	if resolver == IP.RESOLVER_INVALID_ID:
		_fail("O servico de salas nao respondeu. Tente novamente.")

func stop() -> void:
	if resolver != IP.RESOLVER_INVALID_ID:
		IP.erase_resolve_item(resolver)
		resolver = IP.RESOLVER_INVALID_ID
	if control != null:
		control.disconnect_from_host()
	if udp != null:
		udp.close()
	control = null
	udp = null
	host_peer = null
	open_id = ""
	private_id = ""
	buffer = ""
	local_port = 0
	relay_port = 0
	deadline = 0
	retry_at = 0
	registered_remote = false
	sent_registration = false
	handshakes.clear()

func request_relay(target: String) -> void:
	if control == null or not registered_remote:
		_fail("A conexao de internet ainda nao esta pronta.")
		return
	control.put_data(("connect-relay " + target + "\n").to_utf8_buffer())
	deadline = Time.get_ticks_msec() + 15000

func accept_relay(peer: ENetMultiplayerPeer, port: int) -> void:
	if handshakes.size() >= 16:
		return
	host_peer = peer
	handshakes.append({"port":port,"until":Time.get_ticks_msec()+8000,"next":0})

func _fail(message: String) -> void:
	stop()
	failed.emit(message)

func _command(line: String) -> void:
	var parts := line.split(" ", false, 1)
	if parts.size() != 2:
		return
	match parts[0]:
		"set-oid": open_id = parts[1]
		"set-pid": private_id = parts[1]
		"connect-relay":
			if not hosting and registered_remote and udp == null:
				return # A repeated notification must not replace an established client.
			if not registered_remote or not parts[1].is_valid_int() or parts[1].to_int() < 1 or parts[1].to_int() > 65535:
				_fail("Sala nao encontrada ou relay indisponivel. Confira o convite e tente novamente.")
				return
			relay_port = parts[1].to_int()
			if hosting:
				relayed.emit(address, relay_port, local_port)
			else:
				udp.set_dest_address(address, relay_port)
				retry_at = 0

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if deadline > 0 and now > deadline:
		_fail("O servico de salas demorou para responder. Confira sua internet e tente novamente.")
		return
	if resolver != IP.RESOLVER_INVALID_ID:
		var result := IP.get_resolve_item_status(resolver)
		if result == IP.RESOLVER_STATUS_WAITING:
			return
		address = IP.get_resolve_item_address(resolver) if result == IP.RESOLVER_STATUS_DONE else ""
		IP.erase_resolve_item(resolver)
		resolver = IP.RESOLVER_INVALID_ID
		if not address.is_valid_ip_address():
			_fail("O servico de salas nao respondeu. Tente novamente.")
			return
		control = StreamPeerTCP.new()
		if control.connect_to_host(address, CONTROL_PORT) != OK:
			_fail("Nao foi possivel acessar o servico de salas.")
			return
	if control == null:
		return
	control.poll()
	var state := control.get_status()
	if state in [StreamPeerTCP.STATUS_ERROR, StreamPeerTCP.STATUS_NONE]:
		_fail("Conexao com o servico de salas encerrada. Tente criar ou entrar novamente.")
		return
	if state != StreamPeerTCP.STATUS_CONNECTED:
		return
	if not sent_registration:
		sent_registration = true
		control.set_no_delay(true)
		control.put_data("register-host\n".to_utf8_buffer())
	var available := control.get_available_bytes()
	if available > 4096 or buffer.length() + available > 8192:
		_fail("Resposta invalida do servico de salas.")
		return
	if available > 0:
		buffer += control.get_utf8_string(available)
	while buffer.contains("\n"):
		var end := buffer.find("\n")
		var line := buffer.substr(0, end).strip_edges()
		buffer = buffer.substr(end + 1)
		_command(line)
		if control == null:
			return
	if not registered_remote and not open_id.is_empty() and not private_id.is_empty():
		if udp == null:
			udp = PacketPeerUDP.new()
			if udp.bind(0) != OK:
				_fail("Nao foi possivel preparar a conexao UDP.")
				return
			local_port = udp.get_local_port()
			udp.set_dest_address(address, REGISTRATION_PORT)
		if now >= retry_at:
			udp.put_packet(private_id.to_utf8_buffer())
			retry_at = now + 150
		while udp.get_available_packet_count() > 0:
			if udp.get_packet().get_string_from_utf8() == "OK":
				registered_remote = true
				deadline = 0
				if hosting:
					udp.close()
					udp = null
				registered.emit(open_id, local_port)
				break
	if not hosting and registered_remote and relay_port > 0 and udp != null:
		if now >= retry_at:
			udp.put_packet("$rwx".to_ascii_buffer())
			retry_at = now + 100
		while udp.get_available_packet_count() > 0:
			var packet := udp.get_packet().get_string_from_ascii()
			if packet.begins_with("$") and packet.contains("x"):
				udp.put_packet("$rwx".to_ascii_buffer())
				udp.close()
				udp = null
				deadline = 0
				relayed.emit(address, relay_port, local_port)
				break
	for handshake in handshakes.duplicate():
		if now > int(handshake.until) or host_peer == null or host_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
			handshakes.erase(handshake)
		elif now >= int(handshake.next):
			host_peer.host.socket_send(address, int(handshake.port), "$rwx".to_ascii_buffer())
			handshake.next = now + 100

func _exit_tree() -> void:
	stop()

static func public_ipv4(ip: String) -> bool:
	if not ip.is_valid_ip_address() or ip.contains(":"):
		return false
	var parts := ip.split(".")
	var a := parts[0].to_int()
	var b := parts[1].to_int()
	return not (a in [0,10,127] or a>=224 or (a==100 and b>=64 and b<=127) or (a==169 and b==254) or (a==172 and b>=16 and b<=31) or (a==192 and b==168))
