class_name CheezyPoofsRobot
extends BaseRobot

var _is_controlled: bool = false
var _teleop_command: DriveTeleopCommand = null
var owner_peer_id: int = -1

func _ready() -> void:
	set_controlled(false)
	if multiplayer.is_server():
		var manager: SubsystemManager = _get_manager()
		if manager:
			var arm = manager.get_subsystem_by_id("Arm")
			CommandScheduler.schedule(
				SetArmAngle.new(arm, 30)
			)

func set_owner_peer_id(id: int) -> void:
	owner_peer_id = id

func _is_owning_peer() -> bool:
	return owner_peer_id == multiplayer.get_unique_id()

func is_owned_by_local_peer() -> bool:
	return _is_owning_peer()

func get_robot_name() -> String:
	return "Swerve Robot"

func set_controlled(value: bool) -> void:
	_is_controlled = value
	var swerve := _get_swerve()
	if not swerve:
		return
	if value and multiplayer.is_server():
		_teleop_command = DriveTeleopCommand.new(swerve)
		CommandScheduler.schedule(_teleop_command, self)
	elif not value and _teleop_command:
		CommandScheduler.cancel(_teleop_command)
		_teleop_command = null
	_set_subsystems_active(value)
	if not multiplayer.is_server() and NetworkManager.is_networked():
		_rpc_relay_set_controlled.rpc_id(1, value)

func _set_subsystems_active(value: bool) -> void:
	var manager := get_subsystem_manager()
	if manager:
		for s in manager.get_all():
			s.set_active(value)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_relay_set_controlled(value: bool) -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() != owner_peer_id:
		return
	_set_subsystems_active(value)

func _physics_process(_delta: float) -> void:
	if not _is_controlled or multiplayer.is_server() or not _is_owning_peer():
		return
	if not NetworkManager.is_networked():
		return
	var fwd := _deadzone(Input.get_axis("RobotBack", "RobotForward"))
	var strafe := _deadzone(Input.get_axis("RobotLeft", "RobotRight"))
	var rot := _deadzone(Input.get_axis("RobotRotateLeft", "RobotRotateRight"))
	_rpc_relay_drive.rpc_id(1, fwd, strafe, rot)

func _deadzone(value: float, threshold: float = 0.1) -> float:
	if absf(value) < threshold:
		return 0.0
	return signf(value) * (absf(value) - threshold) / (1.0 - threshold)

@rpc("any_peer", "call_remote", "unreliable_ordered")
func _rpc_relay_drive(fwd: float, strafe: float, rot: float) -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() != owner_peer_id:
		return
	var swerve := _get_swerve()
	if swerve:
		swerve.drive(fwd, strafe, rot)

func _get_swerve() -> SwerveSubsystem:
	var manager := get_subsystem_manager()
	if manager:
		return manager.get_subsystem(SwerveSubsystem) as SwerveSubsystem
	return null

func _get_manager() -> SubsystemManager:
	return get_node_or_null("SubsystemManager") as SubsystemManager

func _unhandled_input(event: InputEvent) -> void:
	if not _is_owning_peer():
		return
	if event.is_action_pressed("RobotSubsystemRight"):
		_trigger_action(RobotAction.FIRE_SHOOTER)
	if event.is_action_pressed("RobotSubsystemLeft"):
		_trigger_action(RobotAction.INTAKE_START)
	if event.is_action_released("RobotSubsystemLeft"):
		_trigger_action(RobotAction.INTAKE_STOP)
	if event.is_action_pressed("RobotSubsystemUp"):
		_trigger_action(RobotAction.ARM_UP)
	if event.is_action_pressed("RobotSubsystemDown"):
		_trigger_action(RobotAction.ARM_DOWN)

enum RobotAction { FIRE_SHOOTER, INTAKE_START, INTAKE_STOP, ARM_UP, ARM_DOWN }

func _trigger_action(action: RobotAction) -> void:
	if multiplayer.is_server():
		_run_action(action)
	elif NetworkManager.is_networked():
		_rpc_relay_action.rpc_id(1, action)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_relay_action(action: int) -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() != owner_peer_id:
		return
	_run_action(action)

func _run_action(action: int) -> void:
	match action:
		RobotAction.FIRE_SHOOTER:
			var manager := _get_manager()
			if manager:
				var shooter = manager.get_subsystem_by_id("Shooter")
				CommandScheduler.schedule(
					CommandGroup.parallel()
						.add(FireShooter.new(shooter, 4))
				)
		RobotAction.INTAKE_START:
			var manager: SubsystemManager = _get_manager()
			if manager:
				var intake = manager.get_subsystem_by_id("Intake")
				CommandScheduler.schedule(
					RunIntake.new(intake, false, false)
				)
		RobotAction.INTAKE_STOP:
			var manager: SubsystemManager = _get_manager()
			if manager:
				var intake = manager.get_subsystem_by_id("Intake")
				CommandScheduler.schedule(
					StopIntake.new(intake)
				)
		RobotAction.ARM_UP:
			var manager: SubsystemManager = _get_manager()
			if manager:
				var arm = manager.get_subsystem_by_id("Arm")
				var elevator = manager.get_subsystem_by_id("Elevator")
				if arm and elevator:
					CommandScheduler.schedule(
						CommandGroup.parallel()
							.add(SetElevatorHeight.new(elevator, 0.4))
							.add(SetArmAngle.new(arm, -80))
					)
		RobotAction.ARM_DOWN:
			var manager: SubsystemManager = _get_manager()
			if manager:
				var arm = manager.get_subsystem_by_id("Arm")
				var elevator = manager.get_subsystem_by_id("Elevator")
				if arm and elevator:
					CommandScheduler.schedule(
						CommandGroup.parallel()
							.add(SetElevatorHeight.new(elevator, 0))
							.add(SetArmAngle.new(arm, 30))
					)
