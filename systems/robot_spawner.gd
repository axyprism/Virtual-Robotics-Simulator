class_name RobotSpawner
extends Node

const ROBOTS_FOLDER := "res://robots/scenes/"

@export var spawn_root_path: NodePath
@onready var _spawn_root: Node               = get_node(spawn_root_path)
@onready var _spawner:    MultiplayerSpawner = $MultiplayerSpawner

@export var registered_scenes: Array[PackedScene] = []

var _scenes: Dictionary = {}

signal robot_spawned(robot: Node, owner_id: int)

func _enter_tree() -> void:
	$MultiplayerSpawner.spawn_function = _do_spawn

func _ready() -> void:
	_build_scene_registry()
	NetworkManager.session_ended.connect(_on_session_ended)
	NetworkManager.player_disconnected.connect(_on_player_disconnected)

func _build_scene_registry() -> void:
	_scenes.clear()
	for packed_scene in registered_scenes:
		if packed_scene == null:
			continue
		var scene_name := packed_scene.resource_path.get_file().get_basename()
		_scenes[scene_name] = packed_scene.resource_path
		## Register with spawner so it knows about this scene on all peers
		_spawner.add_spawnable_scene(packed_scene.resource_path)

func get_robot_names() -> Array[String]:
	var names: Array[String] = []
	for key in _scenes.keys():
		names.append(key)
	return names

func request_spawn(scene_name: String) -> void:
	if not NetworkManager.is_connected_to_game():
		push_warning("RobotSpawner: not connected")
		return
	if not _scenes.has(scene_name):
		push_error("RobotSpawner: unknown scene " + scene_name)
		return
	if multiplayer.is_server():
		_rpc_request_spawn(scene_name, multiplayer.get_unique_id())
	else:
		_rpc_request_spawn.rpc_id(1, scene_name, multiplayer.get_unique_id())

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_spawn(scene_name: String, requester_id: int) -> void:
	if not multiplayer.is_server():
		return
	if _spawn_root.has_node("Robot_" + str(requester_id)):
		push_warning("RobotSpawner: Robot_%d already exists" % requester_id)
		return
	## spawn() returns the node on the server — emit directly here
	## _do_spawn handles client-side emit via call_deferred
	var robot := _spawner.spawn({
		"path":     _scenes[scene_name],
		"owner_id": requester_id,
	})
	if robot:
		robot_spawned.emit(robot, requester_id)

func _do_spawn(data: Dictionary) -> Node:
	var scene := load(data["path"]) as PackedScene
	if not scene:
		push_error("RobotSpawner: failed to load " + data["path"])
		return Node.new()
	var robot  := scene.instantiate()
	var id     := int(data["owner_id"])
	robot.name  = "Robot_" + str(id)
	robot.set_multiplayer_authority(id)
	## Only emit on clients — server emits directly in _rpc_request_spawn
	## after spawn() returns, where the node is guaranteed to be in the tree
	if not multiplayer.is_server():
		robot_spawned.emit.call_deferred(robot, id)
	return robot

func _on_session_ended() -> void:
	for child in _spawn_root.get_children():
		_spawn_root.remove_child(child)
		child.queue_free()

func _on_player_disconnected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	var node := _spawn_root.get_node_or_null("Robot_" + str(peer_id))
	if node:
		_spawn_root.remove_child(node)
		node.queue_free()
