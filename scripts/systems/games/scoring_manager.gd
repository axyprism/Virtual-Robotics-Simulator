extends Node
signal score_changed(alliance: String, new_score: int)

var scores := {
	"red": 0,
	"blue": 0
}

var point_values := {
	"low_goal": 2,
	"high_goal": 5,
	"climb": 10
}

func add_score(alliance: String, action: String) -> void:
	if not scores.has(alliance):
		push_error("Unknown alliance: %s" % alliance)
		return
	if not point_values.has(action):
		push_error("Unknown scoring action: %s" % action)
		return
	scores[alliance] += point_values[action]
	score_changed.emit(alliance, scores[alliance])

func add_points(alliance: String, points: int) -> void:
	if not scores.has(alliance):
		push_error("Unknown alliance: %s" % alliance)
		return
	scores[alliance] += points
	score_changed.emit(alliance, scores[alliance])

func get_score(alliance: String) -> int:
	return scores.get(alliance, 0)

func reset_scores() -> void:
	for alliance in scores.keys():
		scores[alliance] = 0
		score_changed.emit(alliance, 0)

func get_winner() -> String:
	if scores["red"] > scores["blue"]:
		return "red"
	elif scores["blue"] > scores["red"]:
		return "blue"
	return "tie"
