# fire_shooter.gd
class_name FireShooter
extends Command

var _shooter: ShooterSubsystem
var _duration: float
var _elapsed: float = 0.0

func _init(shooter: ShooterSubsystem, duration: float = 1.0) -> void:
	_shooter = shooter
	_duration = duration
	require(shooter)

func on_start() -> void:
	_elapsed = 0.0
	_shooter.fire()

func on_update(delta: float) -> void:
	_elapsed += delta

@warning_ignore("unused_parameter")
func on_end(interrupted: bool) -> void:
	_shooter.stop()

func is_finished() -> bool:
	return _elapsed >= _duration
