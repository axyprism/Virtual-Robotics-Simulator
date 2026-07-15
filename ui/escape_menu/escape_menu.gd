extends CanvasLayer

@onready var status_label: Label         = $Panel/MarginContainer/VBoxContainer/TabContainer/MarginContainer/ConnectTab/StatusLabel
@onready var robot_list:   VBoxContainer = $Panel/MarginContainer/VBoxContainer/TabContainer/RobotsTab/RobotListContainer
@onready var spawn_button: Button        = $Panel/MarginContainer/VBoxContainer/TabContainer/RobotsTab/SpawnButton
@onready var disconnect_button: Button = $Panel/MarginContainer/VBoxContainer/TabContainer/MarginContainer/ConnectTab/DisconnectButton

@export var robot_spawner_path: NodePath
@onready var _spawner: RobotSpawner = get_node(robot_spawner_path)

var _selected_robot: String = ""
var _is_open:        bool   = false

func _ready() -> void:
	visible = false
	disconnect_button.pressed.connect(_on_disconnect_pressed)
	spawn_button.pressed.connect(_on_spawn_pressed)
	spawn_button.disabled = true
	get_tree().root.focus_entered.connect(_on_window_focus_entered)
	get_tree().root.focus_exited.connect(_on_window_focus_exited)
	NetworkManager.public_ip_received.connect(func(ip): _set_status("Public IP: " + str(ip)))
	NetworkManager.player_connected.connect(func(id): _set_status("Player connected: " + str(id)))
	NetworkManager.player_disconnected.connect(func(id): _set_status("Player left: " + str(id)))
	_refresh_status()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("OpenMenu"):
		_toggle()
		get_viewport().set_input_as_handled()
		return
	if _is_open and event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_toggle()
			get_viewport().set_input_as_handled()

func _toggle() -> void:
	_is_open = not _is_open
	visible  = _is_open
	if _is_open:
		_refresh_robot_list()
		_refresh_status()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _refresh_robot_list() -> void:
	for child in robot_list.get_children():
		child.queue_free()
	_selected_robot       = ""
	spawn_button.disabled = true
	if not _spawner:
		return
	var names := _spawner.get_robot_names()
	if names.is_empty():
		var lbl  := Label.new()
		lbl.text  = "No robot scenes found in robots/scenes/"
		robot_list.add_child(lbl)
		return
	for robot_name in names:
		var btn        := Button.new()
		btn.text        = robot_name
		btn.toggle_mode = true
		btn.pressed.connect(_on_robot_selected.bind(robot_name, btn))
		robot_list.add_child(btn)

func _on_robot_selected(robot_name: String, btn: Button) -> void:
	for child in robot_list.get_children():
		if child is Button and child != btn:
			child.button_pressed = false
	_selected_robot       = robot_name
	spawn_button.disabled = false

func _on_spawn_pressed() -> void:
	if _selected_robot.is_empty():
		return
	if not NetworkManager.is_connected_to_game():
		_set_status("Not connected")
		return
	_spawner.request_spawn(_selected_robot)
	_set_status("Spawn requested: " + _selected_robot)
	
func _on_disconnect_pressed() -> void:
	NetworkManager.disconnect_from_game()
	get_tree().change_scene_to_file("res://ui/main_menu/main_menu.tscn")

func _refresh_status() -> void:
	if not NetworkManager.is_connected_to_game():
		_set_status("Not connected")
	elif NetworkManager.is_host():
		_set_status("Hosting - Players: " + str(NetworkManager.players.size()))
	else:
		_set_status("Connected — ID: " + str(NetworkManager.get_my_id()))

func _set_status(text: String) -> void:
	status_label.text = text

func _on_window_focus_entered() -> void:
	if _is_open:
		_toggle()

func _on_window_focus_exited() -> void:
	if not _is_open:
		_toggle()
