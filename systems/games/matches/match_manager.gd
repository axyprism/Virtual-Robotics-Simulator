extends Node

enum Phase { PRE_MATCH, AUTONOMOUS, TELEOP, POST_MATCH }

signal phase_changed(new_phase: Phase)
signal time_updated(time_left: float)
signal match_ended
signal gap_time_updated(time_left: float)
signal gap_finished

var current_phase: Phase = Phase.PRE_MATCH
var time_left: float = 0.0
var running: bool = false

var match_gap_seconds: float = 15.0
var in_gap: bool = false
var gap_time_left: float = 0.0

var autonomous_time: float = 15.0
var teleop_time: float = 135.0
var endgame_time: float = 30.0

var _spawner: RobotSpawner = null

func register_spawner(spawner: RobotSpawner) -> void:
	_spawner = spawner

func _ready() -> void:
	NetworkManager.player_connected.connect(_on_peer_connected)

func _on_peer_connected(peer_id: int) -> void:
	if NetworkManager.is_networked() and multiplayer.is_server() and running:
		_rpc_sync_state.rpc_id(peer_id, current_phase, time_left, autonomous_time, teleop_time, endgame_time)

func start_match() -> void:
	if in_gap:
		push_warning("MatchManager: still in the between-match pause (%.1fs left)" % gap_time_left)
		return
	if NetworkManager.is_networked() and multiplayer.is_server():
		_rpc_start_match.rpc()
		GameManager.current_field.reset_field()
	else:
		_begin_match()

@rpc("authority", "call_local", "reliable")
func _rpc_start_match() -> void:
	_begin_match()

@rpc("authority", "call_remote", "reliable")
func _rpc_sync_state(phase: int, t: float, auto_t: float, teleop_t: float, endgame_t: float) -> void:
	autonomous_time = auto_t
	teleop_time = teleop_t
	endgame_time = endgame_t
	current_phase = phase as Phase
	time_left = t
	running = true
	emit_signal("phase_changed", current_phase)

func _begin_match() -> void:
	in_gap = false
	var game := GameManager.current_game
	if game != null:
		autonomous_time = game.autonomous_time
		teleop_time = game.teleop_time
		endgame_time = game.endgame_time
	
	current_phase = Phase.AUTONOMOUS
	time_left = autonomous_time
	running = true
	emit_signal("phase_changed", current_phase)
	_spawn_match_robots()

func _spawn_match_robots() -> void:
	if not multiplayer.is_server():
		return
	if _spawner == null:
		push_warning("MatchManager: no RobotSpawner registered")
		return
	var match_info = MatchScheduler.get_current_match()
	if match_info == null:
		push_warning("MatchManager: no current match, nobody to spawn")
		return
	var assignments: Array = []
	for alliance in ["red", "blue"]:
		for peer_id in match_info[alliance]:
			var profile: Dictionary = NetworkManager.player_profiles.get(peer_id, {})
			var robot_name: String = profile.get("robot", "")
			if robot_name.is_empty():
				push_warning("MatchManager: peer %d has no robot selected" % peer_id)
				continue
			assignments.append({
				"peer_id": peer_id,
				"scene_name": robot_name,
				"alliance": alliance,
			})
	_spawner.spawn_match_robots(assignments)

func stop_match() -> void:
	running = false
	current_phase = Phase.POST_MATCH
	emit_signal("phase_changed", current_phase)
	emit_signal("match_ended")
	in_gap = true
	if GameManager.current_scoring:
		GameManager.current_scoring.reset()
	gap_time_left = match_gap_seconds
	emit_signal("gap_time_updated", gap_time_left)

func _process(delta: float) -> void:
	if in_gap:
		gap_time_left -= delta
		if gap_time_left <= 0.0:
			in_gap = false
			gap_time_left = 0.0
			emit_signal("gap_finished")
		else:
			emit_signal("gap_time_updated", gap_time_left)

	if not running:
		return
	time_left -= delta
	emit_signal("time_updated", time_left)
	if time_left <= 0.0:
		_advance_phase()

func _advance_phase() -> void:
	match current_phase:
		Phase.AUTONOMOUS:
			current_phase = Phase.TELEOP
			time_left = teleop_time
			emit_signal("phase_changed", current_phase)
		Phase.TELEOP:
			stop_match()
		_:
			pass

func is_endgame() -> bool:
	return current_phase == Phase.TELEOP and time_left <= endgame_time
