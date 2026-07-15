class_name BaseRobot
extends RigidBody3D

func set_controlled(value: bool) -> void:
	pass

func get_robot_name() -> String:
	return name

func get_subsystem_manager() -> SubsystemManager:
	return get_node_or_null("SubsystemManager") as SubsystemManager
