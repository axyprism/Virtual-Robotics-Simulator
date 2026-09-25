extends Node
class_name RebuiltScoring

signal hub_active_changed(alliance: String, active: bool)
signal fuel_progress_changed(alliance: String, fuel_scored: int)
signal tower_points_changed(alliance: String, points: int)
signal shift_changed(segment_index: int, segment_name: String, time_left: float)

const TRANSITION_DURATION := 10.0
const SHIFT_DURATION := 25.0
const NUM_SHIFTS := 4
const SEGMENT_NAMES := ["Transition", "Shift 1", "Shift 2", "Shift 3", "Shift 4", "Endgame"]

const ENERGIZED_THRESHOLD := 100
const SUPERCHARGED_THRESHOLD := 360
const TRAVERSAL_THRESHOLD := 50

var auto_winner: String = ""

var _fuel_scored := { "red": 0, "blue": 0 }
var _auto_fuel := { "red": 0, "blue": 0 }
var _tower_points := { "red": 0, "blue": 0 }
var _hub_active := { "red": true, "blue": true }
var _last_segment_index := -1

func _ready() -> void:
	ScoringManager.reset_scores()
	MatchManager.phase_changed.connect(_on_phase_changed)
	MatchManager.time_updated.connect(_on_time_updated)
	if NetworkManager.is_networked() and not multiplayer.is_server():
		_request_state_sync.rpc_id(1)

func _can_trigger_scoring() -> bool:
	return not NetworkManager.is_networked() or multiplayer.is_server()

func _on_phase_changed(phase: int) -> void:
	match phase:
		MatchManager.Phase.AUTONOMOUS:
			_set_hub_active("red", true)
			_set_hub_active("blue", true)
		MatchManager.Phase.TELEOP:
			auto_winner = _determine_auto_winner()
			_last_segment_index = -1

func _determine_auto_winner() -> String:
	if _auto_fuel["red"] > _auto_fuel["blue"]:
		return "red"
	elif _auto_fuel["blue"] > _auto_fuel["red"]:
		return "blue"
	return ""

func _on_time_updated(_time_left: float) -> void:
	if MatchManager.current_phase != MatchManager.Phase.TELEOP:
		return

	var elapsed := MatchManager.teleop_time - _time_left
	var endgame_start := MatchManager.teleop_time - MatchManager.endgame_time

	if elapsed >= endgame_start:
		_set_hub_active("red", true)
		_set_hub_active("blue", true)
		_report_segment(5, endgame_start + MatchManager.endgame_time - elapsed)
		return

	if elapsed < TRANSITION_DURATION:
		_set_hub_active("red", true)
		_set_hub_active("blue", true)
		_report_segment(0, TRANSITION_DURATION - elapsed)
		return

	var shift_elapsed := elapsed - TRANSITION_DURATION
	var shift_index: int = clampi(int(shift_elapsed / SHIFT_DURATION), 0, NUM_SHIFTS - 1)
	var winner_active := (shift_index % 2 == 1)

	if auto_winner == "":
		_set_hub_active("red", true)
		_set_hub_active("blue", true)
	else:
		var loser := "blue" if auto_winner == "red" else "red"
		_set_hub_active(auto_winner, winner_active)
		_set_hub_active(loser, not winner_active)

	var shift_time_left := TRANSITION_DURATION + (shift_index + 1) * SHIFT_DURATION - elapsed
	_report_segment(shift_index + 1, shift_time_left)

func _report_segment(index: int, time_left: float) -> void:
	if index != _last_segment_index:
		_last_segment_index = index
	shift_changed.emit(index + 1, SEGMENT_NAMES[index], time_left)

func _set_hub_active(alliance: String, active: bool) -> void:
	if _hub_active[alliance] == active:
		return
	_hub_active[alliance] = active
	hub_active_changed.emit(alliance, active)

func is_hub_active(alliance: String) -> bool:
	return _hub_active.get(alliance, true)

func score_fuel(alliance: String) -> void:
	if not _can_trigger_scoring():
		return
	if not MatchManager.running:
		return
	if NetworkManager.is_networked():
		_apply_score_fuel.rpc(alliance)
	else:
		_apply_score_fuel(alliance)

@rpc("authority", "call_local", "reliable")
func _apply_score_fuel(alliance: String) -> void:
	if MatchManager.current_phase == MatchManager.Phase.AUTONOMOUS:
		_auto_fuel[alliance] += 1

	if not is_hub_active(alliance):
		return 

	_fuel_scored[alliance] += 1
	ScoringManager.add_score(alliance, "fuel")
	fuel_progress_changed.emit(alliance, _fuel_scored[alliance])

func climb(alliance: String, level: int) -> void:
	if not _can_trigger_scoring():
		return
	if not MatchManager.running:
		return
	if NetworkManager.is_networked():
		_apply_climb.rpc(alliance, level)
	else:
		_apply_climb(alliance, level)

@rpc("authority", "call_local", "reliable")
func _apply_climb(alliance: String, level: int) -> void:
	var key := ""
	if MatchManager.current_phase == MatchManager.Phase.AUTONOMOUS:
		if level != 1:
			push_warning("RebuiltScoring: only Level 1 climbs are legal during auto")
			return
		key = "climb_auto_level1"
	else:
		match level:
			1: key = "climb_teleop_level1"
			2: key = "climb_teleop_level2"
			3: key = "climb_teleop_level3"
			_:
				push_warning("RebuiltScoring: invalid climb level %d" % level)
				return

	ScoringManager.add_score(alliance, key)
	_tower_points[alliance] += GameManager.current_game.point_values.get(key, 0)
	tower_points_changed.emit(alliance, _tower_points[alliance])

func get_fuel_scored(alliance: String) -> int:
	return _fuel_scored.get(alliance, 0)

func reset() -> void:
	_fuel_scored = { "red": 0, "blue": 0 }
	_auto_fuel = { "red": 0, "blue": 0 }
	_tower_points = { "red": 0, "blue": 0 }
	_hub_active = { "red": true, "blue": true }
	_last_segment_index = -1
	auto_winner = ""
	ScoringManager.reset_scores()
	fuel_progress_changed.emit("red", 0)
	fuel_progress_changed.emit("blue", 0)
	tower_points_changed.emit("red", 0)
	tower_points_changed.emit("blue", 0)
	hub_active_changed.emit("red", true)
	hub_active_changed.emit("blue", true)

func get_tower_points(alliance: String) -> int:
	return _tower_points.get(alliance, 0)

func has_energized(alliance: String) -> bool:
	return get_fuel_scored(alliance) >= ENERGIZED_THRESHOLD

func has_supercharged(alliance: String) -> bool:
	return get_fuel_scored(alliance) >= SUPERCHARGED_THRESHOLD

func has_traversal(alliance: String) -> bool:
	return get_tower_points(alliance) >= TRAVERSAL_THRESHOLD

@rpc("any_peer", "call_remote", "reliable")
func _request_state_sync() -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	_apply_state_snapshot.rpc_id(sender,
		ScoringManager.get_score("red"), ScoringManager.get_score("blue"),
		_fuel_scored["red"], _fuel_scored["blue"],
		_tower_points["red"], _tower_points["blue"],
		auto_winner, _hub_active["red"], _hub_active["blue"])

@rpc("authority", "call_remote", "reliable")
func _apply_state_snapshot(red_score: int, blue_score: int, red_fuel: int, blue_fuel: int,
		red_tower: int, blue_tower: int, winner: String, red_hub: bool, blue_hub: bool) -> void:
	ScoringManager.scores["red"] = red_score
	ScoringManager.scores["blue"] = blue_score
	ScoringManager.score_changed.emit("red", red_score)
	ScoringManager.score_changed.emit("blue", blue_score)
	_fuel_scored["red"] = red_fuel
	_fuel_scored["blue"] = blue_fuel
	_tower_points["red"] = red_tower
	_tower_points["blue"] = blue_tower
	auto_winner = winner
	_hub_active["red"] = red_hub
	_hub_active["blue"] = blue_hub
	fuel_progress_changed.emit("red", red_fuel)
	fuel_progress_changed.emit("blue", blue_fuel)
	tower_points_changed.emit("red", red_tower)
	tower_points_changed.emit("blue", blue_tower)
