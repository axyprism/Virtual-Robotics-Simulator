extends Node

const DEFAULT_PORT := 7777
const MAX_PLAYERS  := 16

signal server_created
signal join_succeeded
signal join_failed(reason: String)
signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)
signal server_disconnected
signal session_ended

var players: Dictionary = {}

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func host_local() -> void:
	var peer := OfflineMultiplayerPeer.new()
	multiplayer.multiplayer_peer = peer
	players[1] = { "id": 1 }
	server_created.emit.call_deferred()

func host(port: int = DEFAULT_PORT) -> void:
	var peer := ENetMultiplayerPeer.new()
	var err   := peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		push_error("NetworkManager: failed to create server: " + str(err))
		return
	multiplayer.multiplayer_peer = peer
	players[1] = { "id": 1 }
	server_created.emit.call_deferred()

func join(ip: String, port: int = DEFAULT_PORT) -> void:
	var peer := ENetMultiplayerPeer.new()
	var err   := peer.create_client(ip, port)
	if err != OK:
		join_failed.emit("Failed to create client: " + str(err))
		return
	multiplayer.multiplayer_peer = peer

func disconnect_from_game() -> void:
	## Emit first so listeners can clean up while peer is still valid
	session_ended.emit()
	## Null synchronously — no await
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
