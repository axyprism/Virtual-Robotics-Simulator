class_name FeederSubsystem
extends Subsystem

@export var feeder_visual_path: NodePath
@onready var feeder_visual: Node3D = get_node(feeder_visual_path)

@export var contact_zones: Array[Area3D] = []
@export var feed_speed: float = 1.0
@export var feed_force: float = 10.0
@export var reverse_speed: float = -0.5
@export var visual_spin_rate: float = 15.0

var has_game_piece: bool = false
var _current_speed: float = 0.0
var _target_speed: float = 0.0
var _visual_spin: float = 0.0

var _pieces_in_zones: Dictionary = {}

signal game_piece_detected
signal game_piece_fired

func _ready() -> void:
	for zone in contact_zones:
		_pieces_in_zones[zone] = []
		zone.body_entered.connect(_on_zone_body_entered.bind(zone))
		zone.body_exited.connect(_on_zone_body_exited.bind(zone))

func _on_zone_body_entered(body: Node, zone: Area3D) -> void:
	if not body.is_in_group("game_piece"):
		return
	var rb := body as RigidBody3D
	if not rb:
		return
	_pieces_in_zones[zone].append(rb)
	_on_game_piece_entered(rb)

func _on_zone_body_exited(body: Node, zone: Area3D) -> void:
	_pieces_in_zones[zone].erase(body)
	if _all_zones_empty():
		_on_game_piece_exited(body)

func _all_zones_empty() -> bool:
	for zone in contact_zones:
		if not _pieces_in_zones[zone].is_empty():
			return false
	return true

func feed() -> void:
	_target_speed = feed_speed

func reverse() -> void:
	_target_speed = reverse_speed

func stop() -> void:
	_target_speed = 0.0

func is_feeding() -> bool:
	return _current_speed > 0.1

func get_sync_nodes() -> Array[Node3D]:
	var result: Array[Node3D] = []
	if feeder_visual:
		result.append(feeder_visual)
	return result

func _on_game_piece_entered(_body: Node) -> void:
	has_game_piece = true
	game_piece_detected.emit()

func _on_game_piece_exited(_body: Node) -> void:
	has_game_piece = false
	game_piece_fired.emit()

func update(delta: float) -> void:
	_current_speed = move_toward(_current_speed, _target_speed, delta * 8.0)

	if is_feeding():
		_apply_zone_forces()

	if feeder_visual:
		_visual_spin += _current_speed * visual_spin_rate * delta
		feeder_visual.rotation.x = _visual_spin

func _apply_zone_forces() -> void:
	for zone in contact_zones:
		var pieces: Array = _pieces_in_zones[zone]
		if pieces.is_empty():
			continue
		var direction := zone.global_transform.basis.z
		direction = direction.normalized()
		for piece in pieces:
			var rb := piece as RigidBody3D
			if not rb:
				continue
			rb.apply_central_force(direction * feed_force * _current_speed)

func run_default(delta: float) -> void:
	stop()
	update(delta)
