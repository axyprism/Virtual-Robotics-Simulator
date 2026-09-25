class_name SwerveModuleSubsystem
extends Subsystem

@export var module_offset: Vector2 = Vector2.ZERO
@export var steer_speed: float = 12.0

@export var wheel_collider_shape: Shape3D
@export var wheel_visual_path: NodePath
@onready var wheel_visual: Node3D = get_node(wheel_visual_path)
@onready var _node3d: Node3D = get_node(".") as Node3D

var target_angle: float = 0.0
var target_speed: float = 0.0
var current_angle: float = 0.0

var _chassis: RigidBody3D
var _shape_owner: int = -1
var _wheel_spin: float = 0.0

func apply_state(angle_rad: float, speed: float) -> void:
	target_angle = angle_rad
	target_speed = speed

func get_velocity_vector() -> Vector2:
	return Vector2(sin(current_angle), cos(current_angle)) * target_speed

func _setup(manager: SubsystemManager) -> void:
	super._setup(manager)
	_chassis = manager.get_chassis_body()
	if wheel_collider_shape and _chassis:
		_shape_owner = _register_shape(_chassis, wheel_collider_shape)
	current_angle = _node3d.rotation.y

func update(delta: float) -> void:
	current_angle = lerp_angle(current_angle, target_angle, delta * steer_speed)
	_node3d.rotation.y = current_angle

	if wheel_visual:
		_wheel_spin += target_speed * delta * 20.0
		wheel_visual.rotation.x = _wheel_spin

	if _shape_owner != -1:
		_move_shape(_chassis, _shape_owner, _node3d)

func run_default(delta: float) -> void:
	apply_state(current_angle, 0.0)
	update(delta)

func get_sync_nodes() -> Array[Node3D]:
	var nodes: Array[Node3D] = [_node3d]
	if wheel_visual:
		nodes.append(wheel_visual)
	return nodes
