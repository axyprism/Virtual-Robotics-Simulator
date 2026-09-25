extends CanvasLayer

const GAME_SCENE := "res://world/main.tscn"
const GameEntryScene := preload("res://ui/main_menu/game_entry.tscn")

@export var orbit_speed: float = 0.2
@export var orbit_center: Vector3 = Vector3.ZERO
@export var distance: float = 8.0
@export var height: float = 2.0

@onready var pivot: Node3D = $Background/SubViewportContainer/SubViewport/Pivot
@onready var camera: Camera3D = $Background/SubViewportContainer/SubViewport/Pivot/Camera3D

@onready var viewport_container: SubViewportContainer = $Background/SubViewportContainer
@onready var viewport: SubViewport = $Background/SubViewportContainer/SubViewport

@onready var start_menu: PanelContainer = $Control/StartMenu
@onready var singleplayer_button: Button = $Control/StartMenu/MarginContainer/MenuButtons/Singleplayer
@onready var multiplayer_button: Button = $Control/StartMenu/MarginContainer/MenuButtons/Multiplayer
@onready var options_button: Button = $Control/StartMenu/MarginContainer/MenuButtons/Options
@onready var quit_button: Button = $Control/StartMenu/MarginContainer/MenuButtons/Quit

@onready var game_select: PanelContainer = $Control/GameSelect
@onready var game_list: HBoxContainer = $Control/GameSelect/MarginContainer/VBoxContainer/ItemList/HBoxContainer
@onready var game_back_button: Button = $Control/GameSelect/MarginContainer/VBoxContainer/BackButton

@onready var multiplayer_screen: PanelContainer = $Control/MultiplayerScreen
@onready var port_field: LineEdit = $Control/MultiplayerScreen/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/PortField
@onready var host_button: Button = $Control/MultiplayerScreen/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/HostButton
@onready var ip_field: LineEdit = $Control/MultiplayerScreen/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/IPField
@onready var join_button: Button = $Control/MultiplayerScreen/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/JoinButton
@onready var mp_back_button: Button = $Control/MultiplayerScreen/MarginContainer/VBoxContainer/BackButton

@onready var options_screen: PanelContainer = $Control/OptionsScreen
@onready var camera_mode_option: OptionButton = $Control/OptionsScreen/MarginContainer/VBoxContainer/CameraModeOption
@onready var options_back_button: Button = $Control/OptionsScreen/MarginContainer/VBoxContainer/BackButton

var _pending_port: int = -1
var _game_select_return_panel: Control


func _ready() -> void:
	pivot.position = orbit_center
	camera.position = Vector3(0, height, distance)
	camera.look_at(pivot.global_position)
	
	viewport_container.resized.connect(_on_container_resized)
	_on_container_resized()

	_show(start_menu)

	singleplayer_button.pressed.connect(_on_singleplayer_pressed)
	multiplayer_button.pressed.connect(_on_multiplayer_pressed)
	options_button.pressed.connect(_on_options_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	game_back_button.pressed.connect(func(): _show(_game_select_return_panel))

	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	mp_back_button.pressed.connect(func(): _show(start_menu))

	options_back_button.pressed.connect(func(): _show(start_menu))
	_setup_camera_mode_option()

	_populate_list()


func _process(delta: float) -> void:
	pivot.rotate_y(orbit_speed * delta)

func _on_container_resized() -> void:
	viewport.size = viewport_container.size

func _populate_list() -> void:
	for child in game_list.get_children():
		child.queue_free()

	for game in GameManager.games:
		var entry := GameEntryScene.instantiate()
		game_list.add_child(entry)
		entry.setup(game)
		entry.selected.connect(_on_game_selected)


func _on_singleplayer_pressed() -> void:
	_pending_port = -1
	_game_select_return_panel = start_menu
	_show(game_select)


func _on_multiplayer_pressed() -> void:
	_show(multiplayer_screen)


func _on_options_pressed() -> void:
	_show(options_screen)


func _setup_camera_mode_option() -> void:
	camera_mode_option.clear()
	camera_mode_option.add_item("Basic (3rd person, robot-centric)", CameraSettings.CameraMode.BASIC)
	camera_mode_option.add_item("Advanced (1st person, field-centric)", CameraSettings.CameraMode.ADVANCED)
	camera_mode_option.select(camera_mode_option.get_item_index(CameraSettings.camera_mode))
	camera_mode_option.item_selected.connect(_on_camera_mode_selected)


func _on_camera_mode_selected(_index: int) -> void:
	var mode: CameraSettings.CameraMode = camera_mode_option.get_selected_id() as CameraSettings.CameraMode
	CameraSettings.set_camera_mode(mode)


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_game_selected(game: GameData) -> void:
	GameManager.select_game(game)
	if _pending_port == -1:
		NetworkManager.host_local()
		_load_game()
	else:
		NetworkManager.host(_pending_port)
		_load_game()
		NetworkManager.get_public_ip()


func _on_host_pressed() -> void:
	_pending_port = int(port_field.text) if port_field.text.is_valid_int() \
		else NetworkManager.DEFAULT_PORT
	_game_select_return_panel = multiplayer_screen
	_show(game_select)


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
	join_button.disabled = true
	join_button.text = "Connecting..."


func _on_join_failed(reason: String) -> void:
	NetworkManager.join_succeeded.disconnect(_load_game)
	join_button.disabled = false
	join_button.text = "Join"
	ip_field.placeholder_text = "Failed: " + reason


func _load_game() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)


func _show(panel: Control) -> void:
	start_menu.visible = (panel == start_menu)
	game_select.visible = (panel == game_select)
	multiplayer_screen.visible = (panel == multiplayer_screen)
	options_screen.visible = (panel == options_screen)
