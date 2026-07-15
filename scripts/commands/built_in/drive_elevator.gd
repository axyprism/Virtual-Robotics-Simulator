class_name DriveElevatorCommand
extends Command

var _elevator:    ElevatorSubsystem
var _speed_func:  Callable

func _init(elevator: ElevatorSubsystem, speed_func: Callable) -> void:
	_elevator   = elevator
	_speed_func = speed_func
	require(elevator)

func on_update(_delta: float) -> void:
	var speed: float = _speed_func.call()
	if absf(speed) > 0.05:
		_elevator.drive_manual(speed)
	else:
		if _elevator.state == ElevatorSubsystem.ElevatorState.MANUAL:
			_elevator.hold_current()

func on_end(_interrupted: bool) -> void:
	_elevator.hold_current()

func is_finished() -> bool:
	return false
