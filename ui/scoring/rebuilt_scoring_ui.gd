extends CanvasLayer
class_name RebuiltUI
@onready var qual_num: Label = $VBoxContainer/QualNumBox/QualificationNum

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

	var scoring := GameManager.current_scoring as RebuiltScoring
	if scoring:
		scoring.fuel_progress_changed.connect(_on_fuel_progress_changed)
		scoring.shift_changed.connect(_on_shift_changed)
		_on_fuel_progress_changed("red", scoring.get_fuel_scored("red"))
		_on_fuel_progress_changed("blue", scoring.get_fuel_scored("blue"))

func set_qualification_label(text: String) -> void:
	qual_num.text = text

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
