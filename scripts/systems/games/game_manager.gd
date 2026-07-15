extends Node

signal game_selected(game: GameData)

const GAMES_DIR := "res://assets/games/"

var games: Array[GameData] = []
var current_game: GameData
var current_field: Node = null
var current_scoring: Node = null
var current_ui: Node = null

func _ready() -> void:
	_load_games_from_dir()

func _load_games_from_dir() -> void:
	games.clear()
	var dir := DirAccess.open(GAMES_DIR)
	if dir == null:
		push_error("GameManager: could not open %s" % GAMES_DIR)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		print(file_name)
		if file_name.ends_with(".tres"):
			print('good file')
			var res := load(GAMES_DIR + file_name)
			if res is GameData:
				games.append(res)
		file_name = dir.get_next()
	dir.list_dir_end()

func select_game(game: GameData) -> void:
	current_game = game
	game_selected.emit(game)

func load_current_game(field_container: Node, ui_container: Node) -> void:
	if current_game == null:
		push_error("GameManager: no game selected")
		return

	_clear_node(current_field)
	_clear_node(current_scoring)
	_clear_node(current_ui)
	
	if current_game.field_scene:
		current_field = current_game.field_scene.instantiate()
		field_container.add_child(current_field)
	
	if current_game.scoring_scene:
		current_scoring = current_game.scoring_scene.instantiate()
		add_child(current_scoring)
	
	if current_game.ui_scene:
		current_ui = current_game.ui_scene.instantiate()
		ui_container.add_child(current_ui)

	ScoringManager.reset_scores()

func _clear_node(n: Node) -> void:
	if n != null and is_instance_valid(n):
		n.queue_free()
