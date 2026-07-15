extends Node

enum Target { PLAYER, ROBOT }

var current: Target = Target.PLAYER
var _player:       Node      = null
var _active_robot: BaseRobot = null

signal target_changed(new_target: Target)

func register_player(node: Node) -> void:
	_player = node

func set_active_robot(robot: BaseRobot) -> void:
	_active_robot = robot

func get_active_robot() -> BaseRobot:
	return _active_robot

func switch_to(target: Target, robot: BaseRobot = null) -> void:
	if target == Target.ROBOT:
		if robot == null:
			push_warning("ControlManager: switch_to ROBOT called with no robot")
			return
		if not robot.is_multiplayer_authority():
			push_warning("ControlManager: cannot control a robot owned by another player")
			return
		_active_robot = robot
	current = target
	if _player:
		var player_node := _player as Player
		if player_node:
			player_node.set_controlled(current == Target.PLAYER)
		else:
			push_error("ControlManager: registered player is not a Player node")
	if _active_robot:
		_active_robot.set_controlled(current == Target.ROBOT)
	target_changed.emit(current)

func toggle() -> void:
	if current == Target.PLAYER:
		if _active_robot == null:
			return
		switch_to(Target.ROBOT, _active_robot)
	else:
		switch_to(Target.PLAYER)
