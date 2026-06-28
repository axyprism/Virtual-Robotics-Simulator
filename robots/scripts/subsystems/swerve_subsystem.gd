class_name SwerveSubsystem
extends Subsystem

# --- Configuration ---

@export var max_translation_speed: float = 8.0    ## m/s
@export var max_rotation_speed: float    = 3.5    ## rad/s
@export var velocity_smoothing: float   = 0.25   ## lower = slidey, higher = snappy

## Heading offset so "field forward" matches your field layout (degrees)
@export var field_forward_offset: float = 0.0

## If true, drive() input is interpreted as field-relative.
## If false, input is robot-relative (e.g. for auto routines).
@export var field_centric: bool = true

# --- Module references ---
## Assign all four SwerveModuleSubsystem children here in the inspector
@export var module_paths: Array[NodePath] = []

# --- State ---

enum DriveMode {
	FIELD_CENTRIC,      ## Normal teleop — forward is always field-forward
	ROBOT_CENTRIC,      ## Input relative to robot nose
	LOCKED,             ## Modules form an X — resists being pushed
	IDLE,               ## Modules hold angle, no drive
}

var drive_mode: DriveMode = DriveMode.FIELD_CENTRIC

## Emitted when the robot comes to a full stop (all modules at zero speed)
signal stopped

var _modules: Array[SwerveModuleSubsystem] = []
var _max_wheel_dist: float = 1.0
var _body: RigidBody3D = null

## Current desired chassis velocity (set by drive(), read in update())
var _desired_linear_local: Vector3 = Vector3.ZERO
var _desired_angular: float  = 0.0

var _was_moving: bool = false

# --- Setup ---

func _setup(manager: SubsystemManager) -> void:
	super._setup(manager)

	# Grab the RigidBody3D — it's the robot root (parent of SubsystemManager)
	_body = manager.get_parent() as RigidBody3D
	if not _body:
		push_error("SwerveSubsystem: SubsystemManager parent must be a RigidBody3D")
		return

	# Resolve module paths now that we're in the tree
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

# --- Public API ---

## Primary drive input.
## fwd/strafe/rot are all normalized -1.0 to 1.0.
## In field-centric mode, fwd is always away from the driver station.
func drive(fwd: float, strafe: float, rot: float) -> void:
	var translation := Vector2(strafe, fwd)

	match drive_mode:
		DriveMode.FIELD_CENTRIC:
			var heading := _get_robot_heading()
			translation = translation.rotated(-heading)
		DriveMode.ROBOT_CENTRIC:
			pass  ## Input is already robot-relative
		DriveMode.LOCKED:
			_apply_lock_mode()
			_desired_linear_local  = Vector3.ZERO
			_desired_angular = 0.0
			return
		DriveMode.IDLE:
			stop()
			return

	_compute_and_apply_kinematics(translation, rot)

## Drive toward a field-space target velocity directly (for auto / command use).
## velocity is in m/s field-space, rot_rads is rad/s.
func drive_velocity(velocity: Vector3, rot_rads: float) -> void:
	# velocity is already world-space, convert to local for consistent storage
	_desired_linear_local = _body.global_transform.basis.inverse() * velocity
	_desired_angular      = rot_rads

func stop() -> void:
	for m in _modules:
		m.apply_state(m.current_angle, 0.0)
	_desired_linear_local = Vector3.ZERO  # ← rename here too
	_desired_angular      = 0.0

## Form an X with the wheels — makes the robot very hard to push
func set_locked(locked: bool) -> void:
	drive_mode = DriveMode.LOCKED if locked else DriveMode.FIELD_CENTRIC
	if locked:
		_apply_lock_mode()

func set_drive_mode(mode: DriveMode) -> void:
	drive_mode = mode

## Returns the robot's current heading in radians relative to field forward
func get_heading_deg() -> float:
	return rad_to_deg(_get_robot_heading())

## Returns the robot's current speed as a fraction of max (0.0 - 1.0)
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

# --- Internal ---

func update(delta: float) -> void:
	if not _body:
		return

	# Transform desired velocity from robot-local to world space
	var world_linear := _body.global_transform.basis * _desired_linear_local

	# Only control horizontal velocity — leave Y to the physics engine for gravity
	var target_velocity    := _body.linear_velocity  # start from current (preserves Y)
	target_velocity.x      = lerpf(_body.linear_velocity.x, world_linear.x, velocity_smoothing)
	target_velocity.z      = lerpf(_body.linear_velocity.z, world_linear.z, velocity_smoothing)
	# target_velocity.y is untouched — physics engine owns it

	_body.linear_velocity  = target_velocity
	_body.angular_velocity = _body.angular_velocity.lerp(
		Vector3(0.0, _desired_angular, 0.0), velocity_smoothing
	)

	var moving := not is_stopped()
	if _was_moving and not moving:
		stopped.emit()
	_was_moving = moving

func run_default(_delta: float) -> void:
	## When no command is running, coast to a stop
	stop()

func _compute_and_apply_kinematics(translation: Vector2, rot: float) -> void:
	if _modules.is_empty():
		return

	## --- Swerve kinematics ---
	## Each module's velocity = chassis translation + rotation contribution
	## Rotation contribution at offset (ox, oy): perpendicular vector (-oy, ox)
	var vecs: Array[Vector2] = []
	var max_mag := 0.0

	for m in _modules:
		var perp      := Vector2(-m.module_offset.y, m.module_offset.x)
		perp          /= _max_wheel_dist
		var vec        := translation + perp * rot
		vecs.append(vec)
		max_mag = maxf(max_mag, vec.length())

	## Desaturate: scale all down if any module exceeds 1.0
	if max_mag > 1.0:
		for i in vecs.size():
			vecs[i] /= max_mag

	## Apply to modules + derive chassis desired velocity
	var local_chassis := Vector2.ZERO

	for i in _modules.size():
		var vec   := vecs[i]
		var speed := vec.length()
		var angle := atan2(vec.x, vec.y) if speed > 0.01 else _modules[i].current_angle
		_modules[i].apply_state(angle, speed)
		local_chassis += vec

	local_chassis /= _modules.size()

	# Store as robot-local 3D velocity — transformed to world space in update()
	_desired_linear_local = Vector3(local_chassis.x, 0.0, -local_chassis.y) * max_translation_speed
	_desired_angular      = -rot * max_rotation_speed

func _apply_lock_mode() -> void:
	## Point each module tangentially to form an X pattern
	for m in _modules:
		var lock_angle := atan2(m.module_offset.x, m.module_offset.y)
		m.apply_state(lock_angle, 0.0)

func _get_robot_heading() -> float:
	if not _body:
		return 0.0
	return _body.global_rotation.y - deg_to_rad(field_forward_offset)
