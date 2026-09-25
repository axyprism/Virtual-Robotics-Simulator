extends Node

signal score_changed(alliance: String, new_score: int)

var scores := {
	"red": 0,
	"blue": 0
}

func add_score(alliance: String, action: String) -> void:
	if not scores.has(alliance):
		push_error("Unknown alliance: %s" % alliance)
		return
	var game := GameManager.current_game
	if game == null or not game.point_values.has(action):
		push_error("Unknown scoring action: %s" % action)
		return
	scores[alliance] += game.point_values[action]
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
		score_changed.emit(alliance, scores[alliance])

func get_winner() -> String:
	if scores["red"] > scores["blue"]:
		return "red"
	elif scores["blue"] > scores["red"]:
		return "blue"
	return "tie"
