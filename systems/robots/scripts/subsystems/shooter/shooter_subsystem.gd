class_name ShooterSubsystem
extends Subsystem

@export var flywheel: FlywheelSubsystem
@export var feeder: FeederSubsystem

@export var wait_for_flywheel: bool = true

@export var default_shot_speed: float = 1.0

signal shot_fired

enum State {
	IDLE,
	SPINNING_UP,
	READY,
	FEEDING,
	REVERSING, 
}

var state: State = State.IDLE

func prime(speed: float = -1.0) -> void:
	var target := default_shot_speed if speed < 0.0 else speed
	flywheel.spin_up(target)
	_set_state(State.SPINNING_UP)

func fire() -> void:
	if not wait_for_flywheel or flywheel.at_speed():
		feeder.feed()
		_set_state(State.FEEDING)
	else:
		_set_state(State.SPINNING_UP)

func prime_and_fire(speed: float = -1.0) -> void:
	prime(speed)
	fire()

func stop() -> void:
	flywheel.spin_down()
	feeder.stop()
	_set_state(State.IDLE)

func unjam() -> void:
	feeder.reverse()
	_set_state(State.REVERSING)

func ready_to_fire() -> bool:
	return flywheel.at_speed() and feeder.has_game_piece

func is_idle() -> bool:
	return state == State.IDLE

func _ready() -> void:
	feeder.game_piece_fired.connect(_on_game_piece_fired)

@warning_ignore("unused_parameter")
func update(delta: float) -> void:
	match state:
		State.SPINNING_UP:
			if flywheel.at_speed():
				feeder.feed()
				_set_state(State.FEEDING)
		State.FEEDING:
			if not feeder.has_game_piece and feeder.is_feeding():
				feeder.stop()
				_set_state(State.READY)
		State.REVERSING:
			pass
		State.READY, State.IDLE:
			pass

func run_default(_delta: float) -> void:
	stop()

func _on_game_piece_fired() -> void:
	shot_fired.emit()

func _set_state(new_state: State) -> void:
	if state != new_state:
		state = new_state
