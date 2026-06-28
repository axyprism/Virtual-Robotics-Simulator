class_name FeederSubsystem
extends Subsystem

## Visual node for the feeder belt/roller
@export var feeder_visual_path: NodePath
@onready var feeder_visual: Node3D = get_node(feeder_visual_path)

## Feeder speed (normalized, can be negative to reverse/unjam)
@export var feed_speed: float = 1.0
@export var reverse_speed: float = -0.5
@export var visual_spin_rate: float = 15.0

## If true, a game piece is staged and ready to feed
## Hook this up to a sensor/Area3D in your scene
var has_game_piece: bool = false

var _current_speed: float = 0.0
var _target_speed: float = 0.0
var _visual_spin: float = 0.0

## Emitted when a game piece enters the feeder sensor
signal game_piece_detected
## Emitted when a game piece leaves (was fired)
signal game_piece_fired

# --- Public API ---

func feed() -> void:
	_target_speed = feed_speed

func reverse() -> void:
	_target_speed = reverse_speed

func stop() -> void:
	_target_speed = 0.0

func is_feeding() -> bool:
	return _current_speed > 0.1

# --- Sensor hookup (call from an Area3D signal in the scene) ---

func _on_game_piece_entered(_body: Node) -> void:
	has_game_piece = true
	game_piece_detected.emit()

func _on_game_piece_exited(_body: Node) -> void:
	has_game_piece = false
	game_piece_fired.emit()

# --- Internal ---

func update(delta: float) -> void:
	_current_speed = move_toward(_current_speed, _target_speed, delta * 8.0)

	if feeder_visual:
		_visual_spin += _current_speed * visual_spin_rate * delta
		feeder_visual.rotation.x = _visual_spin

func run_default(delta: float) -> void:
	stop()
	update(delta)
