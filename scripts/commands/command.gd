class_name Command
extends RefCounted

var required: Array[Subsystem] = []

var robot: Node = null

func on_start() -> void:
	pass

func on_update(_delta: float) -> void:
	pass

func on_end(_interrupted: bool) -> void:
	pass

func is_finished() -> bool:
	return true

func require(subsystem: Subsystem) -> Command:
	required.append(subsystem)
	return self
