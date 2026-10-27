class_name ScriptRunner
extends Node

@export var robot_script: RobotScript

var running: Dictionary = {}


func _unhandled_input(event: InputEvent) -> void:
	if robot_script == null or not owns_robot():
		return
	for binding in robot_script.bindings:
		if not InputMap.has_action(binding.action):
			continue
		if event.is_action_pressed(binding.action):
			start(binding)
		elif event.is_action_released(binding.action) and binding.mode == ScriptBinding.Mode.HELD:
			stop(binding)


func owns_robot() -> bool:
	var robot := get_parent()
	if robot != null and robot.has_method("is_owned_by_local_peer"):
		return robot.call("is_owned_by_local_peer")
	return true


func start(binding: ScriptBinding) -> void:
	var manager := get_parent().get_node_or_null("SubsystemManager") as SubsystemManager
	if manager == null or binding.command == null:
		return
	stop(binding)
	var command := CommandFactory.build(binding.command, manager)
	if command == null:
		return
	if binding.mode == ScriptBinding.Mode.HELD:
		running[binding] = command
	CommandScheduler.schedule(command)


func stop(binding: ScriptBinding) -> void:
	if running.has(binding):
		CommandScheduler.cancel(running[binding])
		running.erase(binding)
