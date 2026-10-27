extends Node
class_name ReefscapeScoring

signal coral_scored_changed(alliance: String, level: int, count: int)
signal algae_scored_changed(alliance: String, destination: String, count: int)
signal barge_points_changed(alliance: String, points: int)
signal leave_changed(alliance: String, left: bool)
signal coral_rp_changed(alliance: String, achieved: bool)
signal barge_rp_changed(alliance: String, achieved: bool)

const CORAL_AUTO_POINTS := { 1: 3, 2: 4, 3: 6, 4: 7 }
const CORAL_TELEOP_POINTS := { 1: 2, 2: 3, 3: 4, 4: 5 }
const ALGAE_PROCESSOR_POINTS := 6
const ALGAE_NET_POINTS := 4
const LEAVE_POINTS := 3
const PARK_POINTS := 2
const SHALLOW_CLIMB_POINTS := 6
const DEEP_CLIMB_POINTS := 12

const CORAL_RP_LEVEL_THRESHOLD := 5
const CORAL_RP_LEVELS_REQUIRED := 4
const CORAL_RP_LEVELS_REQUIRED_COOP := 3
const COOP_PROCESSOR_THRESHOLD := 2
const BARGE_RP_THRESHOLD := 14

var _coral_count := {
	"red": { 1: 0, 2: 0, 3: 0, 4: 0 },
	"blue": { 1: 0, 2: 0, 3: 0, 4: 0 }
}
var _algae_processor := { "red": 0, "blue": 0 }
var _algae_net := { "red": 0, "blue": 0 }
var _barge_points := { "red": 0, "blue": 0 }
var _has_left := { "red": false, "blue": false }
var _coral_rp := { "red": false, "blue": false }
var _barge_rp := { "red": false, "blue": false }

func _ready() -> void:
	ScoringManager.reset_scores()
	if NetworkManager.is_networked() and not multiplayer.is_server():
		_request_state_sync.rpc_id(1)

func _can_trigger_scoring() -> bool:
	return not NetworkManager.is_networked() or multiplayer.is_server()

func score_coral(alliance: String, level: int) -> void:
	if not _can_trigger_scoring():
		return
	if not MatchManager.running:
		return
	if not CORAL_AUTO_POINTS.has(level):
		push_warning("ReefscapeScoring: invalid coral level %d" % level)
		return
	if NetworkManager.is_networked():
		_apply_score_coral.rpc(alliance, level)
	else:
		_apply_score_coral(alliance, level)

@rpc("authority", "call_local", "reliable")
func _apply_score_coral(alliance: String, level: int) -> void:
	var points: int
	if MatchManager.current_phase == MatchManager.Phase.AUTONOMOUS:
		points = CORAL_AUTO_POINTS[level]
	else:
		points = CORAL_TELEOP_POINTS[level]

	ScoringManager.add_points(alliance, points)
	_coral_count[alliance][level] += 1
	coral_scored_changed.emit(alliance, level, _coral_count[alliance][level])
	_update_coral_rp("red")
	_update_coral_rp("blue")

func score_algae(alliance: String, destination: String) -> void:
	if not _can_trigger_scoring():
		return
	if not MatchManager.running:
		return
	if destination != "processor" and destination != "net":
		push_warning("ReefscapeScoring: invalid algae destination %s" % destination)
		return
	if NetworkManager.is_networked():
		_apply_score_algae.rpc(alliance, destination)
	else:
		_apply_score_algae(alliance, destination)

@rpc("authority", "call_local", "reliable")
func _apply_score_algae(alliance: String, destination: String) -> void:
	var points := ALGAE_PROCESSOR_POINTS if destination == "processor" else ALGAE_NET_POINTS
	ScoringManager.add_points(alliance, points)

	if destination == "processor":
		_algae_processor[alliance] += 1
	else:
		_algae_net[alliance] += 1

	algae_scored_changed.emit(alliance, destination, _algae_processor[alliance] if destination == "processor" else _algae_net[alliance])
	_update_coral_rp("red")
	_update_coral_rp("blue")

func mark_leave(alliance: String) -> void:
	if not _can_trigger_scoring():
		return
	if not MatchManager.running:
		return
	if MatchManager.current_phase != MatchManager.Phase.AUTONOMOUS:
		return
	if _has_left[alliance]:
		return
	if NetworkManager.is_networked():
		_apply_mark_leave.rpc(alliance)
	else:
		_apply_mark_leave(alliance)

@rpc("authority", "call_local", "reliable")
func _apply_mark_leave(alliance: String) -> void:
	if _has_left[alliance]:
		return
	_has_left[alliance] = true
	ScoringManager.add_points(alliance, LEAVE_POINTS)
	leave_changed.emit(alliance, true)

func climb(alliance: String, cage_type: String) -> void:
	if not _can_trigger_scoring():
		return
	if not MatchManager.running:
		return
	if MatchManager.current_phase != MatchManager.Phase.TELEOP:
		return
	if cage_type != "park" and cage_type != "shallow" and cage_type != "deep":
		push_warning("ReefscapeScoring: invalid cage type %s" % cage_type)
		return
	if NetworkManager.is_networked():
		_apply_climb.rpc(alliance, cage_type)
	else:
		_apply_climb(alliance, cage_type)

@rpc("authority", "call_local", "reliable")
func _apply_climb(alliance: String, cage_type: String) -> void:
	var points: int
	match cage_type:
		"park": points = PARK_POINTS
		"shallow": points = SHALLOW_CLIMB_POINTS
		"deep": points = DEEP_CLIMB_POINTS
		_: return

	ScoringManager.add_points(alliance, points)
	_barge_points[alliance] += points
	barge_points_changed.emit(alliance, _barge_points[alliance])
	_update_barge_rp(alliance)

func has_coopertition() -> bool:
	return _algae_processor["red"] >= COOP_PROCESSOR_THRESHOLD and _algae_processor["blue"] >= COOP_PROCESSOR_THRESHOLD

func _update_coral_rp(alliance: String) -> void:
	var levels_met := 0
	for level in _coral_count[alliance]:
		if _coral_count[alliance][level] >= CORAL_RP_LEVEL_THRESHOLD:
			levels_met += 1

	var required := CORAL_RP_LEVELS_REQUIRED_COOP if has_coopertition() else CORAL_RP_LEVELS_REQUIRED
	var achieved := levels_met >= required

	if _coral_rp[alliance] == achieved:
		return
	_coral_rp[alliance] = achieved
	coral_rp_changed.emit(alliance, achieved)

func _update_barge_rp(alliance: String) -> void:
	var achieved = _barge_points[alliance] >= BARGE_RP_THRESHOLD
	if _barge_rp[alliance] == achieved:
		return
	_barge_rp[alliance] = achieved
	barge_rp_changed.emit(alliance, achieved)

func get_coral_count(alliance: String, level: int) -> int:
	return _coral_count.get(alliance, {}).get(level, 0)

func get_algae_count(alliance: String, destination: String) -> int:
	if destination == "processor":
		return _algae_processor.get(alliance, 0)
	return _algae_net.get(alliance, 0)

func get_barge_points(alliance: String) -> int:
	return _barge_points.get(alliance, 0)

func has_left(alliance: String) -> bool:
	return _has_left.get(alliance, false)

func has_coral_rp(alliance: String) -> bool:
	return _coral_rp.get(alliance, false)

func has_barge_rp(alliance: String) -> bool:
	return _barge_rp.get(alliance, false)

func reset() -> void:
	_coral_count = {
		"red": { 1: 0, 2: 0, 3: 0, 4: 0 },
		"blue": { 1: 0, 2: 0, 3: 0, 4: 0 }
	}
	_algae_processor = { "red": 0, "blue": 0 }
	_algae_net = { "red": 0, "blue": 0 }
	_barge_points = { "red": 0, "blue": 0 }
	_has_left = { "red": false, "blue": false }
	_coral_rp = { "red": false, "blue": false }
	_barge_rp = { "red": false, "blue": false }
	ScoringManager.reset_scores()

	for alliance in ["red", "blue"]:
		for level in [1, 2, 3, 4]:
			coral_scored_changed.emit(alliance, level, 0)
		algae_scored_changed.emit(alliance, "processor", 0)
		algae_scored_changed.emit(alliance, "net", 0)
		barge_points_changed.emit(alliance, 0)
		leave_changed.emit(alliance, false)
		coral_rp_changed.emit(alliance, false)
		barge_rp_changed.emit(alliance, false)

@rpc("any_peer", "call_remote", "reliable")
func _request_state_sync() -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	_apply_state_snapshot.rpc_id(sender,
		ScoringManager.get_score("red"), ScoringManager.get_score("blue"),
		_coral_count["red"], _coral_count["blue"],
		_algae_processor["red"], _algae_processor["blue"],
		_algae_net["red"], _algae_net["blue"],
		_barge_points["red"], _barge_points["blue"],
		_has_left["red"], _has_left["blue"])

@rpc("authority", "call_remote", "reliable")
func _apply_state_snapshot(red_score: int, blue_score: int, red_coral: Dictionary, blue_coral: Dictionary,
		red_processor: int, blue_processor: int, red_net: int, blue_net: int,
		red_barge: int, blue_barge: int, red_left: bool, blue_left: bool) -> void:
	ScoringManager.scores["red"] = red_score
	ScoringManager.scores["blue"] = blue_score
	ScoringManager.score_changed.emit("red", red_score)
	ScoringManager.score_changed.emit("blue", blue_score)

	_coral_count["red"] = red_coral
	_coral_count["blue"] = blue_coral
	_algae_processor["red"] = red_processor
	_algae_processor["blue"] = blue_processor
	_algae_net["red"] = red_net
	_algae_net["blue"] = blue_net
	_barge_points["red"] = red_barge
	_barge_points["blue"] = blue_barge
	_has_left["red"] = red_left
	_has_left["blue"] = blue_left

	for level in [1, 2, 3, 4]:
		coral_scored_changed.emit("red", level, red_coral[level])
		coral_scored_changed.emit("blue", level, blue_coral[level])
	algae_scored_changed.emit("red", "processor", red_processor)
	algae_scored_changed.emit("blue", "processor", blue_processor)
	algae_scored_changed.emit("red", "net", red_net)
	algae_scored_changed.emit("blue", "net", blue_net)
	barge_points_changed.emit("red", red_barge)
	barge_points_changed.emit("blue", blue_barge)
	leave_changed.emit("red", red_left)
	leave_changed.emit("blue", blue_left)
	_update_coral_rp("red")
	_update_coral_rp("blue")
	_update_barge_rp("red")
	_update_barge_rp("blue")
