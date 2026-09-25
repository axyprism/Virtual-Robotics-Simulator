class_name HoldElevatorHeight
extends Command

var _elevator: ElevatorSubsystem

func _init(elevator: ElevatorSubsystem) -> void:
	_elevator = elevator
	require(elevator)

func on_start() -> void:
	_elevator.hold_current()

func on_update(_delta: float) -> void:
	pass

func on_end(_interrupted: bool) -> void:
	pass

func is_finished() -> bool:
	return _elevator.at_target()
