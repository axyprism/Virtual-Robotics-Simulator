class_name WristSubsystem
extends Subsystem

@onready var joint: Node3D = $WristJoint

var _target_angle: float = 0.0
var _arm_compensation: float = 0.0

func set_angle(deg: float) -> void:
	_target_angle = deg

## Called by parent arm to counteract arm rotation so wrist stays level
func set_world_angle_compensation(arm_angle_deg: float) -> void:
	_arm_compensation = -arm_angle_deg

func update(delta: float) -> void:
	var final_angle = _target_angle + _arm_compensation
	joint.rotation.x = lerp_angle(
		joint.rotation.x, deg_to_rad(final_angle), delta * 8.0
	)
