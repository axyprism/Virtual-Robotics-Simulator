extends Node3D

@onready var robot_spawner:  RobotSpawner  = $RobotSpawner
@onready var player_spawner: PlayerSpawner = $PlayerSpawner

@onready var field_container = $FieldContainer
@onready var ui_container = $UIContainer

func _ready() -> void:
	GameManager.load_current_game(field_container, ui_container)
	
	robot_spawner.robot_spawned.connect(_on_robot_spawned)
	player_spawner.player_spawned.connect(_on_player_spawned)

	if NetworkManager.is_connected_to_game():
		if NetworkManager.is_host():
			player_spawner.spawn_local_player()
		else:
			player_spawner.request_spawn_for_client()

func _on_robot_spawned(robot: Node, owner_id: int) -> void:
	if owner_id != multiplayer.get_unique_id():
		return
	var base_robot := robot as BaseRobot
	if not base_robot:
		push_error("Spawned robot does not extend BaseRobot: " + robot.name)
		return
	ControlManager.set_active_robot(base_robot)

func _on_player_spawned(player: Node, owner_id: int) -> void:
	if owner_id != multiplayer.get_unique_id():
		return
	ControlManager.register_player(player)
