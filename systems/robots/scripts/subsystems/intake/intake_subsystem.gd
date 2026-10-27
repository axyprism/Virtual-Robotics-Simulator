class_name IntakeSubsystem
extends Subsystem

@export var roller_visual_path: NodePath
@onready var roller_visual: Node3D = get_node_or_null(roller_visual_path)

@export var roller_zone_paths: Array[NodePath] = []

@export var hold_position_path: NodePath
@onready var hold_position: Marker3D = get_node_or_null(hold_position_path)
@export var hold_enabled: bool = true
@export var hold_pull_speed: float = 6.0
@export var release_collision_delay: float = 0.25

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
var _hold_offset: Transform3D = Transform3D.IDENTITY
var _tracked_piece: RigidBody3D = null
var _release_timer: float = 0.0

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
	held_piece.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	if hold_position:
		_hold_offset = hold_position.global_transform.orthonormalized().affine_inverse() * piece.global_transform
	if _tracked_piece and _tracked_piece != piece:
		_set_robot_collision(_tracked_piece, false)
	_tracked_piece = piece
	_set_robot_collision(piece, true)
	_set_state(IntakeState.HOLDING)
	if auto_stop_on_pickup:
		_target_speed = 0.0
	game_piece_acquired.emit(piece)

func release_piece() -> void:
	if not held_piece:
		return
	held_piece.freeze = false
	game_piece_released.emit(held_piece)
	_set_robot_collision(held_piece, true)
	held_piece = null
	_set_state(IntakeState.IDLE)

func launch_piece(direction: Vector3, force: float) -> void:
	if not held_piece:
		return
	held_piece.freeze = false
	held_piece.apply_central_impulse(direction * force)
	game_piece_released.emit(held_piece)
	_set_robot_collision(held_piece, true)
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
	if not _pieces_in_zones[zone].has(rb):
		_pieces_in_zones[zone].append(rb)

func _on_zone_body_exited(body: Node, zone: Area3D) -> void:
	_pieces_in_zones[zone].erase(body)

func _set_robot_collision(piece: RigidBody3D, ignore: bool) -> void:
	var node := get_parent()
	while node and not node is SubsystemManager:
		node = node.get_parent()
	var manager := node as SubsystemManager
	if not manager:
		return
	var _robot_body = manager.get_subsystem(SwerveSubsystem)
	if not _robot_body or not is_instance_valid(piece):
		return
	if ignore:
		piece.add_collision_exception_with(_robot_body)
	else:
		piece.remove_collision_exception_with(_robot_body)

func _restore_robot_collision(piece: RigidBody3D) -> void:
	await get_tree().create_timer(0.25).timeout
	if is_instance_valid(piece) and piece != held_piece:
		_set_robot_collision(piece, false)

func update(delta: float) -> void:
	_current_speed = move_toward(_current_speed, _target_speed, delta * 8.0)

	if is_running():
		_apply_zone_forces()

	if roller_visual:
		_visual_spin += _current_speed * visual_spin_rate * delta
		roller_visual.rotation = spin_axis * _visual_spin

func _physics_process(delta: float) -> void:
	_update_collision_restore(delta)
	if not is_instance_valid(held_piece) or not hold_position:
		return
	if not held_piece.freeze:
		release_piece()
		return
	var pull := 1.0 - exp(-hold_pull_speed * delta)
	_hold_offset.origin = _hold_offset.origin.lerp(Vector3.ZERO, pull)
	_hold_offset.basis = Basis(Quaternion(_hold_offset.basis.orthonormalized()).slerp(Quaternion.IDENTITY, pull))
	held_piece.global_transform = hold_position.global_transform.orthonormalized() * _hold_offset

func _update_collision_restore(delta: float) -> void:
	if not _tracked_piece:
		return
	if _tracked_piece == held_piece:
		_release_timer = release_collision_delay
		return
	_release_timer -= delta
	if _release_timer <= 0.0:
		_set_robot_collision(_tracked_piece, false)
		_tracked_piece = null

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
