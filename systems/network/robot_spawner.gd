class_name RobotSpawner
extends Node

const ROBOTS_FOLDER := "res://robots/scenes/"

@export var spawn_root_path: NodePath
@onready var _spawn_root: Node = get_node(spawn_root_path)
@onready var _spawner: MultiplayerSpawner = $MultiplayerSpawner

@export var registered_scenes: Array[PackedScene] = []

var _scenes: Dictionary = {}

var _spawned_data: Dictionary = {}

signal robot_spawned(robot: Node, owner_id: int)
signal robot_despawned(owner_id: int)

func _enter_tree() -> void:
	$MultiplayerSpawner.spawn_function = _do_spawn

func _ready() -> void:
	_build_scene_registry()
	MatchManager.register_spawner(self)
	robot_spawned.connect(ControlManager._on_robot_spawned)
	robot_despawned.connect(ControlManager._on_robot_despawned)
	NetworkManager.session_ended.connect(_on_session_ended)
	NetworkManager.player_disconnected.connect(_on_player_disconnected)
	NetworkManager.player_connected.connect(_on_player_connected)

func _build_scene_registry() -> void:
	_scenes.clear()
	for packed_scene in registered_scenes:
		if packed_scene == null:
			continue
		var scene_name := packed_scene.resource_path.get_file().get_basename()
		_scenes[scene_name] = packed_scene.resource_path
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

func spawn_match_robots(assignments: Array) -> void:
	if not multiplayer.is_server():
		return
	reset_all()
	var red_positions := GameManager.current_game.red_spawn_positions.duplicate()
	red_positions.shuffle()
	var blue_positions := GameManager.current_game.blue_spawn_positions.duplicate()
	blue_positions.shuffle()
	for entry in assignments:
		var peer_id: int = entry["peer_id"]
		var scene_name: String = entry["scene_name"]
		var alliance: String = entry.get("alliance", "")
		var position := Vector3.ZERO
		if alliance == "red" and not red_positions.is_empty():
			position = red_positions.pop_back()
		elif alliance == "blue" and not blue_positions.is_empty():
			position = blue_positions.pop_back()
		_spawn_one(scene_name, peer_id, position)

func reset_all() -> void:
	for child in _spawn_root.get_children():
		_spawn_root.remove_child(child)
		child.queue_free()
	_spawned_data.clear()

func _on_player_connected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	for owner_id in _spawned_data:
		var entry: Dictionary = _spawned_data[owner_id]
		_replay_spawn.rpc_id(peer_id, entry["scene_name"], owner_id, entry["position"])

@rpc("authority", "call_remote", "reliable")
func _replay_spawn(scene_name: String, owner_id: int, position: Vector3) -> void:
	if _spawn_root.has_node("Robot_" + str(owner_id)):
		return
	var robot := _do_spawn({
		"path": _scenes[scene_name],
		"owner_id": owner_id,
		"position": position,
	})
	_spawn_root.add_child(robot)
	robot_spawned.emit(robot, owner_id)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_spawn(scene_name: String, requester_id: int) -> void:
	if not multiplayer.is_server():
		return
	_spawn_one(scene_name, requester_id, Vector3.ZERO)

func spawn_for_player(scene_name: String, peer_id: int) -> void:
	_spawn_one(scene_name, peer_id, Vector3.ZERO)

func _spawn_one(scene_name: String, peer_id: int, position: Vector3) -> void:
	if not multiplayer.is_server():
		return
	if not _scenes.has(scene_name):
		push_error("RobotSpawner: unknown scene " + scene_name)
		return
	if _spawn_root.has_node("Robot_" + str(peer_id)):
		push_warning("RobotSpawner: Robot_%d already exists" % peer_id)
		return
	var robot := _spawner.spawn({
		"path": _scenes[scene_name],
		"owner_id": peer_id,
		"position": position,
	})
	if robot:
		_spawned_data[peer_id] = { "scene_name": scene_name, "position": position }
		robot_spawned.emit(robot, peer_id)

func _do_spawn(data: Dictionary) -> Node:
	var scene := load(data["path"]) as PackedScene
	if not scene:
		push_error("RobotSpawner: failed to load " + data["path"])
		return Node.new()
	var robot := scene.instantiate()
	var id := int(data["owner_id"])
	robot.name = "Robot_" + str(id)
	robot.position = data.get("position", Vector3.ZERO)
	robot.set_multiplayer_authority(1)
	if robot.has_method("set_owner_peer_id"):
		robot.set_owner_peer_id(id)
	robot.tree_exiting.connect(func(): robot_despawned.emit(id))
	if not multiplayer.is_server():
		robot_spawned.emit.call_deferred(robot, id)
	return robot

func _on_session_ended() -> void:
	reset_all()

func _on_player_disconnected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	_spawned_data.erase(peer_id)
	var node := _spawn_root.get_node_or_null("Robot_" + str(peer_id))
	if node:
		_spawn_root.remove_child(node)
		node.queue_free()
