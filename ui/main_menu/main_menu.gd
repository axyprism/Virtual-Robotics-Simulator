extends Control

const GAME_SCENE := "res://world/main.tscn"
const GameEntryScene := preload("res://ui/main_menu/game_entry.tscn")

@onready var start_menu:         PanelContainer = $StartMenu
@onready var singleplayer_button: Button        = $StartMenu/MarginContainer/HBoxContainer/HBoxContainer/SingleplayerButton
@onready var multiplayer_button:  Button        = $StartMenu/MarginContainer/HBoxContainer/HBoxContainer/MultiplayerButton
@onready var options_button:      Button        = $StartMenu/MarginContainer/HBoxContainer/OptionsButton
@onready var quit_button:         Button        = $StartMenu/MarginContainer/HBoxContainer/QuitButton

@onready var game_select: PanelContainer = $GameSelect
@onready var game_list: HBoxContainer = $GameSelect/MarginContainer/VBoxContainer/ItemList/HBoxContainer
@onready var game_back_button: Button        = $GameSelect/MarginContainer/VBoxContainer/BackButton

@onready var multiplayer_screen: PanelContainer = $MultiplayerScreen
@onready var port_field:         LineEdit       = $MultiplayerScreen/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/PortField
@onready var host_button:        Button         = $MultiplayerScreen/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/HostButton
@onready var ip_field:           LineEdit       = $MultiplayerScreen/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/IPField
@onready var join_button:        Button         = $MultiplayerScreen/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/JoinButton
@onready var mp_back_button:     Button         = $MultiplayerScreen/MarginContainer/VBoxContainer/BackButton

func _ready() -> void:
	_show(start_menu)

	singleplayer_button.pressed.connect(_on_singleplayer_pressed)
	multiplayer_button.pressed.connect(_on_multiplayer_pressed)
	options_button.pressed.connect(_on_options_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	game_back_button.pressed.connect(func(): _show(start_menu))

	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	mp_back_button.pressed.connect(func(): _show(start_menu))

	_populate_list()
 
func _populate_list() -> void:
	for child in game_list.get_children():
		child.queue_free()
 
	for game in GameManager.games:
		var entry := GameEntryScene.instantiate()
		game_list.add_child(entry)
		entry.setup(game)
		entry.selected.connect(_on_game_selected)
 
func _on_back_pressed() -> void:
	visible = false

func _on_singleplayer_pressed() -> void:
	_show(game_select)

func _on_multiplayer_pressed() -> void:
	_show(multiplayer_screen)

func _on_options_pressed() -> void:
	pass

func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_game_selected(game: GameData) -> void:
	GameManager.select_game(game)
	NetworkManager.host_local()
	_load_game()

func _on_host_pressed() -> void:
	var port: int = int(port_field.text) if port_field.text.is_valid_int() \
		else NetworkManager.DEFAULT_PORT
	NetworkManager.host(port)
	_load_game()
	NetworkManager.get_public_ip()

func _on_join_pressed() -> void:
	var ip := ip_field.text.strip_edges()
	if ip.is_empty():
		ip_field.placeholder_text = "Enter an IP address first"
		return
	var port: int = int(port_field.text) if port_field.text.is_valid_int() \
		else NetworkManager.DEFAULT_PORT
	NetworkManager.join_succeeded.connect(_load_game, CONNECT_ONE_SHOT)
	NetworkManager.join_failed.connect(_on_join_failed, CONNECT_ONE_SHOT)
	NetworkManager.join(ip, port)
	join_button.disabled  = true
	join_button.text      = "Connecting..."

func _on_join_failed(reason: String) -> void:
	join_button.disabled = false
	join_button.text     = "Join"
	ip_field.placeholder_text = "Failed: " + reason

func _load_game() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)

func _show(panel: Control) -> void:
	start_menu.visible       = (panel == start_menu)
	game_select.visible      = (panel == game_select)
	multiplayer_screen.visible = (panel == multiplayer_screen)
