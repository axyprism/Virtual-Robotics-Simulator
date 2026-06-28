extends CanvasLayer

@onready var status_label:       Label         = $Panel/MarginContainer/VBoxContainer/TabContainer/MarginContainer/ConnectTab/StatusLabel
@onready var port_field:         LineEdit      = $Panel/MarginContainer/VBoxContainer/TabContainer/MarginContainer/ConnectTab/PortField
@onready var host_button:        Button        = $Panel/MarginContainer/VBoxContainer/TabContainer/MarginContainer/ConnectTab/HostButton
@onready var ip_field:           LineEdit      = $Panel/MarginContainer/VBoxContainer/TabContainer/MarginContainer/ConnectTab/IPField
@onready var join_button:        Button        = $Panel/MarginContainer/VBoxContainer/TabContainer/MarginContainer/ConnectTab/JoinButton
@onready var disconnect_button:  Button        = $Panel/MarginContainer/VBoxContainer/TabContainer/MarginContainer/ConnectTab/DisconnectButton
@onready var robot_list:         VBoxContainer = $Panel/MarginContainer/VBoxContainer/TabContainer/RobotsTab/RobotListContainer
@onready var spawn_button:       Button        = $Panel/MarginContainer/VBoxContainer/TabContainer/RobotsTab/SpawnButton

@export var robot_spawner_path: NodePath
@onready var _spawner: RobotSpawner = get_node(robot_spawner_path)

var _selected_robot: String = ""
var _is_open:        bool   = false

func _ready() -> void:
	visible = false
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	disconnect_button.pressed.connect(_on_disconnect_pressed)
	spawn_button.pressed.connect(_on_spawn_pressed)
	get_tree().root.focus_entered.connect(_on_window_focus_entered)
	get_tree().root.focus_exited.connect(_on_window_focus_exited)
	spawn_button.disabled = true

	NetworkManager.server_created.connect(_on_server_created)
	NetworkManager.join_succeeded.connect(_on_join_succeeded)
	NetworkManager.join_failed.connect(_on_join_failed)
	NetworkManager.server_disconnected.connect(_on_server_disconnected)
	NetworkManager.player_connected.connect(_on_player_connected)
	NetworkManager.player_disconnected.connect(_on_player_disconnected)

	_refresh_status()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle()
		get_viewport().set_input_as_handled()
		return
	## Close menu and recapture mouse when clicking into the window
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
	_selected_robot   = ""
	spawn_button.disabled = true
	if not _spawner:
		return
	var names := _spawner.get_robot_names()
	if names.is_empty():
		var lbl := Label.new()
		lbl.text = "No robot scenes found in robots/scenes/"
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
		_set_status("Not connected — host or join first")
		return
	_spawner.request_spawn(_selected_robot)
	_set_status("Spawn requested: " + _selected_robot)

func _on_host_pressed() -> void:
	## Disconnect existing session (offline or otherwise) without emitting
	## session_ended twice — disconnect_from_game handles cleanup
	NetworkManager.disconnect_from_game()
	var port = int(port_field.text) if port_field.text.is_valid_int() \
		else NetworkManager.DEFAULT_PORT
	NetworkManager.host(port)
	## Status updates via _on_server_created signal

func _on_join_pressed() -> void:
	var ip := ip_field.text.strip_edges()
	if ip.is_empty():
		_set_status("Enter an IP address first")
		return
	NetworkManager.disconnect_from_game()
	var port = int(port_field.text) if port_field.text.is_valid_int() \
		else NetworkManager.DEFAULT_PORT
	NetworkManager.join(ip, port)
	_set_status("Connecting to " + ip + ":" + str(port) + "...")

func _on_disconnect_pressed() -> void:
	NetworkManager.disconnect_from_game()
	## Peer is now null synchronously so status is correct immediately
	_refresh_status()

func _on_server_created() -> void:
	_refresh_status()

func _on_join_succeeded() -> void:
	_refresh_status()

func _on_join_failed(reason: String) -> void:
	_set_status("Failed: " + reason)
	_refresh_status()

func _on_server_disconnected() -> void:
	_set_status("Disconnected from server")
	_refresh_status()

func _on_player_connected(peer_id: int) -> void:
	_set_status("Player connected: " + str(peer_id))

func _on_player_disconnected(peer_id: int) -> void:
	_set_status("Player left: " + str(peer_id))

func _refresh_status() -> void:
	if not NetworkManager.is_connected_to_game():
		_set_status("Not connected")
		disconnect_button.disabled = true
		host_button.disabled       = false
		join_button.disabled       = false
	elif NetworkManager.is_host():
		_set_status("Hosting — ID: " + str(NetworkManager.get_my_id())
			+ " — Players: " + str(NetworkManager.players.size()))
		disconnect_button.disabled = false
		host_button.disabled       = true
		join_button.disabled       = true
	else:
		_set_status("Connected — ID: " + str(NetworkManager.get_my_id()))
		disconnect_button.disabled = false
		host_button.disabled       = true
		join_button.disabled       = true

func _set_status(text: String) -> void:
	status_label.text = text

func _on_window_focus_entered() -> void:
	## Only close if menu is open AND mouse was captured before we lost focus
	if _is_open:
		_toggle()

func _on_window_focus_exited() -> void:
	## Only open if menu is not already open
	if not _is_open:
		_toggle()
