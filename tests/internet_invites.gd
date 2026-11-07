extends SceneTree

func _initialize() -> void:
	create_timer(5).timeout.connect(func(): quit(1))
	var session := load("res://scripts/lan_session.gd")
	var router := load("res://scripts/internet_access.gd")
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
