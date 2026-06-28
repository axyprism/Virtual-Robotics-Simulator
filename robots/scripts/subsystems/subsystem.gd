class_name Subsystem
extends Node

## Human-readable name for debugging / UI
@export var subsystem_name: StringName = ""

var _manager: SubsystemManager = null
var _child_subsystems: Array[Subsystem] = []
var _active: bool = true

## Called by SubsystemManager on registration
func _setup(manager: SubsystemManager) -> void:
	_manager = manager
	# Auto-register any Subsystem children so nesting is transparent
	for child in get_children():
		if child is Subsystem:
			_child_subsystems.append(child)
			child._setup(manager)

## Override in subclasses — called every physics tick when active
@warning_ignore("unused_parameter")
func update(delta: float) -> void:
	pass

## Override to define what "idle" looks like (called when no command runs this subsystem)
@warning_ignore("unused_parameter")
func run_default(delta: float) -> void:
	pass

func set_active(value: bool) -> void:
	_active = value
	for child in _child_subsystems:
		child.set_active(value)

func get_manager() -> SubsystemManager:
	return _manager

## Walk up to find the robot node this subsystem belongs to
func get_robot() -> Node:
	return _manager.get_parent() if _manager else null

## Internal — called by manager each tick
func _tick(delta: float) -> void:
	if not _active:
		return
	update(delta)
	# Children tick themselves through the manager's flat list, not recursively here
