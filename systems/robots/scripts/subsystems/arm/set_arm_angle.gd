class_name SetArmAngle
extends Command

var _arm:    ArmSubsystem
var _target: float

func _init(arm: ArmSubsystem, angle_deg: float) -> void:
	_arm    = arm
	_target = angle_deg
	require(arm)

func on_start() -> void:
	_arm.set_angle(_target)

func is_finished() -> bool:
	return _arm.at_target()
