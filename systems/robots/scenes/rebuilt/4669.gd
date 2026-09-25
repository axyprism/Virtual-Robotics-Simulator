class_name GalileoRobotics2026
extends BaseRobot

var _is_controlled: bool = false
var _teleop_command: DriveTeleopCommand = null

func _ready() -> void:
	set_controlled(false)
	var manager: SubsystemManager = _get_manager()
	if manager:
		var arm = manager.get_subsystem_by_id("Arm")
		CommandScheduler.schedule(
			SetArmAngle.new(arm, 45)
		)

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

func _get_manager() -> SubsystemManager:
	return get_node_or_null("SubsystemManager") as SubsystemManager

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("RobotSubsystemRight"):
		var manager = _get_manager()
		if manager:
			var shooter = manager.get_subsystem_by_id("Shooter")
			CommandScheduler.schedule(
				CommandGroup.parallel()
					.add(FireShooter.new(shooter, 4))
			)
	if event.is_action_pressed("RobotSubsystemLeft"):
		var manager: SubsystemManager = _get_manager()
		if manager:
			var intake = manager.get_subsystem_by_id("Intake")
			CommandScheduler.schedule(
				RunIntake.new(intake, false, false)
			)
	if event.is_action_released("RobotSubsystemLeft"):
		var manager: SubsystemManager = _get_manager()
		if manager:
			var intake = manager.get_subsystem_by_id("Intake")
			CommandScheduler.schedule(
				StopIntake.new(intake)
			)
	if event.is_action_pressed("RobotSubsystemUp"):
		var manager: SubsystemManager = _get_manager()
		if manager:
			var arm = manager.get_subsystem_by_id("Arm")
			if arm:
				CommandScheduler.schedule(
					SetArmAngle.new(arm, -80)
				)
	if event.is_action_pressed("RobotSubsystemDown"):
		var manager: SubsystemManager = _get_manager()
		if manager:
			var arm = manager.get_subsystem_by_id("Arm")
			if arm:
				CommandScheduler.schedule(
						SetArmAngle.new(arm, 0)
				)
