class_name FeederSubsystem
extends Subsystem

@export var feeder_visual_path: NodePath
@export var contact_zones: Array[Area3D] = []
@onready var feeder_visual: Node3D = get_node(feeder_visual_path)

@export var feed_speed: float = 1.0
@export var feed_force: float = 10.0
@export var reverse_speed: float = -0.5
@export var visual_spin_rate: float = 15.0

var has_game_piece: bool = false

var _current_speed: float = 0.0
var _target_speed: float = 0.0
var _visual_spin: float = 0.0

signal game_piece_detected
signal game_piece_fired

func _ready() -> void:
	for i in contact_zones:
		i.body_entered.connect(_on_game_piece_contact)
	
func _on_game_piece_contact(body: Node) -> void:
	if not body.is_in_group("game_piece"):
		return
	var rb := body as RigidBody3D
	if not rb:
		return
	_on_game_piece_entered(body)
	var direction = self.global_transform.basis.z
	rb.apply_central_impulse(direction * feed_force * _current_speed)

func feed() -> void:
	_target_speed = feed_speed

func reverse() -> void:
	_target_speed = reverse_speed

func stop() -> void:
	_target_speed = 0.0

func is_feeding() -> bool:
	return _current_speed > 0.1

func _on_game_piece_entered(_body: Node) -> void:
	has_game_piece = true
	game_piece_detected.emit()

func _on_game_piece_exited(_body: Node) -> void:
	has_game_piece = false
	game_piece_fired.emit()

func update(delta: float) -> void:
	_current_speed = move_toward(_current_speed, _target_speed, delta * 8.0)

	if feeder_visual:
		_visual_spin += _current_speed * visual_spin_rate * delta
		feeder_visual.rotation.x = _visual_spin

func run_default(delta: float) -> void:
	stop()
	update(delta)
