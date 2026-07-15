class_name SwerveSubsystem
extends Subsystem

@export var max_translation_speed: float = 8.0
@export var max_rotation_speed: float    = 3.5
@export var velocity_smoothing: float   = 0.25

@export var field_forward_offset: float = 0.0

@export var field_centric: bool = true

@export var module_paths: Array[NodePath] = []



enum DriveMode {
	FIELD_CENTRIC,
	ROBOT_CENTRIC,
	LOCKED,
	IDLE,
}

var drive_mode: DriveMode = DriveMode.FIELD_CENTRIC

signal stopped

var _modules: Array[SwerveModuleSubsystem] = []
var _max_wheel_dist: float = 1.0
var _body: RigidBody3D = null

var _desired_linear_local: Vector3 = Vector3.ZERO
var _desired_angular: float  = 0.0

var _was_moving: bool = false


func _setup(manager: SubsystemManager) -> void:
	super._setup(manager)

	_body = manager.get_parent() as RigidBody3D
	if not _body:
		push_error("SwerveSubsystem: SubsystemManager parent must be a RigidBody3D")
		return

	for path in module_paths:
		var module := get_node(path) as SwerveModuleSubsystem
		if module:
			_modules.append(module)
		else:
			push_warning("SwerveSubsystem: module path '%s' did not resolve to a SwerveModuleSubsystem" % path)

	_compute_max_wheel_dist()

func _compute_max_wheel_dist() -> void:
	_max_wheel_dist = 1.0
	for m in _modules:
		_max_wheel_dist = maxf(_max_wheel_dist, m.module_offset.length())

func drive(fwd: float, strafe: float, rot: float) -> void:
	var translation := Vector2(strafe, fwd)

	match drive_mode:
		DriveMode.FIELD_CENTRIC:
			var heading := _get_robot_heading()
			translation = translation.rotated(-heading)
		DriveMode.ROBOT_CENTRIC:
			pass
		DriveMode.LOCKED:
			_apply_lock_mode()
			_desired_linear_local  = Vector3.ZERO
			_desired_angular = 0.0
			return
		DriveMode.IDLE:
			stop()
			return

	_compute_and_apply_kinematics(translation, rot)

func drive_velocity(velocity: Vector3, rot_rads: float) -> void:
	_desired_linear_local = _body.global_transform.basis.inverse() * velocity
	_desired_angular      = rot_rads

func stop() -> void:
	for m in _modules:
		m.apply_state(m.current_angle, 0.0)
	_desired_linear_local = Vector3.ZERO
	_desired_angular      = 0.0

func set_locked(locked: bool) -> void:
	drive_mode = DriveMode.LOCKED if locked else DriveMode.FIELD_CENTRIC
	if locked:
		_apply_lock_mode()

func set_drive_mode(mode: DriveMode) -> void:
	drive_mode = mode

func get_heading_deg() -> float:
	return rad_to_deg(_get_robot_heading())

func get_speed_fraction() -> float:
	if not _body:
		return 0.0
	var horizontal := Vector2(_body.linear_velocity.x, _body.linear_velocity.z)
	return clampf(horizontal.length() / max_translation_speed, 0.0, 1.0)

func is_stopped() -> bool:
	if not _body:
		return true
	var horizontal := Vector2(_body.linear_velocity.x, _body.linear_velocity.z)
	return horizontal.length() < 0.05

func update(delta: float) -> void:
	if not _body:
		return

	var world_linear := _body.global_transform.basis * _desired_linear_local

	var target_velocity    := _body.linear_velocity
	target_velocity.x      = lerpf(_body.linear_velocity.x, world_linear.x, velocity_smoothing)
	target_velocity.z      = lerpf(_body.linear_velocity.z, world_linear.z, velocity_smoothing)
	
	_body.linear_velocity  = target_velocity
	_body.angular_velocity = _body.angular_velocity.lerp(
		Vector3(0.0, _desired_angular, 0.0), velocity_smoothing
	)

	var moving := not is_stopped()
	if _was_moving and not moving:
		stopped.emit()
	_was_moving = moving

func run_default(_delta: float) -> void:
	stop()

func _compute_and_apply_kinematics(translation: Vector2, rot: float) -> void:
	if _modules.is_empty():
		return

	var vecs: Array[Vector2] = []
	var max_mag := 0.0

	for m in _modules:
		var perp      := Vector2(-m.module_offset.y, m.module_offset.x)
		perp          /= _max_wheel_dist
		var vec        := translation + perp * rot
		vecs.append(vec)
		max_mag = maxf(max_mag, vec.length())

	if max_mag > 1.0:
		for i in vecs.size():
			vecs[i] /= max_mag

	var local_chassis := Vector2.ZERO

	for i in _modules.size():
		var vec   := vecs[i]
		var speed := vec.length()
		var angle := atan2(vec.x, vec.y) if speed > 0.01 else _modules[i].current_angle
		_modules[i].apply_state(angle, speed)
		local_chassis += vec

	local_chassis /= _modules.size()

	_desired_linear_local = Vector3(local_chassis.x, 0.0, -local_chassis.y) * max_translation_speed
	_desired_angular      = -rot * max_rotation_speed

func _apply_lock_mode() -> void:
	for m in _modules:
		var lock_angle := atan2(m.module_offset.x, m.module_offset.y)
		m.apply_state(lock_angle, 0.0)

func _get_robot_heading() -> float:
	if not _body:
		return 0.0
	return _body.global_rotation.y - deg_to_rad(field_forward_offset)
