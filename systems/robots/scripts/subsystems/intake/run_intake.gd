class_name RunIntake
extends Command

var _intake: IntakeSubsystem
var _eject: bool
var _stop_on_pickup: bool

func _init(intake: IntakeSubsystem,
		eject: bool = false, stop_on_pickup: bool = true) -> void:
	_intake         = intake
	_eject          = eject
	_stop_on_pickup = stop_on_pickup and intake.hold_enabled
	require(intake)

func on_start() -> void:
	if _eject:
		_intake.eject()
	else:
		_intake.intake()

func on_update(_delta: float) -> void:
	if not _intake.hold_enabled:
		if _eject:
			_intake.eject()
		else:
			_intake.intake()

func on_end(interrupted: bool) -> void:
	_intake.stop()

func is_finished() -> bool:
	if _eject:
		return false
	if _stop_on_pickup and _intake.has_game_piece():
		return true
	return false
