extends CanvasLayer
class_name RebuiltUI
@onready var qual_num: Label = $VBoxContainer/QualNumBox/QualificationNum

@onready var red_team_labels: Array[Label] = [
	$VBoxContainer/OverlayContainer/RedTeams/RedAlliance/TeamTabs/TeamTab/TeamNumber,
	$VBoxContainer/OverlayContainer/RedTeams/RedAlliance/TeamTabs/PanelContainer/TeamTab2/TeamNumber,
	$VBoxContainer/OverlayContainer/RedTeams/RedAlliance/TeamTabs/TeamTab3/TeamNumber,
]
@onready var blue_team_labels: Array[Label] = [
	$VBoxContainer/OverlayContainer/BlueTeams/RedAlliance/TeamTabs/TeamTab/TeamNumber,
	$VBoxContainer/OverlayContainer/BlueTeams/RedAlliance/TeamTabs/PanelContainer/TeamTab2/TeamNumber,
	$VBoxContainer/OverlayContainer/BlueTeams/RedAlliance/TeamTabs/TeamTab3/TeamNumber,
]

@onready var red_progress_label: Label = $VBoxContainer/OverlayContainer/RedTeams/RedAlliance/MarginContainer/PanelContainer/HBoxContainer/Label
@onready var blue_progress_label: Label = $VBoxContainer/OverlayContainer/BlueTeams/RedAlliance/MarginContainer/PanelContainer/HBoxContainer/Label

@onready var red_score_label: Label = $VBoxContainer/OverlayContainer/RedScore/HBoxContainer/ScoreLabel
@onready var blue_score_label: Label = $VBoxContainer/OverlayContainer/BlueScore/HBoxContainer/ScoreLabel

@onready var shift_counter: Label = $VBoxContainer/OverlayContainer/PanelContainer/VBoxContainer/HBoxContainer/ShiftCounter
@onready var shift_time_left: Label = $VBoxContainer/OverlayContainer/PanelContainer/VBoxContainer/HBoxContainer/PanelContainer/ShiftTimeLeft
@onready var match_timer: Label = $VBoxContainer/OverlayContainer/PanelContainer/VBoxContainer/MatchTimer

func _ready() -> void:
	ScoringManager.score_changed.connect(_on_score_changed)
	MatchManager.time_updated.connect(_on_time_updated)
	_on_score_changed("red", ScoringManager.get_score("red"))
	_on_score_changed("blue", ScoringManager.get_score("blue"))

	MatchScheduler.current_match_changed.connect(func(_m): _refresh_match_info())
	MatchScheduler.schedule_updated.connect(_refresh_match_info)
	NetworkManager.player_profile_updated.connect(func(_id): _refresh_match_info())
	_refresh_match_info()

	var scoring := GameManager.current_scoring as RebuiltScoring
	if scoring:
		scoring.fuel_progress_changed.connect(_on_fuel_progress_changed)
		scoring.shift_changed.connect(_on_shift_changed)
		_on_fuel_progress_changed("red", scoring.get_fuel_scored("red"))
		_on_fuel_progress_changed("blue", scoring.get_fuel_scored("blue"))

func set_qualification_label(text: String) -> void:
	qual_num.text = text

func _refresh_match_info() -> void:
	var match_info = MatchScheduler.get_current_match()
	if match_info == null:
		set_qualification_label("No match in progress")
		_fill_team_labels(red_team_labels, [])
		_fill_team_labels(blue_team_labels, [])
		return
	set_qualification_label("Qualification %d of %d" % [match_info["match_number"], MatchScheduler.total_matches])
	_fill_team_labels(red_team_labels, match_info["red"])
	_fill_team_labels(blue_team_labels, match_info["blue"])

func _fill_team_labels(labels: Array[Label], peer_ids: Array) -> void:
	for i in labels.size():
		if i >= peer_ids.size():
			labels[i].text = "N/A"
			continue
		var profile: Dictionary = NetworkManager.player_profiles.get(peer_ids[i], {})
		labels[i].text = profile.get("team_number", "N/A")

func _on_score_changed(alliance: String, new_score: int) -> void:
	if alliance == "red":
		red_score_label.text = str(new_score)
	else:
		blue_score_label.text = str(new_score)

func _on_fuel_progress_changed(alliance: String, fuel_scored: int) -> void:
	var scoring := GameManager.current_scoring as RebuiltScoring
	var target := RebuiltScoring.ENERGIZED_THRESHOLD
	if scoring and scoring.has_energized(alliance):
		target = RebuiltScoring.SUPERCHARGED_THRESHOLD
	var text := "%d / %d" % [fuel_scored, target]
	if alliance == "red":
		red_progress_label.text = text
	else:
		blue_progress_label.text = text

func _on_time_updated(time_left: float) -> void:
	var t := maxi(0, int(ceil(time_left)))
	@warning_ignore("integer_division")
	match_timer.text = "%d:%02d" % [t / 60, t % 60]

func _on_shift_changed(segment_index: int, _segment_name: String, seg_time_left: float) -> void:
	shift_counter.text = "%d/6" % segment_index
	shift_time_left.text = ":%02d" % maxi(0, int(ceil(seg_time_left)))
