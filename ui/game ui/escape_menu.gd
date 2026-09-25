extends CanvasLayer

@onready var status_label: Label = $Panel/MarginContainer/VBoxContainer/TabContainer/MarginContainer/ConnectTab/StatusLabel
@onready var spawn_button: Button = $Panel/MarginContainer/VBoxContainer/TabContainer/RobotsTab/SpawnButton
@onready var disconnect_button: Button = $Panel/MarginContainer/VBoxContainer/TabContainer/MarginContainer/ConnectTab/DisconnectButton

const ROBOT_SELECT_SCENE := preload("res://ui/game ui/robot_select.tscn")
var _robot_select: Node = null

var _is_open: bool = false

@onready var _match_mode_option: OptionButton = $Panel/MarginContainer/VBoxContainer/TabContainer/MatchSettings/MatchTab/HBoxContainer/OptionButton
@onready var _total_matches_spin: SpinBox = $Panel/MarginContainer/VBoxContainer/TabContainer/MatchSettings/MatchTab/HBoxContainer2/SpinBox
@onready var _min_alliance_size_spin: SpinBox = $Panel/MarginContainer/VBoxContainer/TabContainer/MatchSettings/MatchTab/HBoxContainer4/SpinBox
@onready var _max_alliance_size_spin: SpinBox = $Panel/MarginContainer/VBoxContainer/TabContainer/MatchSettings/MatchTab/HBoxContainer3/SpinBox
@onready var _apply_button: Button = $Panel/MarginContainer/VBoxContainer/TabContainer/MatchSettings/MatchTab/HBoxContainer5/ApplyButton
@onready var _reset_button: Button = $Panel/MarginContainer/VBoxContainer/TabContainer/MatchSettings/MatchTab/HBoxContainer5/ResetButton
@onready var _start_match_button: Button = $Panel/MarginContainer/VBoxContainer/TabContainer/MatchSettings/MatchTab/HBoxContainer5/Button

var _host_only_controls: Array[Control] = []
var _suppress_next_close_click: bool = false
var _popup_open_count: int = 0

func _ready() -> void:
	visible = false
	disconnect_button.pressed.connect(_on_disconnect_pressed)
	spawn_button.pressed.connect(_on_spawn_pressed)
	get_tree().root.focus_entered.connect(_on_window_focus_entered)
	get_tree().root.focus_exited.connect(_on_window_focus_exited)
	NetworkManager.public_ip_received.connect(func(ip): _set_status("Public IP: " + str(ip)))
	NetworkManager.player_connected.connect(func(id): _set_status("Player connected: " + str(id)))
	NetworkManager.player_disconnected.connect(func(id): _set_status("Player left: " + str(id)))
	_refresh_status()

	_setup_match_tab()
	MatchScheduler.config_changed.connect(_refresh_match_config_ui)
	_refresh_match_config_ui()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("OpenMenu"):
		_toggle()
		get_viewport().set_input_as_handled()
		return
	if _is_open and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if _popup_open_count > 0:
			get_viewport().set_input_as_handled()
			return
		if event.pressed:
			return
		if _suppress_next_close_click:
			_suppress_next_close_click = false
			get_viewport().set_input_as_handled()
			return
		_toggle()
		get_viewport().set_input_as_handled()

func _toggle() -> void:
	_is_open = not _is_open
	visible = _is_open
	if _is_open:
		_refresh_status()
		_refresh_match_config_ui()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		_close_robot_select()
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_spawn_pressed() -> void:
	if not NetworkManager.is_connected_to_game():
		_set_status("Not connected")
		return
	_open_robot_select()

func _open_robot_select() -> void:
	if _robot_select == null:
		_robot_select = ROBOT_SELECT_SCENE.instantiate()
		add_child(_robot_select)
		_robot_select.profile_confirmed.connect(_on_profile_confirmed)
		_robot_select.back_pressed.connect(_close_robot_select)
	_robot_select.visible = true
	visible = false

func _on_profile_confirmed(robot_name: String, team_number: String) -> void:
	NetworkManager.set_profile(robot_name, team_number)
	_set_status("Profile saved: team " + team_number + ", " + robot_name)
	_close_robot_select()

func _close_robot_select() -> void:
	if _robot_select != null:
		_robot_select.visible = false
	visible = _is_open
	
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
	if _popup_open_count > 0:
		return
	if _is_open:
		_toggle()

func _on_window_focus_exited() -> void:
	if _popup_open_count > 0:
		return
	if not _is_open:
		_toggle()


func _setup_match_tab() -> void:
	_apply_button.pressed.connect(_on_apply_config_pressed)
	_reset_button.pressed.connect(func(): MatchScheduler.reset_schedule())
	_start_match_button.pressed.connect(_on_start_next_match_pressed)
	MatchManager.gap_time_updated.connect(_on_gap_time_updated)
	MatchManager.gap_finished.connect(_on_gap_finished)
	_suppress_close_for_popup(_match_mode_option.get_popup())

	_host_only_controls = [
		_match_mode_option, _total_matches_spin, _min_alliance_size_spin,
		_max_alliance_size_spin, _apply_button, _reset_button, _start_match_button,
	]
	_update_host_only_visibility()

func _suppress_close_for_popup(popup: Popup) -> void:
	popup.about_to_popup.connect(func(): _popup_open_count += 1)
	popup.popup_hide.connect(func():
		_popup_open_count = maxi(0, _popup_open_count - 1)
		_suppress_next_close_click = true
	)

func _on_gap_time_updated(time_left: float) -> void:
	_start_match_button.text = "Next match in %ds" % int(ceil(time_left))
	_start_match_button.disabled = true

func _on_gap_finished() -> void:
	_start_match_button.text = "Start Next Match"
	_update_host_only_visibility()
	
func _update_host_only_visibility() -> void:
	var is_host := NetworkManager.is_host()
	for c in _host_only_controls:
		if c is SpinBox:
			c.editable = is_host
		else:
			c.disabled = not is_host

func _on_apply_config_pressed() -> void:
	var mode: int = _match_mode_option.get_selected_id()
	MatchScheduler.configure(
		mode,
		int(_total_matches_spin.value),
		int(_max_alliance_size_spin.value),
		int(_min_alliance_size_spin.value)
	)

func _on_start_next_match_pressed() -> void:
	MatchScheduler.start_next_match()
	if MatchScheduler.get_current_match() != null:
		MatchManager.start_match()

func _refresh_match_config_ui() -> void:
	_match_mode_option.select(_match_mode_option.get_item_index(MatchScheduler.mode))
	_total_matches_spin.value = MatchScheduler.total_matches
	_max_alliance_size_spin.value = MatchScheduler.alliance_size
	_min_alliance_size_spin.value = MatchScheduler.min_alliance_size
	_update_host_only_visibility()
