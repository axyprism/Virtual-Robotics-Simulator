class_name ShooterSubsystem
extends Subsystem

## Child subsystems — must exist as child nodes in the scene
@onready var flywheel: FlywheelSubsystem = $FlywheelSubsystem
@onready var feeder: FeederSubsystem     = $FeederSubsystem

## If true, the feeder will only run once the flywheel is at speed
## Set false if you want to feed regardless (e.g. for testing)
@export var wait_for_flywheel: bool = true

## Default flywheel speed for a normal shot (can be overridden per-shot)
@export var default_shot_speed: float = 1.0

## Emitted when a shot is actually fired (feeder detects game piece leaving)
signal shot_fired

enum State {
	IDLE,           ## Nothing happening
	SPINNING_UP,    ## Flywheel ramping up, waiting to reach speed
	READY,          ## At speed, waiting for feed command
	FEEDING,        ## Actively feeding game piece into flywheel
	REVERSING,      ## Unjamming
}

var state: State = State.IDLE

# --- Public API ---

## Spin up the flywheel in preparation for a shot
func prime(speed: float = -1.0) -> void:
	var target := default_shot_speed if speed < 0.0 else speed
	flywheel.spin_up(target)
	_set_state(State.SPINNING_UP)

## Feed the game piece — will wait for flywheel if wait_for_flywheel is true
func fire() -> void:
	if not wait_for_flywheel or flywheel.at_speed():
		feeder.feed()
		_set_state(State.FEEDING)
	else:
		# Arm the feed — update() will pull the trigger when ready
		_set_state(State.SPINNING_UP)

## Convenience: spin up AND fire in one call
func prime_and_fire(speed: float = -1.0) -> void:
	prime(speed)
	fire()

## Stop everything
func stop() -> void:
	flywheel.spin_down()
	feeder.stop()
	_set_state(State.IDLE)

## Reverse the feeder to clear a jam
func unjam() -> void:
	feeder.reverse()
	_set_state(State.REVERSING)

## True when flywheel is at speed and game piece is staged
func ready_to_fire() -> bool:
	return flywheel.at_speed() and feeder.has_game_piece

## True when no game piece is staged and flywheel is stopped
func is_idle() -> bool:
	return state == State.IDLE

# --- Internal ---

func _ready() -> void:
	# Forward feeder signals up so callers can listen on the shooter directly
	feeder.game_piece_fired.connect(_on_game_piece_fired)

@warning_ignore("unused_parameter")
func update(delta: float) -> void:
	match state:
		State.SPINNING_UP:
			# If we were waiting for flywheel speed before feeding, pull trigger now
			if flywheel.at_speed():
				feeder.feed()
				_set_state(State.FEEDING)

		State.FEEDING:
			# If game piece has left and feeder is still running, stop the feed
			if not feeder.has_game_piece and feeder.is_feeding():
				feeder.stop()
				# Keep flywheel spinning so next shot is faster
				_set_state(State.READY)

		State.REVERSING:
			pass  # Caller must call stop() manually or use a timed command

		State.READY, State.IDLE:
			pass

func run_default(_delta: float) -> void:
	stop()

func _on_game_piece_fired() -> void:
	shot_fired.emit()

func _set_state(new_state: State) -> void:
	if state != new_state:
		state = new_state
