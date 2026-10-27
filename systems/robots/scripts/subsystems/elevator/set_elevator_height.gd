class_name SetElevatorHeight
extends Command

var _elevator: ElevatorSubsystem
var _target: float

static func describe() -> Array[Dictionary]:
	return [
		{"name": "elevator", "type": "subsystem", "class": ElevatorSubsystem},
		{"name": "height", "type": "float", "default": 0.0},
	]

func _init(elevator: ElevatorSubsystem, height: float) -> void:
	_elevator = elevator
	_target = height
	require(elevator)

func on_start() -> void:
	_elevator.set_height(_target)

func on_update(_delta: float) -> void:
	pass

func on_end(_interrupted: bool) -> void:
	_elevator.hold_current()

func is_finished() -> bool:
	return _elevator.at_target()
