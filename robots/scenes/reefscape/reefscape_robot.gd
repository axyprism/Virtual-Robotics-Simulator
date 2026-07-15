class_name ReefscapeRobot
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

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("RobotSubsystemDown"):
		var manager: SubsystemManager = get_tree().get_first_node_in_group("subsystem_managers")
		if manager:
			var elevator1 = manager.get_subsystem_by_id("Elevator1")
			var elevator2 = manager.get_subsystem_by_id("Elevator2")
			CommandScheduler.schedule(
				CommandGroup.parallel()
					.add(SetElevatorHeight.new(elevator1, 0))
					.add(SetElevatorHeight.new(elevator2, 0))
			)
	if event.is_action_pressed("RobotSubsystemUp"):
		var manager = get_tree().get_first_node_in_group("subsystem_managers")
		if manager:
			var elevator1 = manager.get_subsystem_by_id("Elevator1")
			var elevator2 = manager.get_subsystem_by_id("Elevator2")
			CommandScheduler.schedule(
				CommandGroup.parallel()
					.add(SetElevatorHeight.new(elevator1, 2))
					.add(SetElevatorHeight.new(elevator2, 2))
			)
