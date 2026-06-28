class_name SwerveModuleSubsystem
extends Subsystem

## Position of this module relative to robot center (X = right, Y = forward)
@export var module_offset: Vector2 = Vector2.ZERO

## How fast the steering snaps to target angle
@export var steer_speed: float = 12.0

## Node3D that rotates to show steering direction
@export var steer_visual_path: NodePath
@onready var steer_visual: Node3D = get_node(steer_visual_path)

## Node3D that spins to show drive (child of steer visual)
@export var wheel_visual_path: NodePath
@onready var wheel_visual: Node3D = get_node(wheel_visual_path)

## Read by SwerveSubsystem each tick to build the chassis velocity
var target_angle: float = 0.0
var target_speed: float = 0.0   # normalized 0.0 - 1.0

## Actual current steering angle (lerped toward target)
var current_angle: float = 0.0

var _wheel_spin: float = 0.0

# --- Public API ---

func apply_state(angle_rad: float, speed: float) -> void:
	target_angle = angle_rad
	target_speed = speed

func get_velocity_vector() -> Vector2:
	return Vector2(sin(current_angle), cos(current_angle)) * target_speed

# --- Internal ---

func update(delta: float) -> void:
	current_angle = lerp_angle(current_angle, target_angle, delta * steer_speed)

	if steer_visual:
		steer_visual.rotation.y = current_angle

	if wheel_visual:
		_wheel_spin += target_speed * delta * 20.0
		wheel_visual.rotation.x = _wheel_spin

func run_default(delta: float) -> void:
	apply_state(current_angle, 0.0)
	update(delta)
