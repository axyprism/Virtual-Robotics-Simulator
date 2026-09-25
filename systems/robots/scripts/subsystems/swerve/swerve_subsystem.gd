class_name SwerveSubsystem
extends Subsystem

@export var max_translation_speed: float = 8.0
@export var max_rotation_speed: float = 3.5
@export var velocity_smoothing: float = 0.25

@export var field_forward_offset: float = 0.0

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
var _desired_angular: float = 0.0

var _was_moving: bool = false


func _setup(manager: SubsystemManager) -> void:
	super._setup(manager)

	_body = get_node(".") as RigidBody3D
	if not _body:
		push_error("SwerveSubsystem: node must be a RigidBody3D")
		return
		
	_body.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	_body.center_of_mass = Vector3(0, -0.15, 0)
	_body.mass = 80.0
	_body.gravity_scale = 1.0
	_body.angular_damp = 6.0
	_body.linear_damp = 2.0
	_body.continuous_cd = true

	var chassis_material := PhysicsMaterial.new()
	chassis_material.friction = 0.0
	_body.physics_material_override = chassis_material

	for path in module_paths:
		var module := get_node(path) as SwerveModuleSubsystem
		if module:
			_modules.append(module)
		else:
			push_warning("SwerveSubsystem: module path '%s' did not resolve to a SwerveModuleSubsystem" % path)

	_compute_max_wheel_dist()
	drive_mode = _camera_drive_mode()
	CameraSettings.camera_mode_changed.connect(_on_camera_mode_changed)

	# The "Sync" MultiplayerSynchronizer already replicates position/
	# rotation/velocity, but without freezing, local physics keeps
	# simulating (gravity, collisions) in between sync ticks and fights
	# those incoming values, causing jitter. This is the one piece missing.
	if not _body.is_multiplayer_authority():
		_body.freeze = true
		_body.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC

func get_body() -> RigidBody3D:
	return _body

func _camera_drive_mode() -> DriveMode:
	return DriveMode.FIELD_CENTRIC if CameraSettings.is_advanced() else DriveMode.ROBOT_CENTRIC

func _on_camera_mode_changed(_mode: CameraSettings.CameraMode) -> void:
	# Only swap the "active steering" modes; don't fight a lock or idle
	# state someone else put us in.
	if drive_mode == DriveMode.FIELD_CENTRIC or drive_mode == DriveMode.ROBOT_CENTRIC:
		drive_mode = _camera_drive_mode()

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
			_desired_linear_local = Vector3.ZERO
			_desired_angular = 0.0
			return
		DriveMode.IDLE:
			stop()
			return

	_compute_and_apply_kinematics(translation, rot)

func drive_velocity(velocity: Vector3, rot_rads: float) -> void:
	_desired_linear_local = _body.global_transform.basis.inverse() * velocity
	_desired_angular = rot_rads

func stop() -> void:
	for m in _modules:
		m.apply_state(m.current_angle, 0.0)
	_desired_linear_local = Vector3.ZERO
	_desired_angular = 0.0

func set_locked(locked: bool) -> void:
	drive_mode = DriveMode.LOCKED if locked else _camera_drive_mode()
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

	var target_velocity := _body.linear_velocity
	target_velocity.x = lerpf(_body.linear_velocity.x, world_linear.x, velocity_smoothing)
	target_velocity.z = lerpf(_body.linear_velocity.z, world_linear.z, velocity_smoothing)
	
	var max_accel := 5.0
	var max_angular_accel := 20.0

	var linear_error := target_velocity - _body.linear_velocity
	linear_error.y = 0.0
	var max_delta_v := max_accel * delta
	if linear_error.length() > max_delta_v:
		linear_error = linear_error.normalized() * max_delta_v
	_body.apply_central_force(linear_error * _body.mass / delta)

	_body.angular_velocity.y = move_toward(_body.angular_velocity.y, _desired_angular, max_angular_accel * delta)

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
		var perp := Vector2(-m.module_offset.y, m.module_offset.x)
		perp /= _max_wheel_dist
		var vec := translation + perp * rot
		vecs.append(vec)
		max_mag = maxf(max_mag, vec.length())

	if max_mag > 1.0:
		for i in vecs.size():
			vecs[i] /= max_mag

	var local_chassis := Vector2.ZERO

	for i in _modules.size():
		var vec := vecs[i]
		var speed := vec.length()
		var angle := atan2(vec.x, vec.y) if speed > 0.01 else _modules[i].current_angle
		_modules[i].apply_state(angle, speed)
		local_chassis += vec

	local_chassis /= _modules.size()

	_desired_linear_local = Vector3(local_chassis.x, 0.0, -local_chassis.y) * max_translation_speed
	_desired_angular = -rot * max_rotation_speed

func _apply_lock_mode() -> void:
	for m in _modules:
		var lock_angle := atan2(m.module_offset.x, m.module_offset.y)
		m.apply_state(lock_angle, 0.0)

func _get_robot_heading() -> float:
	if not _body:
		return 0.0
	return _body.global_rotation.y - deg_to_rad(field_forward_offset)
