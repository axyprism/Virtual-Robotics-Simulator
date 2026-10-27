class_name ReefscapeRobot
extends BaseRobot

enum ScoreState { INTAKE, L1, L2, L3, L4, ALGAE_NET }

var _is_controlled: bool = false
var _teleop_command: DriveTeleopCommand = null
var owner_peer_id: int = -1
var _score_state: ScoreState = ScoreState.INTAKE

func _ready() -> void:
	set_controlled(false)

func set_owner_peer_id(id: int) -> void:
	owner_peer_id = id

func _is_owning_peer() -> bool:
	return owner_peer_id == multiplayer.get_unique_id()

func is_owned_by_local_peer() -> bool:
	return _is_owning_peer()

func get_robot_name() -> String:
	return "Reefscape Robot"

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
	if event.is_action_pressed("RobotSubsystemDown"):
		_step_state(-1)
	if event.is_action_pressed("RobotSubsystemUp"):
		_step_state(1)
	if event.is_action_pressed("RobotSubsystemLeft"):
		var manager = _get_manager()
		if manager:
			var intake = manager.get_subsystem_by_id("Claw")
			CommandScheduler.schedule(RunIntake.new(intake, false, true))
	if event.is_action_pressed("RobotTriggerLeft"):
		var manager = _get_manager()
		if manager:
			var intakeArm = manager.get_subsystem_by_id("IntakeArm")
			var intakeArm2 = manager.get_subsystem_by_id("IntakeArm2")
			CommandScheduler.schedule(CommandGroup.parallel().add(SetArmAngle.new(intakeArm, 60.0)).add(SetArmAngle.new(intakeArm2, 120.0)))
	if event.is_action_pressed("RobotTriggerRight"):
		var manager = _get_manager()
		if manager:
			var intakeArm = manager.get_subsystem_by_id("IntakeArm")
			var intakeArm2 = manager.get_subsystem_by_id("IntakeArm2")
			CommandScheduler.schedule(CommandGroup.parallel().add(SetArmAngle.new(intakeArm, 0.0)).add(SetArmAngle.new(intakeArm2, 180.0)))
			
	if event.is_action_pressed("RobotSubsystemRight"):
		var manager = _get_manager()
		if manager:
			var intake = manager.get_subsystem_by_id("Claw")
			CommandScheduler.schedule(RunIntake.new(intake, true, false))
	if event.is_action_released("RobotSubsystemRight") or event.is_action_released("RobotSubsystemLeft"):
		var manager = _get_manager()
		if manager:
			var intake = manager.get_subsystem_by_id("Claw")
			CommandScheduler.schedule(StopIntake.new(intake))

func _step_state(direction: int) -> void:
	var next := clampi(_score_state + direction, ScoreState.INTAKE, ScoreState.ALGAE_NET)
	if next == _score_state:
		return
	_score_state = next as ScoreState
	_apply_state()

func _apply_state() -> void:
	var command = _get_state_command(_score_state)
	if command:
		CommandScheduler.schedule(command)

func _get_state_command(state: ScoreState):
	match state:
		ScoreState.INTAKE:
			return _command_intake()
		ScoreState.L1:
			return _command_l1()
		ScoreState.L2:
			return _command_l2()
		ScoreState.L3:
			return _command_l3()
		ScoreState.L4:
			return _command_l4()
		ScoreState.ALGAE_NET:
			return _command_algae_net()
	return null

func _command_intake():
	var manager := _get_manager()
	if manager:
		var elevator1 = manager.get_subsystem_by_id("Elevator1")
		var elevator2 = manager.get_subsystem_by_id("Elevator2")
		var elevator3 = manager.get_subsystem_by_id("Elevator3")
		var arm = manager.get_subsystem_by_id("Arm")
		return CommandGroup.parallel().add(SetElevatorHeight.new(elevator1, 0)).add(SetElevatorHeight.new(elevator2, 0)).add(SetElevatorHeight.new(elevator3, 1)).add(SetArmAngle.new(arm, -180))
		

func _command_l1():
	var manager := _get_manager()
	if manager:
		var elevator1 = manager.get_subsystem_by_id("Elevator1")
		var elevator2 = manager.get_subsystem_by_id("Elevator2")
		var elevator3 = manager.get_subsystem_by_id("Elevator3")
		var arm = manager.get_subsystem_by_id("Arm")
		return CommandGroup.parallel().add(SetElevatorHeight.new(elevator1, .1)).add(SetElevatorHeight.new(elevator2, .1)).add(SetElevatorHeight.new(elevator3, .1)).add(SetArmAngle.new(arm, -90))

func _command_l2():
	var manager := _get_manager()
	if manager:
		var elevator1 = manager.get_subsystem_by_id("Elevator1")
		var elevator2 = manager.get_subsystem_by_id("Elevator2")
		var elevator3 = manager.get_subsystem_by_id("Elevator3")
		var arm = manager.get_subsystem_by_id("Arm")
		return CommandGroup.parallel().add(SetElevatorHeight.new(elevator1, 0.08)).add(SetElevatorHeight.new(elevator2, 0.08)).add(SetElevatorHeight.new(elevator3, 0.08)).add(SetArmAngle.new(arm, -60))

func _command_l3():
	var manager := _get_manager()
	if manager:
		var elevator1 = manager.get_subsystem_by_id("Elevator1")
		var elevator2 = manager.get_subsystem_by_id("Elevator2")
		var elevator3 = manager.get_subsystem_by_id("Elevator3")
		var arm = manager.get_subsystem_by_id("Arm")
		return CommandGroup.parallel().add(SetElevatorHeight.new(elevator1, 0.2)).add(SetElevatorHeight.new(elevator2, 0.2)).add(SetElevatorHeight.new(elevator3, 0.2)).add(SetArmAngle.new(arm, -60))

func _command_l4():
	var manager := _get_manager()
	if manager:
		var elevator1 = manager.get_subsystem_by_id("Elevator1")
		var elevator2 = manager.get_subsystem_by_id("Elevator2")
		var elevator3 = manager.get_subsystem_by_id("Elevator3")
		var arm = manager.get_subsystem_by_id("Arm")
		return CommandGroup.parallel().add(SetElevatorHeight.new(elevator1, 0.47)).add(SetElevatorHeight.new(elevator2, 0.47)).add(SetElevatorHeight.new(elevator3, 0.47)).add(SetArmAngle.new(arm, -70))

func _command_algae_net():
	var manager := _get_manager()
	if manager:
		var elevator1 = manager.get_subsystem_by_id("Elevator1")
		var elevator2 = manager.get_subsystem_by_id("Elevator2")
		var elevator3 = manager.get_subsystem_by_id("Elevator3")
		var arm = manager.get_subsystem_by_id("Arm")
		return CommandGroup.parallel().add(SetElevatorHeight.new(elevator1, 1)).add(SetElevatorHeight.new(elevator2, 1)).add(SetElevatorHeight.new(elevator3, 1)).add(SetArmAngle.new(arm, 0))
