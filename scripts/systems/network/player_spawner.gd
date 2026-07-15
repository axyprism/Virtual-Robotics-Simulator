class_name PlayerSpawner
extends Node

const PLAYER_SCENE := "res://player/player.tscn"
const PLAYER_SCENE_VR := "res://player/vr_player.tscn"

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

func request_spawn_for_client() -> void:
	_rpc_request_spawn.rpc_id(1, multiplayer.get_unique_id(), VRManager.is_vr)

func _enter_tree() -> void:
	$MultiplayerSpawner.spawn_function = _do_spawn

func _ready() -> void:
	$MultiplayerSpawner.add_spawnable_scene(PLAYER_SCENE)
	$MultiplayerSpawner.add_spawnable_scene(PLAYER_SCENE_VR)
	NetworkManager.server_created.connect(_on_server_created)
	NetworkManager.join_succeeded.connect(_on_join_succeeded)
	NetworkManager.player_disconnected.connect(_on_player_disconnected)
	NetworkManager.session_ended.connect(_on_session_ended)

func _on_server_created() -> void:
	_spawn_index = 0
	if get_tree().current_scene.name != "MainMenu":
		spawn_local_player()

func spawn_local_player() -> void:
	_server_spawn_player(multiplayer.get_unique_id())
	
func _on_join_succeeded() -> void:
	if get_tree().current_scene.name != "MainMenu":
		_rpc_request_spawn.rpc_id(1, multiplayer.get_unique_id(), VRManager.is_vr)

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
func _rpc_request_spawn(peer_id: int, is_vr: bool) -> void:
	if not multiplayer.is_server():
		return
	_server_spawn_player(peer_id, is_vr)

func _server_spawn_player(peer_id: int, is_vr: bool = false) -> void:
	if _spawn_root.has_node("Player_" + str(peer_id)):
		return
	_spawner.spawn({
		"owner_id":    peer_id,
		"spawn_index": _spawn_index,
		"is_vr":       is_vr,
	})
	_spawn_index += 1

func _do_spawn(data: Dictionary) -> Node:
	var scene_path := PLAYER_SCENE_VR if data.get("is_vr", false) else PLAYER_SCENE
	var scene      := load(scene_path) as PackedScene
	var player     := scene.instantiate()
	var id         := int(data["owner_id"])
	var index      := int(data["spawn_index"]) % spawn_positions.size()
	player.name     = "Player_" + str(id)
	player.position  = spawn_positions[index]
	player_spawned.emit.call_deferred(player, id)
	return player
