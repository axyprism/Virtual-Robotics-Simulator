extends Node
enum CameraMode { BASIC, ADVANCED }

const KEY := "camera_mode"

signal camera_mode_changed(mode: CameraMode)

var camera_mode: CameraMode:
	get:
		return Settings.get_value(KEY, CameraMode.BASIC)

func _ready() -> void:
	Settings.set_default(KEY, CameraMode.BASIC)
	Settings.setting_changed.connect(_on_setting_changed)

func set_camera_mode(mode: CameraMode) -> void:
	Settings.set_value(KEY, mode)

func is_advanced() -> bool:
	return camera_mode == CameraMode.ADVANCED

func _on_setting_changed(key: String, value: Variant) -> void:
	if key == KEY:
		camera_mode_changed.emit(value)
