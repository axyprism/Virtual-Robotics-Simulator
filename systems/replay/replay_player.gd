extends Node
class_name ReplayPlayer

signal load_progress(ratio: float)
signal load_finished(success: bool)

var _spawned: Array[Node] = []
var _loading: bool = false
var recording: ReplayData
var playback_time: float = 0.0
var speed: float = 1.0
var playing: bool = false

var _instances: Dictionary = {}

func is_loading() -> bool:
	return _loading

func _clear_instances() -> void:
	for node in _spawned:
		if is_instance_valid(node):
			node.queue_free()
	_spawned.clear()
	_instances.clear()

func load_recording(data: ReplayData, root: Node) -> void:
	_clear_instances()
	recording = data
	playback_time = 0.0
	for id in data.entities.keys():
		_spawn_entity(id, data.entities[id], root)
	load_finished.emit(true)

func load_recording_async(path: String, root: Node) -> void:
	if _loading:
		return
	_loading = true
	playing = false
	load_progress.emit(0.0)
	var loaded: Resource = await _load_threaded(path)
	var data := loaded as ReplayData
	if data == null:
		_loading = false
		load_finished.emit(false)
		return
	load_progress.emit(0.6)
	var scene_paths: Array[String] = []
	for entry in data.entities.values():
		if entry["scene_path"] != "" and not scene_paths.has(entry["scene_path"]):
			scene_paths.append(entry["scene_path"])
	var keep: Array[Resource] = []
	for scene_path in scene_paths:
		var scene: Resource = await _load_threaded(scene_path)
		keep.append(scene)
	load_progress.emit(0.8)
	_clear_instances()
	recording = null
	var ids := data.entities.keys()
	for i in ids.size():
		_spawn_entity(ids[i], data.entities[ids[i]], root)
		load_progress.emit(0.8 + 0.2 * float(i + 1) / ids.size())
		await get_tree().process_frame
	recording = data
	playback_time = 0.0
	_loading = false
	load_finished.emit(true)

func _load_threaded(path: String) -> Resource:
	if ResourceLoader.load_threaded_request(path) != OK:
		return null
	while true:
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await get_tree().process_frame
		elif status == ResourceLoader.THREAD_LOAD_LOADED:
			return ResourceLoader.load_threaded_get(path)
		else:
			return null
	return null

func _spawn_entity(id, entry: Dictionary, root: Node) -> void:
	if entry["scene_path"] == "":
		var existing := root.find_child(id, true, false) as Node3D
		if existing:
			_disable_gameplay(existing)
			_instances[id] = existing
		return
	var scene := load(entry["scene_path"]) as PackedScene
	if scene == null:
		return
	var instance := scene.instantiate() as Node3D
	instance.name = id
	root.add_child(instance)
	_disable_gameplay(instance)
	_instances[id] = instance
	_spawned.append(instance)

func _disable_gameplay(instance: Node3D) -> void:
	instance.set_physics_process(false)
	instance.set_process(false)
	if instance is RigidBody3D:
		instance.freeze = true
	for child in instance.find_children("*", "", true, false):
		child.set_physics_process(false)
		child.set_process(false)
		if child is RigidBody3D:
			child.freeze = true

func set_category_visible(group_name: String, is_visible: bool) -> void:
	for id in _instances.keys():
		var instance: Node3D = _instances[id]
		if instance.is_in_group(group_name):
			instance.visible = is_visible

func _process(delta: float) -> void:
	if not playing or recording == null:
		return
	playback_time += delta * speed
	apply_frame(playback_time)

func apply_frame(t: float) -> void:
	if recording.frames.is_empty():
		return
	var frame_index: float = t / recording.frame_dt
	var index_a: int = clampi(int(floor(frame_index)), 0, recording.frames.size() - 1)
	var index_b: int = clampi(index_a + 1, 0, recording.frames.size() - 1)
	var alpha: float = frame_index - index_a
	var frame_a: Dictionary = recording.frames[index_a]
	var frame_b: Dictionary = recording.frames[index_b]
	for id in _instances.keys():
		if not frame_a.has(id) or not frame_b.has(id):
			continue
		var instance: Node3D = _instances[id]
		var a: Dictionary = frame_a[id]
		var b: Dictionary = frame_b[id]
		instance.global_position = a["pos"].lerp(b["pos"], alpha)
		instance.global_rotation = _lerp_angle_vec3(a["rot"], b["rot"], alpha)
		for part_path in a["parts"].keys():
			var part := instance.get_node_or_null(part_path) as Node3D
			if part == null or not b["parts"].has(part_path):
				continue
			var pa: Dictionary = a["parts"][part_path]
			var pb: Dictionary = b["parts"][part_path]
			part.position = pa["pos"].lerp(pb["pos"], alpha)
			part.rotation = _lerp_angle_vec3(pa["rot"], pb["rot"], alpha)

func _lerp_angle_vec3(from: Vector3, to: Vector3, weight: float) -> Vector3:
	return Vector3(
		lerp_angle(from.x, to.x, weight),
		lerp_angle(from.y, to.y, weight),
		lerp_angle(from.z, to.z, weight)
	)
