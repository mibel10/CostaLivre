extends Node

signal prepared(address: String, mapped: bool, message: String)
var worker: Thread
var router: UPNP
var stopping := false
var cleaning := false
var renew_clock := 0.0
const PORT := 28960

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func start() -> void:
	if worker != null or router != null:
		prepared.emit("",false,"Aguarde o encerramento da conexao anterior.")
		return
	stopping=false
	cleaning=false
	worker=Thread.new()
	var error := worker.start(_setup)
	if error!=OK:
		worker=null
		prepared.emit("",false,"Nao foi possivel preparar a conexao automatica.")

func _setup() -> Dictionary:
	var device := UPNP.new()
	if device.discover(4000,2,"InternetGatewayDevice")!=UPNP.UPNP_RESULT_SUCCESS:
		return {"message":"Abertura automatica indisponivel. Encaminhe UDP 28960 no roteador do anfitriao."}
	var gateway := device.get_gateway()
	if gateway==null or not gateway.is_valid_gateway():
		return {"message":"Roteador sem gateway UPnP compativel. Configure UDP 28960 manualmente."}
	var address := device.query_external_address()
	if not public_ipv4(address):
		return {"message":"O roteador informou IP privado/CGNAT. Use outro anfitriao ou uma conexao com acesso externo."}
	var result := device.add_port_mapping(PORT,PORT,"CostaLivre","UDP",3600)
	if result!=UPNP.UPNP_RESULT_SUCCESS:
		return {"address":address,"message":"Porta nao confirmada. Encaminhe UDP 28960 no roteador do anfitriao."}
	return {"router":device,"address":address,"message":"Porta solicitada ao roteador. Compartilhe o convite para conectar."}

func stop() -> void:
	stopping=true
	if worker==null and router!=null:
		cleaning=true
		worker=Thread.new()
		if worker.start(_remove)!=OK:
			worker=null

func _remove() -> Dictionary:
	if router!=null:
		router.delete_port_mapping(PORT,"UDP")
	return {}

static func public_ipv4(address: String) -> bool:
	if not address.is_valid_ip_address() or address.contains(":"):
		return false
	var parts := address.split(".")
	var a := parts[0].to_int()
	var b := parts[1].to_int()
	return not (a in [0,10,127] or a>=224 or (a==100 and b>=64 and b<=127) or (a==169 and b==254) or (a==172 and b>=16 and b<=31) or (a==192 and b==168))

func _renew() -> Dictionary:
	var result := router.add_port_mapping(PORT,PORT,"CostaLivre","UDP",3600)
	return {"router":router,"address":router.query_external_address(),"message":"Porta renovada." if result==UPNP.UPNP_RESULT_SUCCESS else "Confira o encaminhamento de porta do anfitriao."}

func _process(delta: float) -> void:
	if worker==null and router!=null and not stopping:
		renew_clock+=delta
		if renew_clock>1800:
			renew_clock=0
			worker=Thread.new()
			if worker.start(_renew)!=OK:
				worker=null
	if worker==null or worker.is_alive():
		return
	var result: Dictionary=worker.wait_to_finish()
	worker=null
	if cleaning:
		router=null
		cleaning=false
		return
	router=result.get("router")
	if stopping:
		stop()
	else:
		prepared.emit(result.get("address",""),router!=null,result.get("message",""))

func _exit_tree() -> void:
	if worker!=null:
		var result: Dictionary=worker.wait_to_finish()
		if not cleaning:
			router=result.get("router")
	if router!=null:
		router.delete_port_mapping(PORT,"UDP")
