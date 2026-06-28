class_name BaseRobot
extends RigidBody3D

## Override this in your robot script to handle gaining/losing control
func set_controlled(value: bool) -> void:
	pass

## Override to return your robot's display name in UI
func get_robot_name() -> String:
	return name

## Returns the SubsystemManager if this robot has one — optional
func get_subsystem_manager() -> SubsystemManager:
	return get_node_or_null("SubsystemManager") as SubsystemManager
