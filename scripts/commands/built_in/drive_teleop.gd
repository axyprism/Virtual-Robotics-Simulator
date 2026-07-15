class_name DriveTeleopCommand
extends Command

var _swerve: SwerveSubsystem

func _init(swerve: SwerveSubsystem) -> void:
	_swerve = swerve
	require(swerve)

func on_update(_delta: float) -> void:
	_swerve.drive(
		_deadzone(Input.get_axis("RobotBack", "RobotForward")),
		_deadzone(Input.get_axis("RobotLeft", "RobotRight")),
		_deadzone(Input.get_axis("RobotRotateLeft", "RobotRotateRight"))
	)

func _deadzone(value: float, threshold: float = 0.1) -> float:
	if absf(value) < threshold:
		return 0.0
	return signf(value) * (absf(value) - threshold) / (1.0 - threshold)

func on_end(_interrupted: bool) -> void:
	_swerve.stop()

func is_finished() -> bool:
	return false
