class_name ReplayCamera
extends Node

signal keyframes_changed

var keyframes: Array[Dictionary] = []

func add_keyframe(time: float, pos: Vector3, rot: Vector3, fov: float) -> int:
	var kf := {"time": time, "pos": pos, "rot": rot, "fov": fov}
	var existing := find_at(time)
	if existing != -1:
		kf["time"] = keyframes[existing]["time"]
		keyframes[existing] = kf
		keyframes_changed.emit()
		return existing
	keyframes.append(kf)
	keyframes.sort_custom(func(a, b): return a["time"] < b["time"])
	keyframes_changed.emit()
	return keyframes.find(kf)

func update_keyframe(index: int, pos: Vector3, rot: Vector3, fov: float) -> void:
	keyframes[index]["pos"] = pos
	keyframes[index]["rot"] = rot
	keyframes[index]["fov"] = fov

func remove_keyframe(index: int) -> void:
	keyframes.remove_at(index)
	keyframes_changed.emit()

func clear() -> void:
	keyframes.clear()
	keyframes_changed.emit()

func find_at(time: float, tolerance: float = 0.01) -> int:
	for i in keyframes.size():
		if absf(keyframes[i]["time"] - time) <= tolerance:
			return i
	return -1

func get_times() -> Array[float]:
	var result: Array[float] = []
	for kf in keyframes:
		result.append(kf["time"])
	return result

func sample(t: float) -> Dictionary:
	if keyframes.is_empty():
		return {}
	if keyframes.size() == 1 or t <= keyframes[0]["time"]:
		return keyframes[0]
	if t >= keyframes[-1]["time"]:
		return keyframes[-1]
	for i in keyframes.size() - 1:
		var a := keyframes[i]
		var b := keyframes[i + 1]
		if t <= b["time"]:
			var alpha: float = inverse_lerp(a["time"], b["time"], t)
			var qa := Quaternion.from_euler(a["rot"])
			var qb := Quaternion.from_euler(b["rot"])
			return {
				"pos": a["pos"].lerp(b["pos"], alpha),
				"rot": Basis(qa.slerp(qb, alpha)).get_euler(),
				"fov": lerpf(a["fov"], b["fov"], alpha)
			}
	return {}
