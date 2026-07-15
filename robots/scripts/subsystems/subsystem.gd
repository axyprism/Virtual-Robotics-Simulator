class_name Subsystem
extends Node

@export var subsystem_name: StringName = ""
@export var subsystem_id: StringName = ""

var _manager: SubsystemManager = null
var _child_subsystems: Array[Subsystem] = []
var _active: bool = true

func _setup(manager: SubsystemManager) -> void:
	_manager = manager
	for child in get_children():
		if child is Subsystem:
			_child_subsystems.append(child)
			child._setup(manager)

func update(delta: float) -> void:
	pass

func run_default(delta: float) -> void:
	pass

func set_active(value: bool) -> void:
	_active = value
	for child in _child_subsystems:
		child.set_active(value)

func get_manager() -> SubsystemManager:
	return _manager

func get_robot() -> Node:
	return _manager.get_parent() if _manager else null
	
func get_sync_nodes() -> Array[Node3D]:
	return []

func _tick(delta: float) -> void:
	if not _active:
		return
	update(delta)
