class_name FlywheelSubsystem
extends Subsystem

## The Node3D that visually spins (e.g. a wheel mesh)
@export var wheel_visual_path: NodePath
@onready var wheel_visual: Node3D = get_node(wheel_visual_path)

## How fast the flywheel accelerates/decelerates (higher = snappier)
@export var spin_up_rate: float = 3.0
@export var spin_down_rate: float = 2.0

## Tolerance to consider "at speed" (0.0 - 1.0, as a fraction of target)
@export var at_speed_tolerance: float = 0.05

## Max visual spin speed in radians per second (cosmetic only)
@export var max_visual_spin_rps: float = 40.0

## Current normalized speed (0.0 = stopped, 1.0 = full speed)
var current_speed: float = 0.0

var _target_speed: float = 0.0
var _visual_spin: float = 0.0
var _running: bool = false

# --- Public API ---

func set_target_speed(normalized: float) -> void:
	_target_speed = clampf(normalized, 0.0, 1.0)

func spin_up(speed: float = 1.0) -> void:
	_running = true
	set_target_speed(speed)

func spin_down() -> void:
	_running = false
	set_target_speed(0.0)

## Returns true when the flywheel is within tolerance of its target speed
## and the target is not zero (i.e. it's actually spun up, not spun down)
func at_speed() -> bool:
	if _target_speed < 0.01:
		return false
	return abs(current_speed - _target_speed) < at_speed_tolerance

func is_spinning() -> bool:
	return current_speed > 0.01

# --- Internal ---

func update(delta: float) -> void:
	var rate := spin_up_rate if current_speed < _target_speed else spin_down_rate
	current_speed = move_toward(current_speed, _target_speed, rate * delta)

	if wheel_visual:
		_visual_spin += current_speed * max_visual_spin_rps * delta
		wheel_visual.rotation.z = _visual_spin

func run_default(delta: float) -> void:
	spin_down()
	update(delta)
