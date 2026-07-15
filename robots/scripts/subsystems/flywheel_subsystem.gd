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

func _ready() -> void:
	for i in contact_zones:
		i.body_entered.connect(_on_game_piece_contact)
	
func _on_game_piece_contact(body: Node) -> void:
	if not body.is_in_group("game_piece"):
		return
	if not is_spinning():
		return
	var rb := body as RigidBody3D
	if not rb:
		return
	var direction = self.global_transform.basis.z
	rb.apply_central_impulse(direction * launch_force * current_speed)

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

func is_spinning() -> bool:
	return current_speed > 0.01

func update(delta: float) -> void:
	var rate := spin_up_rate if current_speed < _target_speed else spin_down_rate
	current_speed = move_toward(current_speed, _target_speed, rate * delta)

	if wheel_visual:
		_visual_spin += current_speed * max_visual_spin_rps * delta
		wheel_visual.rotation.x = _visual_spin

func run_default(delta: float) -> void:
	spin_down()
	update(delta)
