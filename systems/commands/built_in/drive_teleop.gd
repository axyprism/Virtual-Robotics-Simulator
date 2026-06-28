class_name DriveTeleopCommand
extends Command

var _swerve: SwerveSubsystem

func _init(swerve: SwerveSubsystem) -> void:
	_swerve = swerve
	require(swerve)

func on_update(_delta: float) -> void:
	_swerve.drive(
		Input.get_axis("RobotBack",         "RobotForward"),
		Input.get_axis("RobotLeft",          "RobotRight"),
		Input.get_axis("RobotRotateLeft",   "RobotRotateRight")
	)

func on_end(_interrupted: bool) -> void:
	_swerve.stop()

func is_finished() -> bool:
	return false  ## Runs until cancelled
