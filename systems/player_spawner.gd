class_name PlayerSpawner
extends Node

const PLAYER_SCENE := "res://player/player.tscn"

@export var spawn_root_path: NodePath
@onready var _spawn_root: Node               = get_node(spawn_root_path)
@onready var _spawner:    MultiplayerSpawner = $MultiplayerSpawner

@export var spawn_positions: Array[Vector3] = [
	Vector3(0, 1, 0),
	Vector3(3, 1, 0),
	Vector3(-3, 1, 0),
	Vector3(0, 1, 3),
]

signal player_spawned(player: Node, owner_id: int)

var _spawn_index: int = 0

func _enter_tree() -> void:
	$MultiplayerSpawner.spawn_function = _do_spawn

func _ready() -> void:
	$MultiplayerSpawner.add_spawnable_scene(PLAYER_SCENE)
	NetworkManager.server_created.connect(_on_server_created)
	NetworkManager.join_succeeded.connect(_on_join_succeeded)
	NetworkManager.player_disconnected.connect(_on_player_disconnected)
	NetworkManager.session_ended.connect(_on_session_ended)

func _on_server_created() -> void:
	_spawn_index = 0
	_server_spawn_player(1)

func _on_join_succeeded() -> void:
	_rpc_request_spawn.rpc_id(1, multiplayer.get_unique_id())

func _on_player_disconnected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	var node := _spawn_root.get_node_or_null("Player_" + str(peer_id))
	if node:
		_spawn_root.remove_child(node)
		node.queue_free()

func _on_session_ended() -> void:
	_spawn_index = 0
	for child in _spawn_root.get_children():
		_spawn_root.remove_child(child)
		child.queue_free()

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_spawn(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	_server_spawn_player(peer_id)

func _server_spawn_player(peer_id: int) -> void:
	if _spawn_root.has_node("Player_" + str(peer_id)):
		return
	var player := _spawner.spawn({
		"owner_id":    peer_id,
		"spawn_index": _spawn_index,
	})
	_spawn_index += 1
	## Emit directly on server
	if player:
		player_spawned.emit(player, peer_id)

func _do_spawn(data: Dictionary) -> Node:
	var scene   := load(PLAYER_SCENE) as PackedScene
	var player  := scene.instantiate()
	var id      := int(data["owner_id"])
	var index   := int(data["spawn_index"]) % spawn_positions.size()
	player.name      = "Player_" + str(id)
	player.position   = spawn_positions[index]
	player.set_multiplayer_authority(id)
	## Only emit on clients
	if not multiplayer.is_server():
		player_spawned.emit.call_deferred(player, id)
	return player
