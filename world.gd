extends Node3D

@onready var robot_spawner:  RobotSpawner  = $RobotSpawner
@onready var player_spawner: PlayerSpawner = $PlayerSpawner

func _ready() -> void:
	robot_spawner.robot_spawned.connect(_on_robot_spawned)
	player_spawner.player_spawned.connect(_on_player_spawned)
	NetworkManager.host_local()

func _on_robot_spawned(robot: Node, owner_id: int) -> void:
	print("robot_spawned received, owner_id: ", owner_id, " my_id: ", multiplayer.get_unique_id())
	if owner_id != multiplayer.get_unique_id():
		return
	var base_robot := robot as BaseRobot
	if not base_robot:
		print("cast to BaseRobot failed")
		return
	print("set_active_robot called")
	ControlManager.set_active_robot(base_robot)

func _on_player_spawned(player: Node, owner_id: int) -> void:
	if owner_id != multiplayer.get_unique_id():
		return
	ControlManager.register_player(player)
