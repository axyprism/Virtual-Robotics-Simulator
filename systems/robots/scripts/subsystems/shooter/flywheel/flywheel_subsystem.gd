class_name FlywheelSubsystem
extends Subsystem

@export var wheel_visual_path: NodePath
@onready var wheel_visual: Node3D = get_node(wheel_visual_path)

@export var spin_up_rate: float = 3.0
@export var spin_down_rate: float = 2.0
@export var launch_force: float = 20.0
@export var contact_zones: Array[Area3D] = []
@export var at_speed_tolerance: float = 0.05
@export var max_visual_spin_rps: float = 40.0

var current_speed: float = 0.0
var _target_speed: float = 0.0
var _visual_spin: float = 0.0
var _running: bool = false

var _pieces_in_zones: Dictionary = {}

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

func _on_zone_body_exited(body: Node, zone: Area3D) -> void:
	_pieces_in_zones[zone].erase(body)

func set_target_speed(normalized: float) -> void:
	_target_speed = clampf(normalized, 0.0, 1.0)

func spin_up(speed: float = 1.0) -> void:
	_running = true
	set_target_speed(speed)

func spin_down() -> void:
	_running = false
	set_target_speed(0.0)

func at_speed() -> bool:
	if _target_speed < 0.01:
		return false
	return abs(current_speed - _target_speed) < at_speed_tolerance

func get_sync_nodes() -> Array[Node3D]:
	var result: Array[Node3D] = []
	if wheel_visual:
		result.append(wheel_visual)
	return result

func is_spinning() -> bool:
	return current_speed > 0.01

func update(delta: float) -> void:
	var rate := spin_up_rate if current_speed < _target_speed else spin_down_rate
	current_speed = move_toward(current_speed, _target_speed, rate * delta)

	if is_spinning():
		_apply_zone_forces()

	if wheel_visual:
		_visual_spin += current_speed * max_visual_spin_rps * delta
		wheel_visual.rotation.x = _visual_spin

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
			rb.apply_central_force(direction * launch_force * current_speed)

func run_default(delta: float) -> void:
	spin_down()
	update(delta)
