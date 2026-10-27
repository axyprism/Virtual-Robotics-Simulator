extends CanvasLayer

@onready var replay_player: ReplayPlayer = $ReplayPlayer
@onready var root: Node3D = $Replay

@onready var exit_button: Button = $Menu/ReplayFilePanel/MarginContainer/VBoxContainer/Exit


@onready var container: SubViewportContainer = $Replay/SubViewportContainer
@onready var subviewport: SubViewport = $Replay/SubViewportContainer/SubViewport
@onready var pivot: Node3D = $Replay/SubViewportContainer/SubViewport/Pivot
@onready var camera: Camera3D = $Replay/SubViewportContainer/SubViewport/Pivot/Camera3D

@onready var select_file: OptionButton = $Menu/ReplayFilePanel/MarginContainer/VBoxContainer/SelectFile
@onready var load_replay_button: Button = $Menu/ReplayFilePanel/MarginContainer/VBoxContainer/LoadReplay

@onready var timeline: HSlider = $Menu/PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/HSlider
@onready var play_button: Button = $Menu/PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/Button
@onready var time_label: Label = $Menu/PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/TimeLabel

@onready var keyframe_track: KeyframeTrack = $Menu/PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/KeyframeTrack
@onready var keyframe_panel: Control = $Menu/KeyframePanel
@onready var add_keyframe_button: Button = $Menu/KeyframePanel/MarginContainer/VBoxContainer/AddKeyframe
@onready var delete_keyframe_button: Button = $Menu/KeyframePanel/MarginContainer/VBoxContainer/DeleteKeyframe
@onready var follow_button: Button = $Menu/KeyframePanel/MarginContainer/VBoxContainer/FollowKeyframes
@onready var pos_x: SpinBox = $Menu/KeyframePanel/MarginContainer/VBoxContainer/Position/X
@onready var pos_y: SpinBox = $Menu/KeyframePanel/MarginContainer/VBoxContainer/Position/Y
@onready var pos_z: SpinBox = $Menu/KeyframePanel/MarginContainer/VBoxContainer/Position/Z
@onready var rot_x: SpinBox = $Menu/KeyframePanel/MarginContainer/VBoxContainer/Rotation/X
@onready var rot_y: SpinBox = $Menu/KeyframePanel/MarginContainer/VBoxContainer/Rotation/Y
@onready var rot_z: SpinBox = $Menu/KeyframePanel/MarginContainer/VBoxContainer/Rotation/Z
@onready var fov_field: SpinBox = $Menu/KeyframePanel/MarginContainer/VBoxContainer/HBoxContainer/Fov

var editor_camera: EditorCamera
var replay_camera: ReplayCamera
var selected_keyframe: int = -1
var transform_fields: Array[SpinBox] = []

const REPLAY_DIR := "user://replays"
const REPLAY_EXT := ".tres"

func _ready() -> void:
	exit_button.pressed.connect(func(): get_tree().change_scene_to_file("res://ui/main_menu/main_menu.tscn"))
	
	editor_camera = EditorCamera.new()
	add_child(editor_camera)
	editor_camera.setup(container, pivot, camera)
	editor_camera.blocked_controls = [$Menu/PanelContainer, $Menu/ReplayFilePanel, keyframe_panel]
	container.resized.connect(func(): subviewport.size = container.size)

	timeline.editable = false
	timeline.min_value = 0.0
	timeline.max_value = 1.0
	timeline.step = 0.001
	timeline.value_changed.connect(_on_timeline_changed)
	
	replay_camera = ReplayCamera.new()
	add_child(replay_camera)
	replay_camera.keyframes_changed.connect(_refresh_keyframes)
	editor_camera.follow_interrupted.connect(_on_follow_interrupted)

	transform_fields = [pos_x, pos_y, pos_z, rot_x, rot_y, rot_z, fov_field]
	for field in transform_fields:
		field.value_changed.connect(_on_transform_edited)

	keyframe_track.setup(timeline)
	keyframe_track.keyframe_clicked.connect(_select_keyframe)
	add_keyframe_button.pressed.connect(_on_add_keyframe_pressed)
	delete_keyframe_button.pressed.connect(_on_delete_keyframe_pressed)
	follow_button.toggled.connect(_on_follow_toggled)
	_refresh_keyframes()
	
	play_button.disabled = true
	play_button.pressed.connect(_on_play_pressed)
	_update_play_button()
	_update_time_label()

	populate_replay_options()

	replay_player.load_progress.connect(_on_load_progress)
	replay_player.load_finished.connect(_on_load_finished)

	load_replay_button.pressed.connect(func():
		if select_file.selected == -1:
			print("No replay file selected!")
			return
		if replay_player.is_loading():
			return

		var file_path = select_file.get_item_metadata(select_file.selected)
		selected_keyframe = -1
		replay_camera.clear()
		load_replay_button.disabled = true
		replay_player.load_recording_async(file_path, root)
	)

func _process(_delta: float) -> void:
	if replay_player.recording == null:
		return
	var duration := _get_duration()
	if replay_player.playing and replay_player.playback_time >= duration:
		replay_player.playback_time = duration
		replay_player.apply_frame(duration)
		_set_playing(false)
	if replay_player.playing:
		timeline.set_value_no_signal(replay_player.playback_time)
	_update_time_label()
	if editor_camera.following:
		_apply_follow()
		
func _on_load_progress(ratio: float) -> void:
	load_replay_button.text = "Loading %d%%" % int(ratio * 100.0)

func _on_load_finished(success: bool) -> void:
	load_replay_button.disabled = false
	load_replay_button.text = "Load Replay"
	if not success:
		push_error("Failed to load replay")
		return
	_setup_timeline()

func _get_duration() -> float:
	var data := replay_player.recording
	if data == null or data.frames.is_empty():
		return 0.0
	return (data.frames.size() - 1) * data.frame_dt

func _setup_timeline() -> void:
	var duration := _get_duration()
	timeline.editable = duration > 0.0
	timeline.max_value = maxf(duration, 0.001)
	timeline.set_value_no_signal(0.0)
	play_button.disabled = duration <= 0.0
	replay_player.playback_time = 0.0
	replay_player.apply_frame(0.0)
	_set_playing(false)
	_update_time_label()
	keyframe_track.queue_redraw()

func _on_timeline_changed(value: float) -> void:
	if replay_player.recording == null:
		return
	_set_playing(false)
	replay_player.playback_time = value
	replay_player.apply_frame(value)
	_update_time_label()
	
func _on_play_pressed() -> void:
	if replay_player.recording == null:
		return
	if not replay_player.playing and replay_player.playback_time >= _get_duration():
		replay_player.playback_time = 0.0
		replay_player.apply_frame(0.0)
		timeline.set_value_no_signal(0.0)
	_set_playing(not replay_player.playing)

func _set_playing(value: bool) -> void:
	replay_player.playing = value
	_update_play_button()

func _update_play_button() -> void:
	play_button.text = "Pause" if replay_player.playing else "Play"

func _update_time_label() -> void:
	time_label.text = "%s/%s" % [_format_time(replay_player.playback_time), _format_time(_get_duration())]

func _format_time(seconds: float) -> String:
	var total := int(floor(seconds))
	@warning_ignore("integer_division")
	return "%d:%02d" % [total / 60, total % 60]

func _apply_follow() -> void:
	var view := replay_camera.sample(replay_player.playback_time)
	if view.is_empty():
		return
	editor_camera.apply_view(view["pos"], view["rot"], view["fov"])

func _on_add_keyframe_pressed() -> void:
	if replay_player.recording == null:
		return
	var time := snappedf(replay_player.playback_time, replay_player.recording.frame_dt)
	var view := editor_camera.get_view()
	var index := replay_camera.add_keyframe(time, view["pos"], view["rot"], view["fov"])
	selected_keyframe = index
	_refresh_keyframes()

func _on_delete_keyframe_pressed() -> void:
	if selected_keyframe == -1:
		return
	var index := selected_keyframe
	selected_keyframe = -1
	replay_camera.remove_keyframe(index)

func _select_keyframe(index: int) -> void:
	if index < 0 or index >= replay_camera.keyframes.size():
		return
	selected_keyframe = index
	var kf := replay_camera.keyframes[index]
	_set_playing(false)
	replay_player.playback_time = kf["time"]
	replay_player.apply_frame(kf["time"])
	timeline.set_value_no_signal(kf["time"])
	editor_camera.apply_view(kf["pos"], kf["rot"], kf["fov"])
	_refresh_keyframes()
	_update_time_label()

func _on_transform_edited(_value: float) -> void:
	if selected_keyframe == -1:
		return
	var pos := Vector3(pos_x.value, pos_y.value, pos_z.value)
	var rot := Vector3(deg_to_rad(rot_x.value), deg_to_rad(rot_y.value), deg_to_rad(rot_z.value))
	replay_camera.update_keyframe(selected_keyframe, pos, rot, fov_field.value)
	editor_camera.apply_view(pos, rot, fov_field.value)

func _on_follow_toggled(pressed: bool) -> void:
	print("follow toggled: ", pressed, " keyframes: ", replay_camera.keyframes.size())
	if pressed and replay_camera.keyframes.is_empty():
		follow_button.set_pressed_no_signal(false)
		return
	editor_camera.following = pressed

func _on_follow_interrupted() -> void:
	print("follow interrupted")
	follow_button.set_pressed_no_signal(false)

func _refresh_keyframes() -> void:
	if selected_keyframe >= replay_camera.keyframes.size():
		selected_keyframe = -1
	keyframe_track.set_keyframes(replay_camera.get_times(), selected_keyframe)
	var has_selection := selected_keyframe != -1
	delete_keyframe_button.disabled = not has_selection
	for field in transform_fields:
		field.editable = has_selection
	if has_selection:
		_load_fields()
	if replay_camera.keyframes.is_empty() and editor_camera.following:
		editor_camera.following = false
		follow_button.set_pressed_no_signal(false)

func _load_fields() -> void:
	var kf := replay_camera.keyframes[selected_keyframe]
	pos_x.set_value_no_signal(kf["pos"].x)
	pos_y.set_value_no_signal(kf["pos"].y)
	pos_z.set_value_no_signal(kf["pos"].z)
	rot_x.set_value_no_signal(rad_to_deg(kf["rot"].x))
	rot_y.set_value_no_signal(rad_to_deg(kf["rot"].y))
	rot_z.set_value_no_signal(rad_to_deg(kf["rot"].z))
	fov_field.set_value_no_signal(kf["fov"])

func populate_replay_options() -> void:
	select_file.clear()

	var dir = DirAccess.open(REPLAY_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()

		while file_name != "":
			if !dir.current_is_dir() and file_name.ends_with(REPLAY_EXT):
				var clean_name = file_name.replace(REPLAY_EXT, "")
				var full_path = REPLAY_DIR.path_join(file_name)

				select_file.add_item(clean_name)
				select_file.set_item_metadata(select_file.get_item_count() - 1, full_path)

			file_name = dir.get_next()
		dir.list_dir_end()
	else:
		print("Failed to open replay directory: ", REPLAY_DIR)
