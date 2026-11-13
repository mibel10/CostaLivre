extends SceneTree

func _initialize() -> void:
	create_timer(5).timeout.connect(func(): quit(1))
	var session := load("res://scripts/lan_session.gd")
	var router := load("res://scripts/internet_access.gd")
	var connection: Node = router.new()
	root.add_child(connection)
	connection.start_online(true)
	assert(connection.resolver != IP.RESOLVER_INVALID_ID and connection.control == null, "DNS resolution is queued")
	connection.stop()
	assert(connection.resolver == IP.RESOLVER_INVALID_ID and connection.deadline == 0, "Cancellation clears DNS and timeout")
	connection.registered_remote = true
	connection.relay_port = 30000
	connection._command("connect-relay 30000")
	assert(connection.relay_port == 30000 and connection.udp == null, "Duplicate relay notifications leave an established client alone")
	connection.queue_free()
	var relay_invite := "CL2-" + "ZRxfX4SxDgt1Vn3v5MqbX|AB123".to_utf8_buffer().hex_encode()
	var relay: Dictionary = session.parse_target(relay_invite.to_lower(), "")
	assert(relay.relay == "ZRxfX4SxDgt1Vn3v5MqbX" and relay.code == "AB123")
	for invalid in ["CL2-", "CL2-xyz", "CL2-" + "id\nconnect-relay other|AB123".to_utf8_buffer().hex_encode(), "CL2-" + "id|AB!23".to_utf8_buffer().hex_encode()]:
		assert(session.parse_target(invalid, "").is_empty())
	for i in 128:
		var ip := "%d.%d.%d.%d" % [1+i,i%255,(i*7)%256,(i*13)%256]
		var encoded: String=session.make_internet_code(ip,28960+i,"AB123")
		var decoded: Dictionary=session.parse_target(encoded.to_lower(),"")
		assert(decoded.address==ip and decoded.port==28960+i and decoded.code=="AB123")
		assert(session.parse_target(encoded.substr(0,encoded.length()-1),"").is_empty())
	var sample: String=session.make_internet_code("203.0.113.5",28960,"AB123")
	var changed := sample.substr(0,sample.length()-1)+("A" if not sample.ends_with("A") else "B")
	assert(session.parse_target(changed,"").is_empty())
	var target: Dictionary = session.parse_target("CL://203.0.113.5:34567/ab123","")
	assert(target.address=="203.0.113.5" and target.port==34567 and target.code=="AB123")
	assert(session.parse_target("game.example.com","AB123").port==28960)
	for value in ["https://example.com/AB123","CL://:28960/AB123","CL://example.com:99999/AB123","CL://example.com:abc/AB123","CL://example.com:28960/AB!23"]:
		assert(session.parse_target(value,"").is_empty(),value)
	for address in ["10.0.0.1","100.64.0.1","172.16.0.1","192.168.1.1","127.0.0.1"]:
		assert(not router.public_ipv4(address))
	assert(router.public_ipv4("8.8.8.8"))
	print("PASS: internet invites, ports, codes, private IP/CGNAT detection")
	quit()
