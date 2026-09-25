extends Control

@export var max_rows := 10

@onready var list: VBoxContainer = $Panel/VBoxContainer/UpcomingMatchesList

var row_template: HBoxContainer


func _ready() -> void:
	row_template = list.get_child(0)
	list.remove_child(row_template)
	MatchScheduler.schedule_updated.connect(_refresh)
	MatchScheduler.current_match_changed.connect(func(_m): _refresh())
	NetworkManager.player_profile_updated.connect(func(_id): _refresh())
	_refresh()


func _refresh() -> void:
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	for match_info in MatchScheduler.get_next_matches(max_rows):
		list.add_child(_build_row(match_info))


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
	label.text = profile.get("team_number", "----")
