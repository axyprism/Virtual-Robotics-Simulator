extends Node

signal rankings_updated

var records := {}
var standings: Array = []


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)


func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		_sync.rpc_id(id, records)


func record_match(red_peers: Array, blue_peers: Array) -> void:
	if not multiplayer.is_server():
		return
	var winner := ScoringManager.get_winner()
	for team in _get_teams(red_peers):
		_apply_result(team, "red", winner)
	for team in _get_teams(blue_peers):
		_apply_result(team, "blue", winner)
	_rebuild()
	_sync.rpc(records)


func reset_rankings() -> void:
	if not multiplayer.is_server():
		return
	records.clear()
	_rebuild()
	_sync.rpc(records)


func get_rank(team: String) -> int:
	for entry in standings:
		if entry["team"] == team:
			return entry["rank"]
	return 0


func get_record(team: String) -> Dictionary:
	return records.get(team, {"wins": 0, "losses": 0, "ties": 0})


func _get_teams(peer_ids: Array) -> Array:
	var teams: Array = []
	for peer_id in peer_ids:
		var profile: Dictionary = NetworkManager.player_profiles.get(peer_id, {})
		var team := str(profile.get("team_number", ""))
		if team != "" and not teams.has(team):
			teams.append(team)
	return teams


func _apply_result(team: String, alliance: String, winner: String) -> void:
	if not records.has(team):
		records[team] = {"wins": 0, "losses": 0, "ties": 0}
	if winner == "tie":
		records[team]["ties"] += 1
	elif winner == alliance:
		records[team]["wins"] += 1
	else:
		records[team]["losses"] += 1


func _rebuild() -> void:
	standings.clear()
	for team in records.keys():
		var entry: Dictionary = records[team].duplicate()
		entry["team"] = team
		standings.append(entry)
	standings.sort_custom(_compare)
	for i in standings.size():
		standings[i]["rank"] = i + 1
	rankings_updated.emit()


func _compare(a: Dictionary, b: Dictionary) -> bool:
	if a["wins"] != b["wins"]:
		return a["wins"] > b["wins"]
	if a["ties"] != b["ties"]:
		return a["ties"] > b["ties"]
	if a["losses"] != b["losses"]:
		return a["losses"] < b["losses"]
	return a["team"] < b["team"]


@rpc("authority", "call_remote", "reliable")
func _sync(data: Dictionary) -> void:
	records = data
	_rebuild()
