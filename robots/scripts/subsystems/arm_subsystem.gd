class_name ArmSubsystem
extends Subsystem

@onready var wrist: WristSubsystem = $WristSubsystem
@onready var joint: Node3D = $ArmJoint

var _target_angle: float = 0.0

func set_angle(deg: float) -> void:
	_target_angle = deg

func get_angle() -> float:
	return rad_to_deg(joint.rotation.x)

func update(delta: float) -> void:
	joint.rotation.x = lerp_angle(
		joint.rotation.x, deg_to_rad(_target_angle), delta * 5.0
	)
	wrist.set_world_angle_compensation(get_angle())
