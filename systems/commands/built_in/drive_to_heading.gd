## Rotates the robot to a target field-relative heading while optionally translating.
class_name DriveToHeadingCommand
extends Command

@export var target_heading_deg: float = 0.0
@export var tolerance_deg: float      = 2.0
@export var rotation_p: float         = 0.04   ## proportional gain

var _swerve: SwerveSubsystem
var _fwd: float
var _strafe: float

func _init(swerve: SwerveSubsystem, heading_deg: float,
		   fwd: float = 0.0, strafe: float = 0.0) -> void:
	_swerve          = swerve
	target_heading_deg = heading_deg
	_fwd             = fwd
	_strafe          = strafe
	require(swerve)

func on_update(_delta: float) -> void:
	var error := _angle_error()
	var rot   := clampf(error * rotation_p, -1.0, 1.0)
	_swerve.drive(_fwd, _strafe, rot)

func on_end(_interrupted: bool) -> void:
	_swerve.stop()

func is_finished() -> bool:
	return absf(_angle_error()) < tolerance_deg

func _angle_error() -> float:
	var current := _swerve.get_heading_deg()
	var error   := fmod(target_heading_deg - current + 540.0, 360.0) - 180.0
	return error
