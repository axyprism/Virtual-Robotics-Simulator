class_name ElevatorSubsystem
extends Subsystem

@export var carriage_path: NodePath
@onready var carriage: Node3D = get_node(carriage_path)

@export var travel_axis: Vector3 = Vector3.UP

@export var min_height: float = 0.0
@export var max_height: float = 2.0

@export var max_speed: float = 1.5

@export var tolerance: float = 0.02

@export var hold_on_idle: bool = true

@export var soft_limit_zone: float = 0.1

enum ElevatorState {
	IDLE,
	MOVING_TO_TARGET,
	HOLDING,
	MANUAL,
}

var state: ElevatorState = ElevatorState.IDLE

var _target_height:  float = 0.0
var _current_height: float = 0.0
var _hold_height:    float = 0.0

signal arrived_at_target
signal soft_limit_reached(at_min: bool)

func set_height(height: float) -> void:
	_target_height = clampf(height, min_height, max_height)
	_set_state(ElevatorState.MOVING_TO_TARGET)

func move_by(delta_height: float) -> void:
	set_height(_current_height + delta_height)

func drive_manual(speed: float) -> void:
	_set_state(ElevatorState.MANUAL)
	_manual_speed = speed

func hold_current() -> void:
	_hold_height = _current_height
	_target_height = _current_height
	_set_state(ElevatorState.HOLDING)

func at_target() -> bool:
	return absf(_current_height - _target_height) < tolerance

func at_bottom() -> bool:
	return _current_height <= min_height + tolerance

func at_top() -> bool:
	return _current_height >= max_height - tolerance

func get_height_fraction() -> float:
	return clampf(
		(_current_height - min_height) / (max_height - min_height),
		0.0, 1.0
	)

func get_height() -> float:
	return _current_height

func get_sync_nodes() -> Array[Node3D]:
	var nodes: Array[Node3D] = []
	if carriage != null:
		nodes.append(carriage)
	return nodes

var _manual_speed: float = 0.0

func _ready() -> void:
	if carriage:
		_current_height = _get_carriage_height()
	_hold_height   = _current_height
	_target_height = _current_height

func update(delta: float) -> void:
	if not carriage:
		return

	match state:
		ElevatorState.MOVING_TO_TARGET:
			_move_toward_target(delta)
			if at_target():
				_set_state(ElevatorState.HOLDING)
				arrived_at_target.emit()

		ElevatorState.HOLDING:
			_current_height = lerpf(_current_height, _hold_height, delta * 20.0)

		ElevatorState.MANUAL:
			_apply_manual(delta)

		ElevatorState.IDLE:
			if not hold_on_idle:
				_target_height = min_height
				_move_toward_target(delta)

	_apply_carriage_position()

func run_default(_delta: float) -> void:
	if hold_on_idle:
		hold_current()
	else:
		set_height(min_height)

func _move_toward_target(delta: float) -> void:
	var distance  := _target_height - _current_height
	var direction := signf(distance)
	var speed     := max_speed

	var dist_from_min := _current_height - min_height
	var dist_from_max := max_height - _current_height
	if dist_from_min < soft_limit_zone and direction < 0:
		speed *= (dist_from_min / soft_limit_zone)
		if dist_from_min <= tolerance:
			soft_limit_reached.emit(true)
	if dist_from_max < soft_limit_zone and direction > 0:
		speed *= (dist_from_max / soft_limit_zone)
		if dist_from_max <= tolerance:
			soft_limit_reached.emit(false)

	var step := minf(absf(distance), speed * delta)
	_current_height = clampf(_current_height + direction * step, min_height, max_height)

func _apply_manual(delta: float) -> void:
	var speed     := _manual_speed * max_speed
	var new_height := _current_height + speed * delta

	if new_height < min_height + soft_limit_zone and speed < 0:
		var t     := (new_height - min_height) / soft_limit_zone
		new_height = _current_height + speed * delta * maxf(t, 0.0)

	if new_height > max_height - soft_limit_zone and speed > 0:
		var t     := (max_height - new_height) / soft_limit_zone
		new_height = _current_height + speed * delta * maxf(t, 0.0)

	_current_height = clampf(new_height, min_height, max_height)
	_hold_height    = _current_height

func _apply_carriage_position() -> void:
	carriage.position = travel_axis * _current_height

func _get_carriage_height() -> float:
	return carriage.position.dot(travel_axis)

func _set_state(new_state: ElevatorState) -> void:
	if state != new_state:
		state = new_state
