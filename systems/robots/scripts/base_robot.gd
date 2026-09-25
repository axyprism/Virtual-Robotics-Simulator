class_name BaseRobot
extends Node3D

func set_controlled(value: bool) -> void:
	pass

func is_owned_by_local_peer() -> bool:
	return false

func get_robot_name() -> String:
	return name

func get_subsystem_manager() -> SubsystemManager:
	return get_node_or_null("SubsystemManager") as SubsystemManager
