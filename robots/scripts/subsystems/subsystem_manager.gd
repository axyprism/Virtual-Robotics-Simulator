class_name SubsystemManager
extends Node

const SYNC_INTERVAL := 0.05

var _all_subsystems: Array[Subsystem] = []
var _sync_timer: float = 0.0

func _ready() -> void:
	for child in get_children():
		_register_tree(child)
	CommandScheduler.register_manager(self)

func _register_tree(node: Node) -> void:
	if node is Subsystem:
		_all_subsystems.append(node)
		node._setup(self)
	for child in node.get_children():
		_register_tree(child)

func get_subsystem(subsystem_class: Script) -> Subsystem:
	for s in _all_subsystems:
		if s.get_script() == subsystem_class:
			return s
	return null

func get_subsystems(subsystem_class: Script) -> Array[Subsystem]:
	var result: Array[Subsystem] = []
	for s in _all_subsystems:
		if s.get_script() == subsystem_class:
			result.append(s)
	return result

func get_subsystem_by_id(id: StringName) -> Subsystem:
	for s in _all_subsystems:
		if s.subsystem_id == id:
			return s
	return null

func get_all() -> Array[Subsystem]:
	return _all_subsystems

func tick(delta: float) -> void:
	if not get_parent().is_multiplayer_authority():
		return
	for s in _all_subsystems:
		s._tick(delta)
	_sync_timer += delta
	if _sync_timer >= SYNC_INTERVAL:
		_sync_timer = 0.0
		_broadcast_transforms()

func _broadcast_transforms() -> void:
	var data: Dictionary = {}
	for s in _all_subsystems:
		for node in s.get_sync_nodes():
			if node == null:
				continue
			var path := str(get_path_to(node))
			data[path] = { "p": node.position, "r": node.rotation }
	if not data.is_empty():
		_apply_transforms.rpc(data)

@rpc("authority", "call_remote", "unreliable_ordered")
func _apply_transforms(data: Dictionary) -> void:
	for path in data:
		var node := get_node_or_null(path) as Node3D
		if node:
			node.position = data[path]["p"]
			node.rotation = data[path]["r"]
