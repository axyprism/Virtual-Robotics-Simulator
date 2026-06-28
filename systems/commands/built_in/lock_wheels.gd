# lock_wheels_command.gd
## Holds the X-lock for a duration, then releases.
## Pass duration = -1 to hold indefinitely until cancelled.
class_name LockWheelsCommand
extends Command

var _swerve: SwerveSubsystem
var _duration: float
var _elapsed: float = 0.0

func _init(swerve: SwerveSubsystem, duration: float = -1.0) -> void:
	_swerve   = swerve
	_duration = duration
	require(swerve)

func on_start() -> void:
	_elapsed = 0.0
	_swerve.set_locked(true)

func on_update(delta: float) -> void:
	_elapsed += delta

func on_end(_interrupted: bool) -> void:
	_swerve.set_locked(false)

func is_finished() -> bool:
	return _duration >= 0.0 and _elapsed >= _duration
