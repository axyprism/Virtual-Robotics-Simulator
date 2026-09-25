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

var _chassis: RigidBody3D = null

func _ready() -> void:
	top_level = true
	_pitch = deg_to_rad(default_pitch_deg)
	_target_distance = default_distance
	_current_distance = default_distance
	camera.current = false
	var robot := _get_robot()
	if robot and robot.is_owned_by_local_peer():
		ControlManager.target_changed.connect(_on_target_changed)
		CameraSettings.camera_mode_changed.connect(_on_camera_mode_changed)

func _get_robot() -> BaseRobot:
	return owner as BaseRobot

func _on_camera_mode_changed(_mode: CameraSettings.CameraMode) -> void:
	_on_target_changed(ControlManager.current)

func _on_target_changed(new_target: ControlManager.Target) -> void:
	if not follow_camera_behaviour:
		return
	var should_be_active := new_target == ControlManager.Target.ROBOT \
		and CameraSettings.camera_mode == CameraSettings.CameraMode.BASIC
	_active = should_be_active
	camera.current = _active
	if _active:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _get_chassis() -> RigidBody3D:
	if _chassis:
		return _chassis
	var robot := _get_robot()
	if robot:
		var manager := robot.get_subsystem_manager()
		if manager:
			_chassis = manager.get_chassis_body()
	return _chassis

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

	var space := get_world_3d().direct_space_state
	var desired_cam_world := arm.global_position + arm.global_transform.basis.z * _current_distance
	var query := PhysicsRayQueryParameters3D.create(global_position, desired_cam_world)
	var chassis := _get_chassis()
	if chassis:
		query.exclude = [chassis.get_rid()]
	var result := space.intersect_ray(query)

	if result:
		var safe_distance := global_position.distance_to(result.position) - 0.2
		camera.position = Vector3(0, 0, max(safe_distance, min_distance))
	else:
		camera.position = Vector3(0, 0, _current_distance)
