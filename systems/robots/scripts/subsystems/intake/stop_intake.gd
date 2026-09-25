class_name StopIntake
extends Command

var _intake: IntakeSubsystem

func _init(intake: IntakeSubsystem) -> void:
	_intake = intake
	require(intake)

func on_start() -> void:
	_intake.stop()

func on_update(_delta: float) -> void:
	return

func on_end(interrupted: bool) -> void:
	return

func is_finished() -> bool:
	return true
