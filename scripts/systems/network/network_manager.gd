extends Node

const DEFAULT_PORT := 7777
const MAX_PLAYERS  := 16
const UPNP_REFRESH_INTERVAL := 300.0
const PORT_RETRY_COUNT := 5

signal server_created
signal join_succeeded
signal join_failed(reason: String)
signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)
signal server_disconnected
signal session_ended
signal upnp_completed(success: bool, message: String)
signal public_ip_received(ip: String)

var players: Dictionary = {}
var upnp: UPNP
var upnp_thread: Thread
var upnp_port: int = -1
var upnp_refresh_timer: Timer

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	upnp_refresh_timer = Timer.new()
	upnp_refresh_timer.wait_time = UPNP_REFRESH_INTERVAL
	upnp_refresh_timer.timeout.connect(_refresh_upnp)
	add_child(upnp_refresh_timer)

func host_local() -> void:
	var peer := OfflineMultiplayerPeer.new()
	multiplayer.multiplayer_peer = peer
	players[1] = { "id": 1 }
	server_created.emit.call_deferred()

func host(port: int = DEFAULT_PORT) -> void:
	var actual_port := _try_create_server(port)
	if actual_port == -1:
		push_error("NetworkManager: failed to create server, no free port found")
		return
	players[1] = { "id": 1 }
	server_created.emit.call_deferred()
	upnp_port = actual_port
	_start_upnp_thread(actual_port)
	upnp_refresh_timer.start()

func _try_create_server(start_port: int) -> int:
	var port := start_port
	for i in range(PORT_RETRY_COUNT):
		var peer := ENetMultiplayerPeer.new()
		var err := peer.create_server(port, MAX_PLAYERS)
		if err == OK:
			multiplayer.multiplayer_peer = peer
			return port
		port += 1
	return -1

func _start_upnp_thread(port: int) -> void:
	if upnp_thread and upnp_thread.is_started():
		upnp_thread.wait_to_finish()
	upnp_thread = Thread.new()
	upnp_thread.start(_upnp_setup_threaded.bind(port))

func _upnp_setup_threaded(port: int) -> void:
	var local_upnp := UPNP.new()
	var discover_result := local_upnp.discover()
	if discover_result != UPNP.UPNP_RESULT_SUCCESS:
		call_deferred("_on_upnp_result", false, "UPnP discovery failed: " + str(discover_result), null)
		return
	if not local_upnp.get_gateway() or not local_upnp.get_gateway().is_valid_gateway():
		call_deferred("_on_upnp_result", false, "No valid UPnP gateway found", null)
		return
	var map_udp := local_upnp.add_port_mapping(port, port, "godot_game_udp", "UDP")
	var map_tcp := local_upnp.add_port_mapping(port, port, "godot_game_tcp", "TCP")
	if map_udp != UPNP.UPNP_RESULT_SUCCESS or map_tcp != UPNP.UPNP_RESULT_SUCCESS:
		call_deferred("_on_upnp_result", false, "Port mapping failed (UDP: %s, TCP: %s)" % [map_udp, map_tcp], null)
		return
	call_deferred("_on_upnp_result", true, "Port %d opened successfully" % port, local_upnp)

func _on_upnp_result(success: bool, message: String, result_upnp: UPNP) -> void:
	if success:
		upnp = result_upnp
	upnp_completed.emit(success, message)
	if upnp_thread and upnp_thread.is_started():
		upnp_thread.wait_to_finish()

func _refresh_upnp() -> void:
	if not multiplayer.is_server() or upnp_port == -1:
		upnp_refresh_timer.stop()
		return
	_start_upnp_thread(upnp_port)

func close_upnp() -> void:
	upnp_refresh_timer.stop()
	if upnp_thread and upnp_thread.is_started():
		upnp_thread.wait_to_finish()
	if upnp and upnp_port != -1:
		upnp.delete_port_mapping(upnp_port, "UDP")
		upnp.delete_port_mapping(upnp_port, "TCP")
	upnp = null
	upnp_port = -1

func get_public_ip() -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_public_ip_response.bind(http))
	http.request("https://api.ipify.org")

func _on_public_ip_response(_result, _code, _headers, body: PackedByteArray, http: HTTPRequest) -> void:
	var ip := body.get_string_from_utf8()
	public_ip_received.emit(ip)
	http.queue_free()

func join(ip: String, port: int = DEFAULT_PORT) -> void:
	var peer := ENetMultiplayerPeer.new()
	var err   := peer.create_client(ip, port)
	if err != OK:
		join_failed.emit("Failed to create client: " + str(err))
		return
	multiplayer.multiplayer_peer = peer

func disconnect_from_game() -> void:
	session_ended.emit()
	if multiplayer.is_server():
		close_upnp()
	multiplayer.multiplayer_peer = null
	players.clear()

func is_connected_to_game() -> bool:
	if multiplayer.multiplayer_peer == null:
		return false
	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		return true
	if multiplayer.is_server():
		return true
	return multiplayer.multiplayer_peer.get_connection_status() \
		== MultiplayerPeer.CONNECTION_CONNECTED

func is_host() -> bool:
	return multiplayer.is_server()

func get_my_id() -> int:
	return multiplayer.get_unique_id()

func _on_peer_connected(peer_id: int) -> void:
	players[peer_id] = { "id": peer_id }
	player_connected.emit(peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	players.erase(peer_id)
	player_disconnected.emit(peer_id)

func _on_connected_to_server() -> void:
	players[get_my_id()] = { "id": get_my_id() }
	join_succeeded.emit()

func _on_connection_failed() -> void:
	multiplayer.multiplayer_peer = null
	join_failed.emit("Connection timed out")
	
func _on_server_disconnected() -> void:
	session_ended.emit()
	multiplayer.multiplayer_peer = null
	players.clear()
	server_disconnected.emit()
