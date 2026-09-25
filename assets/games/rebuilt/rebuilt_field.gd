extends Node3D

@onready var scoring := GameManager.current_scoring as RebuiltScoring

@onready var redArea = $RedScoring
@onready var redHubExit = $RedHubExit
@onready var blueArea = $BlueScoring
@onready var blueHubExit = $BlueHubExit

var fuel_pieces: Array[RigidBody3D] = []
var fuel_start_transforms: Array[Transform3D] = []

func _ready() -> void:
	if scoring:
		redArea.body_entered.connect(_score_red)
		blueArea.body_entered.connect(_score_blue)

	for child in get_children():
		if child is RigidBody3D and child.is_in_group("game_piece"):
			_setup_fuel(child)

func _setup_fuel(fuel: RigidBody3D) -> void:
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var config := SceneReplicationConfig.new()
	config.add_property(NodePath(":position"))
	config.add_property(NodePath(":rotation"))
	sync.replication_config = config
	fuel.add_child(sync)

	fuel.set_multiplayer_authority(1, true)

	if not multiplayer.is_server():
		fuel.freeze = true

	fuel_pieces.append(fuel)
	fuel_start_transforms.append(fuel.global_transform)

func reset_field() -> void:
	if not multiplayer.is_server():
		return

	for i in fuel_pieces.size():
		var fuel := fuel_pieces[i]
		fuel.global_transform = fuel_start_transforms[i]
		fuel.linear_velocity = Vector3.ZERO
		fuel.angular_velocity = Vector3.ZERO

func _score_red(body: Node) -> void:
	if body is RigidBody3D and body.is_in_group("game_piece"):
		scoring.score_fuel("red")

		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		var physics_state = PhysicsServer3D.body_get_direct_state(body.get_rid())
		if physics_state:
			physics_state.transform = redHubExit.global_transform

func _score_blue(body: Node) -> void:
	if body is RigidBody3D and body.is_in_group("game_piece"):
		scoring.score_fuel("blue")

		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		var physics_state = PhysicsServer3D.body_get_direct_state(body.get_rid())
		if physics_state:
			physics_state.transform = blueHubExit.global_transform
