extends Node3D

@export var default_distance: float = 5.0
@export var min_distance: float = 1.5
@export var max_distance: float = 12.0
@export var pivot_height: float = 0.5
@export var orbit_sensitivity: float = 0.005
@export var zoom_sensitivity: float = 0.5
@export var follow_speed: float = 8.0
@export var zoom_speed: float = 10.0
@export var default_pitch_deg: float = -25.0
@export var follow_camera_behaviour: bool = true

@onready var camera: Camera3D = $CameraArm/Camera3D
@onready var arm: Node3D = $CameraArm

var _yaw: float = 0.0
var _pitch: float = 0.0
var _target_distance: float
var _current_distance: float
var _active: bool = false

func _ready() -> void:
	top_level = true
	_pitch            = deg_to_rad(default_pitch_deg)
	_target_distance  = default_distance
	_current_distance = default_distance
	camera.current    = false
	if get_parent().is_multiplayer_authority():
		ControlManager.target_changed.connect(_on_target_changed)

func _on_target_changed(new_target: ControlManager.Target) -> void:
	if follow_camera_behaviour:
		_active = (new_target == ControlManager.Target.ROBOT)
		camera.current = _active
		if _active:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventMouseMotion:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			_yaw -= event.relative.x * orbit_sensitivity
			_pitch -= event.relative.y * orbit_sensitivity
			_pitch = clamp(_pitch, deg_to_rad(-89), deg_to_rad(30))
	if event is InputEventMouseButton:
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_target_distance = clamp(
					_target_distance - zoom_sensitivity, min_distance, max_distance
				)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_target_distance = clamp(
					_target_distance + zoom_sensitivity, min_distance, max_distance
				)
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta: float) -> void:
	if not _active:
		return
	_current_distance = lerpf(_current_distance, _target_distance, delta * zoom_speed)
	var target_pos = get_parent().global_position + Vector3(0, pivot_height, 0)
	global_position = global_position.lerp(target_pos, delta * follow_speed)
	rotation.y = _yaw
	arm.rotation.x = _pitch
	camera.position = Vector3(0, 0, _current_distance)
