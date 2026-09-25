extends Node

enum Mode { FIXED, ENDLESS }

const STATUS_PENDING := "pending"
const STATUS_IN_PROGRESS := "in_progress"
const STATUS_COMPLETE := "complete"

signal config_changed
signal schedule_updated
signal current_match_changed(match_info: Variant)
signal match_completed(match_number: int, results: Dictionary)

var mode: Mode = Mode.ENDLESS
var total_matches: int = 10 
var alliance_size: int = 3 
var min_alliance_size: int = 1 
var allow_solo_practice: bool = true 

var schedule: Array = []
var current_match_index: int = -1
var _bench: Array = [] 
var _next_match_number: int = 1

func _ready() -> void:
	NetworkManager.player_connected.connect(_on_player_connected)
	NetworkManager.player_disconnected.connect(_on_player_disconnected)

func _is_authority() -> bool:
	return not NetworkManager.is_networked() or multiplayer.is_server()

func players_per_match() -> int:
	return alliance_size * 2

func configure(new_mode: Mode, new_total_matches: int = 10, new_alliance_size: int = 3, new_min_alliance_size: int = 1, new_allow_solo_practice: bool = true) -> void:
	if not _is_authority():
		return
	mode = new_mode
	total_matches = new_total_matches
	alliance_size = new_alliance_size
	min_alliance_size = new_min_alliance_size
	allow_solo_practice = new_allow_solo_practice
	config_changed.emit()
	if NetworkManager.is_networked():
		_rpc_config.rpc(mode, total_matches, alliance_size, min_alliance_size, allow_solo_practice)
	_try_generate_matches()

@rpc("authority", "call_remote", "reliable")
func _rpc_config(new_mode: int, new_total_matches: int, new_alliance_size: int, new_min_alliance_size: int, new_allow_solo_practice: bool) -> void:
	mode = new_mode as Mode
	total_matches = new_total_matches
	alliance_size = new_alliance_size
	min_alliance_size = new_min_alliance_size
	allow_solo_practice = new_allow_solo_practice
	config_changed.emit()

func reset_schedule() -> void:
	if not _is_authority():
		return
	schedule.clear()
	current_match_index = -1
	_next_match_number = 1
	_bench = NetworkManager.players.keys()
	_try_generate_matches()
	_broadcast_schedule()


func get_current_match() -> Variant:
	if current_match_index < 0 or current_match_index >= schedule.size():
		return null
	return schedule[current_match_index]

func get_next_matches(count: int = 3) -> Array:
	var out: Array = []
	var start := current_match_index + 1
	for i in range(start, mini(start + count, schedule.size())):
		out.append(schedule[i])
	return out

func get_bench() -> Array:
	return _bench.duplicate()

func get_alliance(peer_id: int) -> String:
	var m = get_current_match()
	if m == null:
		return ""
	if peer_id in m["red"]:
		return "red"
	if peer_id in m["blue"]:
		return "blue"
	return ""

func find_match_for_player(peer_id: int) -> Variant:
	for m in schedule:
		if m["status"] != STATUS_COMPLETE and (peer_id in m["red"] or peer_id in m["blue"]):
			return m
	return null

func get_match_alliance_size(match_info: Dictionary) -> int:
	return match_info.get("alliance_size", alliance_size)

func is_schedule_complete() -> bool:
	return mode == Mode.FIXED and _next_match_number > total_matches \
		and current_match_index + 1 >= schedule.size()


func start_next_match() -> void:
	if not _is_authority():
		return
	if current_match_index + 1 >= schedule.size():
		push_warning("MatchScheduler: no scheduled match ready yet")
		return
	current_match_index += 1
	schedule[current_match_index]["status"] = STATUS_IN_PROGRESS
	_broadcast_schedule()
	current_match_changed.emit(get_current_match())

func complete_current_match(results: Dictionary = {}) -> void:
	if not _is_authority():
		return
	var m = get_current_match()
	if m == null:
		return
	m["status"] = STATUS_COMPLETE
	m["results"] = results
	match_completed.emit(m["match_number"], results)

	for peer_id in m["red"] + m["blue"]:
		if NetworkManager.players.has(peer_id):
			_bench.append(peer_id)

	_try_generate_matches()
	_broadcast_schedule()


func _on_player_connected(peer_id: int) -> void:
	if not _is_authority():
		return
	_bench.append(peer_id)
	_backfill_pending_matches()
	_try_generate_matches()
	_broadcast_schedule()

func _on_player_disconnected(peer_id: int) -> void:
	if not _is_authority():
		return
	_bench.erase(peer_id)

	for m in schedule:
		if m["status"] != STATUS_PENDING:
			continue
		if peer_id in m["red"]:
			m["red"].erase(peer_id)
		if peer_id in m["blue"]:
			m["blue"].erase(peer_id)

	_backfill_pending_matches()
	_broadcast_schedule()

func _backfill_pending_matches() -> void:
	for m in schedule:
		if m["status"] != STATUS_PENDING:
			continue
		var target: int = alliance_size
		while m["red"].size() < target and not _bench.is_empty():
			m["red"].append(_bench.pop_front())
		while m["blue"].size() < target and not _bench.is_empty():
			m["blue"].append(_bench.pop_front())
		m["alliance_size"] = maxi(m["red"].size(), m["blue"].size())
	schedule_updated.emit()

func _try_generate_matches() -> void:
	var generated := false
	while true:
		if mode == Mode.FIXED and _next_match_number > total_matches:
			break

		var n := _bench.size()
		if n == 0:
			break
		var total_for_match: int = mini(n, alliance_size * 2)
		var red_size: int = clampi(ceili(total_for_match / 2.0), 0, alliance_size)
		var blue_size: int = total_for_match - red_size
		if blue_size < min_alliance_size:
			if allow_solo_practice and red_size >= min_alliance_size:
				blue_size = 0
			else:
				break
		if red_size < min_alliance_size:
			break
		_generate_match(red_size, blue_size)
		generated = true
	if generated:
		schedule_updated.emit()

func _generate_match(red_size: int, blue_size: int) -> void:
	var red: Array = []
	for i in range(red_size):
		red.append(_bench.pop_front())
	var blue: Array = []
	for i in range(blue_size):
		blue.append(_bench.pop_front())
	var match_info := {
		"match_number": _next_match_number,
		"red": red,
		"blue": blue,
		"alliance_size": maxi(red_size, blue_size),
		"status": STATUS_PENDING,
		"results": {},
	}
	schedule.append(match_info)
	_next_match_number += 1


func _broadcast_schedule() -> void:
	if NetworkManager.is_networked() and multiplayer.is_server():
		_rpc_sync_schedule.rpc(schedule, current_match_index, _bench, _next_match_number)

@rpc("authority", "call_remote", "reliable")
func _rpc_sync_schedule(new_schedule: Array, new_index: int, new_bench: Array, new_next_number: int) -> void:
	schedule = new_schedule
	current_match_index = new_index
	_bench = new_bench
	_next_match_number = new_next_number
	schedule_updated.emit()
	current_match_changed.emit(get_current_match())
