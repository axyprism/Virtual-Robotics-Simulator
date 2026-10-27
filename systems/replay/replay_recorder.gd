extends Node

var recording: ReplayData
var is_recording: bool = false
var time: float = 0.0

var _entity_nodes: Dictionary = {}

func start_recording() -> void:
	recording = ReplayData.new()
	recording.frame_dt = get_physics_process_delta_time()
	time = 0.0
	is_recording = true
	_register_entities()

func stop_recording() -> ReplayData:
	is_recording = false
	return recording

func _register_entities() -> void:
	recording.entities.clear()
	_entity_nodes.clear()
	for node in get_tree().get_nodes_in_group("recordable"):
		var parts: Array = []
		if node.has_method("get_subsystem_manager"):
			var manager: Node = node.get_subsystem_manager()
			if manager:
				var chassis: Node3D = manager.get_chassis_body()
				if chassis:
					parts.append(str(node.get_path_to(chassis)))
				for subsystem in manager.get_all():
					for sync_node in subsystem.get_sync_nodes():
						var part_path := str(node.get_path_to(sync_node))
						if not parts.has(part_path):
							parts.append(part_path)
		recording.entities[node.name] = {
			"scene_path": node.scene_file_path,
			"parts": parts
		}
		_entity_nodes[node.name] = node
	for node in get_tree().get_nodes_in_group("game_piece"):
		if not recording.entities.has(node.name):
			recording.entities[node.name] = {
				"scene_path": "",
				"parts": []
			}
			_entity_nodes[node.name] = node

func _physics_process(delta: float) -> void:
	if not is_recording:
		return
	_capture_frame()
	time += delta

func _capture_frame() -> void:
	var frame: Dictionary = {}
	for id in _entity_nodes.keys():
		var node: Node3D = _entity_nodes[id]
		if not is_instance_valid(node):
			continue
		var parts_data: Dictionary = {}
		for part_path in recording.entities[id]["parts"]:
			var part := node.get_node_or_null(part_path) as Node3D
			if part:
				parts_data[part_path] = {
					"pos": part.position,
					"rot": part.rotation
				}
		frame[id] = {
			"pos": node.global_position,
			"rot": node.global_rotation,
			"parts": parts_data
		}
	recording.frames.append(frame)

func save_recording(path: String) -> void:
	ResourceSaver.save(recording, path)

func load_recording(path: String) -> ReplayData:
	return load(path) as ReplayData
