class_name SwerveRobot
extends BaseRobot

var _is_controlled:  bool               = false
var _teleop_command: DriveTeleopCommand = null

func _ready() -> void:
	set_controlled(false)

func get_robot_name() -> String:
	return "Swerve Robot"

func set_controlled(value: bool) -> void:
	_is_controlled = value
	var swerve := _get_swerve()
	if not swerve:
		return
	if value:
		_teleop_command = DriveTeleopCommand.new(swerve)
		CommandScheduler.schedule(_teleop_command, self)
	else:
		if _teleop_command:
			CommandScheduler.cancel(_teleop_command)
			_teleop_command = null
	var manager := get_subsystem_manager()
	if manager:
		for s in manager.get_all():
			s.set_active(value)

func _get_swerve() -> SwerveSubsystem:
	var manager := get_subsystem_manager()
	if manager:
		return manager.get_subsystem(SwerveSubsystem) as SwerveSubsystem
	return null
