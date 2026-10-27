class_name ExportedRobot
extends BaseRobot

var owner_peer_id: int = -1
var is_controlled: bool = false
var teleop_command: DriveTeleopCommand = null


func _ready() -> void:
	set_controlled(false)


func set_owner_peer_id(id: int) -> void:
	owner_peer_id = id


func is_owned_by_local_peer() -> bool:
	return owner_peer_id == multiplayer.get_unique_id()


func set_controlled(value: bool) -> void:
	is_controlled = value
	var swerve := get_swerve()
	if not swerve:
		return
	if value and multiplayer.is_server():
		teleop_command = DriveTeleopCommand.new(swerve)
		CommandScheduler.schedule(teleop_command, self)
	elif not value and teleop_command:
		CommandScheduler.cancel(teleop_command)
		teleop_command = null
	set_subsystems_active(value)
	if not multiplayer.is_server() and NetworkManager.is_networked():
		rpc_relay_set_controlled.rpc_id(1, value)


func set_subsystems_active(value: bool) -> void:
	var manager := get_subsystem_manager()
	if manager:
		for s in manager.get_all():
			s.set_active(value)


@rpc("any_peer", "call_remote", "reliable")
func rpc_relay_set_controlled(value: bool) -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() != owner_peer_id:
		return
	set_subsystems_active(value)


func _physics_process(_delta: float) -> void:
	if not is_controlled or multiplayer.is_server() or not is_owned_by_local_peer():
		return
	if not NetworkManager.is_networked():
		return
	var fwd := deadzone(Input.get_axis("RobotBack", "RobotForward"))
	var strafe := deadzone(Input.get_axis("RobotLeft", "RobotRight"))
	var rot := deadzone(Input.get_axis("RobotRotateLeft", "RobotRotateRight"))
	rpc_relay_drive.rpc_id(1, fwd, strafe, rot)


func deadzone(value: float, threshold: float = 0.1) -> float:
	if absf(value) < threshold:
		return 0.0
	return signf(value) * (absf(value) - threshold) / (1.0 - threshold)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func rpc_relay_drive(fwd: float, strafe: float, rot: float) -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() != owner_peer_id:
		return
	var swerve := get_swerve()
	if swerve:
		swerve.drive(fwd, strafe, rot)


func get_swerve() -> SwerveSubsystem:
	var manager := get_subsystem_manager()
	if manager:
		return manager.get_subsystem(SwerveSubsystem) as SwerveSubsystem
	return null
