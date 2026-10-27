extends Control

@export var max_rows := 10
@export var max_leaderboard_rows := 10

@onready var list: VBoxContainer = $HBoxContainer/QueuePanel/VBoxContainer/UpcomingMatchesList
@onready var leaderboard_list: VBoxContainer = $HBoxContainer/LeaderboardPanel/LeaderboardList

var row_template: HBoxContainer


func _ready() -> void:
	row_template = list.get_child(0)
	list.remove_child(row_template)
	MatchScheduler.schedule_updated.connect(_refresh)
	MatchScheduler.current_match_changed.connect(func(_m): _refresh())
	NetworkManager.player_profile_updated.connect(func(_id): _refresh())
	RankingManager.rankings_updated.connect(_refresh)
	_refresh()


func _refresh() -> void:
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	for match_info in MatchScheduler.get_next_matches(max_rows):
		list.add_child(_build_row(match_info))
	_refresh_leaderboard()


func _refresh_leaderboard() -> void:
	for child in leaderboard_list.get_children():
		leaderboard_list.remove_child(child)
		child.queue_free()
	leaderboard_list.add_child(_build_leaderboard_row("Rank", "Team", "W-L-T"))
	var count := mini(RankingManager.standings.size(), max_leaderboard_rows)
	for i in count:
		var entry: Dictionary = RankingManager.standings[i]
		var record := "%d-%d-%d" % [entry["wins"], entry["losses"], entry["ties"]]
		leaderboard_list.add_child(_build_leaderboard_row(str(entry["rank"]), entry["team"], record))


func _build_leaderboard_row(rank_text: String, team_text: String, record_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	for text in [rank_text, team_text, record_text]:
		var label := Label.new()
		label.text = text
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(label)
	return row


func _build_row(match_info: Dictionary) -> HBoxContainer:
	var row: HBoxContainer = row_template.duplicate()
	var red: Array = match_info["red"]
	var blue: Array = match_info["blue"]
	_fill_slot(row.get_node("RedMember1"), red, 0)
	_fill_slot(row.get_node("RedMember2"), red, 1)
	_fill_slot(row.get_node("RedMember3"), red, 2)
	_fill_slot(row.get_node("BlueMember1"), blue, 0)
	_fill_slot(row.get_node("BlueMember2"), blue, 1)
	_fill_slot(row.get_node("BlueMember3"), blue, 2)
	return row


func _fill_slot(label: Label, peer_ids: Array, index: int) -> void:
	if index >= peer_ids.size():
		label.visible = false
		return
	label.visible = true
	var peer_id: int = peer_ids[index]
	var profile: Dictionary = NetworkManager.player_profiles.get(peer_id, {})
	var team := str(profile.get("team_number", ""))
	if team == "":
		label.text = "----"
		return
	var rank := RankingManager.get_rank(team)
	if rank == 0:
		label.text = team
	else:
		label.text = "#%d %s" % [rank, team]
