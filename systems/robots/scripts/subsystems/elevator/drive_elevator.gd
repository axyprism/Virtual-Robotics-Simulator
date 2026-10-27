class_name DriveElevator
extends Command

var _elevator: ElevatorSubsystem
var _speed: float

func _init(elevator: ElevatorSubsystem, speed: float) -> void:
	_elevator = elevator
	_speed = speed
	require(elevator)

func on_update(_delta: float) -> void:
	if absf(_speed) > 0.05:
		_elevator.drive_manual(_speed)
	else:
		if _elevator.state == ElevatorSubsystem.ElevatorState.MANUAL:
			_elevator.hold_current()

func on_end(_interrupted: bool) -> void:
	_elevator.hold_current()

func is_finished() -> bool:
	return false
