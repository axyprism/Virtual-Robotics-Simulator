class_name ArmSubsystem
extends Subsystem

@onready var _node3d: Node3D = get_node(".") as Node3D
@export var arm: Node3D
@export var rotation_axis: Vector3 = Vector3.RIGHT
@export var min_angle_deg: float = -90.0
@export var max_angle_deg: float =  90.0
@export var max_speed_deg: float = 120.0
@export var manual_speed_deg: float = 45.0
@export var tolerance_deg: float = 1.0
@export var soft_limit_zone_deg: float = 10.0
@export var hold_on_idle: bool = true
@export var broadcast_angle: bool = true

enum ArmState {
	IDLE,
	MOVING_TO_TARGET,
	HOLDING,
	MANUAL,
}

var state: ArmState = ArmState.IDLE

var _target_angle_deg: float = 0.0
var _current_angle_deg: float = 0.0
var _manual_speed: float = 0.0

var _chassis: RigidBody3D
var _shape_entries: Array[Dictionary] = []

signal arrived_at_target
signal angle_changed(angle_deg: float)

func set_angle(deg: float) -> void:
	_target_angle_deg = clampf(deg, min_angle_deg, max_angle_deg)
	_set_state(ArmState.MOVING_TO_TARGET)

func move_by(delta_deg: float) -> void:
	set_angle(_current_angle_deg + delta_deg)

func drive_manual(speed: float) -> void:
	_manual_speed = speed
	_set_state(ArmState.MANUAL)

func hold_current() -> void:
	_target_angle_deg = _current_angle_deg
	_set_state(ArmState.HOLDING)

func at_target() -> bool:
	return absf(_current_angle_deg - _target_angle_deg) < tolerance_deg

func at_min() -> bool:
	return _current_angle_deg <= min_angle_deg + tolerance_deg

func at_max() -> bool:
	return _current_angle_deg >= max_angle_deg - tolerance_deg

func get_angle() -> float:
	return _current_angle_deg

func get_angle_fraction() -> float:
	return clampf(
		(_current_angle_deg - min_angle_deg) / (max_angle_deg - min_angle_deg),
		0.0, 1.0
	)

func get_sync_nodes() -> Array[Node3D]:
	return [_node3d]

func _setup(manager: SubsystemManager) -> void:
	super._setup(manager)
	_chassis = manager.get_chassis_body()
	if _chassis:
		_shape_entries = _register_shapes_from_children(_chassis, arm)
	_current_angle_deg = rad_to_deg(_node3d.rotation.dot(rotation_axis))
	_target_angle_deg = _current_angle_deg

func update(delta: float) -> void:
	match state:
		ArmState.MOVING_TO_TARGET:
			_step_toward_target(delta)
			if at_target():
				_set_state(ArmState.HOLDING)
				arrived_at_target.emit()
		ArmState.MANUAL:
			_step_manual(delta)
		ArmState.IDLE:
			if not hold_on_idle:
				_target_angle_deg = min_angle_deg
				_step_toward_target(delta)
	_apply_rotation()
	if broadcast_angle:
		angle_changed.emit(_current_angle_deg)

func run_default(_delta: float) -> void:
	if hold_on_idle:
		hold_current()
	else:
		set_angle(min_angle_deg)

func _step_toward_target(delta: float) -> void:
	var speed_limit := max_speed_deg
	var dist_from_min := _current_angle_deg - min_angle_deg
	var dist_from_max := max_angle_deg - _current_angle_deg
	var going_down := _target_angle_deg < _current_angle_deg
	if dist_from_min < soft_limit_zone_deg and going_down:
		speed_limit *= dist_from_min / soft_limit_zone_deg
	if dist_from_max < soft_limit_zone_deg and not going_down:
		speed_limit *= dist_from_max / soft_limit_zone_deg
	_current_angle_deg = move_toward(_current_angle_deg, _target_angle_deg, speed_limit * delta)

func _step_manual(delta: float) -> void:
	var speed_limit := absf(_manual_speed) * manual_speed_deg
	_current_angle_deg = clampf(
		_current_angle_deg + signf(_manual_speed) * speed_limit * delta,
		min_angle_deg, max_angle_deg
	)
	_target_angle_deg = _current_angle_deg

func _apply_rotation() -> void:
	_node3d.rotation = rotation_axis * deg_to_rad(_current_angle_deg)

func _sync_colliders() -> void:
	if not _shape_entries.is_empty():
		_move_registered_shapes(_chassis, _shape_entries, arm)

func _set_state(new_state: ArmState) -> void:
	if state != new_state:
		state = new_state
