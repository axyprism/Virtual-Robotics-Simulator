class_name IntakeSubsystem
extends Subsystem

@export var roller_visual_path: NodePath
@onready var roller_visual: Node3D = get_node_or_null(roller_visual_path)

@export var roller_zone_paths: Array[NodePath] = []

@export var hold_position_path: NodePath
@onready var hold_position: Marker3D = get_node_or_null(hold_position_path)
@export var hold_enabled: bool = true

@export var spin_axis: Vector3 = Vector3.RIGHT
@export var visual_spin_rate: float = 15.0
@export var intake_force: float = 10.0
@export var game_piece_group: StringName = "game_piece"
@export var auto_stop_on_pickup: bool = true
@export var intake_speed: float = 1.0
@export var eject_speed: float = -0.8

enum IntakeState {
	IDLE,
	INTAKING,
	EJECTING,
	HOLDING,
}

var state: IntakeState = IntakeState.IDLE
var held_piece: RigidBody3D = null

var _current_speed: float = 0.0
var _target_speed: float = 0.0
var _visual_spin: float = 0.0

var _pieces_in_zones: Dictionary = {}

var _zones: Array[Area3D] = []

signal game_piece_acquired(piece: RigidBody3D)
signal game_piece_released(piece: RigidBody3D)

func get_sync_nodes() -> Array[Node3D]:
	var nodes: Array[Node3D] = []
	if roller_visual != null:
		nodes.append(roller_visual)
	return nodes


func intake() -> void:
	_target_speed = intake_speed
	_set_state(IntakeState.INTAKING)

func eject() -> void:
	_target_speed = eject_speed
	_set_state(IntakeState.EJECTING)

func stop() -> void:
	_target_speed = 0.0
	_set_state(IntakeState.IDLE)

func has_game_piece() -> bool:
	return held_piece != null

func is_running() -> bool:
	return absf(_current_speed) > 0.05

func hold_piece(piece: RigidBody3D) -> void:
	if not hold_enabled:
		return
	held_piece = piece
	held_piece.freeze = true
	_set_state(IntakeState.HOLDING)
	if auto_stop_on_pickup:
		_target_speed = 0.0
	game_piece_acquired.emit(piece)

func release_piece() -> void:
	if not held_piece:
		return
	held_piece.freeze = false
	game_piece_released.emit(held_piece)
	held_piece = null
	_set_state(IntakeState.IDLE)

func launch_piece(direction: Vector3, force: float) -> void:
	if not held_piece:
		return
	held_piece.freeze = false
	held_piece.apply_central_impulse(direction * force)
	game_piece_released.emit(held_piece)
	held_piece = null
	_set_state(IntakeState.IDLE)


func _ready() -> void:
	for path in roller_zone_paths:
		var zone := get_node_or_null(path) as Area3D
		if zone:
			_zones.append(zone)
			_pieces_in_zones[zone] = []
			zone.body_entered.connect(_on_zone_body_entered.bind(zone))
			zone.body_exited.connect(_on_zone_body_exited.bind(zone))

func _on_zone_body_entered(body: Node, zone: Area3D) -> void:
	if not body.is_in_group(game_piece_group):
		return
	var rb := body as RigidBody3D
	if not rb:
		return
	_pieces_in_zones[zone].append(rb)

func _on_zone_body_exited(body: Node, zone: Area3D) -> void:
	_pieces_in_zones[zone].erase(body)
	if body == held_piece:
		held_piece = null

func update(delta: float) -> void:
	_current_speed = move_toward(_current_speed, _target_speed, delta * 8.0)

	if is_running():
		_apply_zone_forces()

	if held_piece and held_piece.freeze and hold_position:
		held_piece.global_position = hold_position.global_position

	if roller_visual:
		_visual_spin += _current_speed * visual_spin_rate * delta
		roller_visual.rotation = spin_axis * _visual_spin

func _apply_zone_forces() -> void:
	for zone in _zones:
		var pieces: Array = _pieces_in_zones[zone]
		if pieces.is_empty():
			continue
		var direction := zone.global_transform.basis * Vector3(0, 0, -1)
		direction = direction.normalized()
		for piece in pieces:
			var rb := piece as RigidBody3D
			if not rb or rb.freeze:
				continue
			if state == IntakeState.INTAKING:
				rb.apply_central_force(direction * intake_force * _current_speed)
				if hold_enabled and not has_game_piece():
					if hold_position and rb.global_position.distance_to(
							hold_position.global_position) < 0.15:
						hold_piece(rb)
			elif state == IntakeState.EJECTING:
				rb.apply_central_force(
					-direction * intake_force * absf(_current_speed)
				)

func _set_state(new_state: IntakeState) -> void:
	if state != new_state:
		state = new_state
