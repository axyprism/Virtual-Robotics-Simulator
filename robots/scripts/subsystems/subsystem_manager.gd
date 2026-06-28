class_name SubsystemManager
extends Node

## Flat list of ALL subsystems (including nested ones) for the scheduler to query
var _all_subsystems: Array[Subsystem] = []

func _ready() -> void:
	# Discover top-level Subsystem children; they recurse into their own children
	for child in get_children():
		if child is Subsystem:
			_register_tree(child)

	# Register with the global scheduler so it knows this robot exists
	CommandScheduler.register_manager(self)

func _register_tree(subsystem: Subsystem) -> void:
	_all_subsystems.append(subsystem)
	subsystem._setup(self)
	for child in subsystem.get_children():
		if child is Subsystem:
			_register_tree(child)

func get_subsystem(subsystem_class: Script) -> Subsystem:
	for s in _all_subsystems:
		if s.get_script() == subsystem_class:
			return s
	return null

func get_all() -> Array[Subsystem]:
	return _all_subsystems

## Called by CommandScheduler each tick
func tick(delta: float) -> void:
	## Only process subsystems on the peer that owns this robot
	if not get_parent().is_multiplayer_authority():
		return
	for s in _all_subsystems:
		s._tick(delta)
