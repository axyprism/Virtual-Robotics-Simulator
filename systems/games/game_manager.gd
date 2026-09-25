extends Node

signal game_selected(game: GameData)

const GAMES_DIR := "res://systems/games/data/"

var games: Array[GameData] = []
var current_game: GameData
var current_field: Node = null
var current_scoring: Node = null
var current_ui: Node = null

func _ready() -> void:
	_load_games_from_dir()
	NetworkManager.player_connected.connect(_on_peer_connected)


func _on_peer_connected(peer_id: int) -> void:
	if NetworkManager.is_networked() and multiplayer.is_server() and current_game != null:
		_rpc_receive_game.rpc_id(peer_id, current_game.resource_path)

func _load_games_from_dir() -> void:
	games.clear()
	var dir := DirAccess.open(GAMES_DIR)
	if dir == null:
		push_error("GameManager: could not open %s" % GAMES_DIR)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var res := load(GAMES_DIR + file_name)
			if res is GameData:
				games.append(res)
		file_name = dir.get_next()
	dir.list_dir_end()

func select_game(game: GameData) -> void:
	current_game = game
	emit_signal("game_selected", game)
	if NetworkManager.is_networked() and multiplayer.is_server():
		_rpc_receive_game.rpc(game.resource_path)

@rpc("authority", "call_remote", "reliable")
func _rpc_receive_game(path: String) -> void:
	var game := load(path) as GameData
	if game:
		current_game = game
		emit_signal("game_selected", game)

func load_current_game(field_container: Node, ui_container: Node) -> void:
	if current_game == null:
		push_error("GameManager: no game selected")
		return

	_clear_node(current_field)
	_clear_node(current_scoring)
	_clear_node(current_ui)

	current_scoring = current_game.scoring_scene.instantiate()
	current_scoring.name = "Scoring"
	add_child(current_scoring)

	current_field = current_game.field_scene.instantiate()
	current_field.name = "Field"
	field_container.add_child(current_field)

	current_ui = current_game.ui_scene.instantiate()
	current_ui.name = "UI"
	ui_container.add_child(current_ui)

	ScoringManager.reset_scores()

func _clear_node(n) -> void:
	if n != null and is_instance_valid(n):
		n.queue_free()
