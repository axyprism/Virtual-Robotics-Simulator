class_name Player
extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const SYNC_INTERVAL = 0.05

@export var camera_track_speed: float = 4.0 
@export var advanced_pitch_offset_deg: float = -8.0
@export var advanced_min_horizontal_dist: float = 2.0 

@onready var neck: Node3D = $Neck
@onready var camera: Camera3D = $Neck/Camera3D
@onready var remote_visual: MeshInstance3D = $RemoteVisual

var _controlled: bool = true

func _enter_tree() -> void:
	if name.begins_with("Player_"):
		var id := int(name.split("_")[1])
		set_multiplayer_authority(id)

func _ready() -> void:
	if not is_multiplayer_authority():
		remote_visual.visible = true
		set_physics_process(false)
		set_process_unhandled_input(false)
		return
	remote_visual.visible = false
	camera.current = true
	if not VRManager.is_vr:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	ControlManager.target_changed.connect(_on_control_target_changed)
	CameraSettings.camera_mode_changed.connect(_on_camera_mode_changed)

func _on_control_target_changed(_new_target) -> void:
	if CameraSettings.is_advanced():
		camera.current = true

func _on_camera_mode_changed(_mode) -> void:
	if CameraSettings.is_advanced():
		camera.current = true

func set_controlled(value: bool) -> void:
	_controlled = value
	if not _controlled:
		velocity.x = 0.0
		velocity.z = 0.0
		if not VRManager.is_vr:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		camera.current = true
		if not VRManager.is_vr:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		return
	if event.is_action_pressed("SwitchControl"):
		ControlManager.toggle()
		return
	if not _controlled:
		return
	if event is InputEventMouseButton:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseMotion:
			neck.rotate_y(-event.relative.x * 0.01)
			camera.rotate_x(-event.relative.y * 0.01)
			camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-89), deg_to_rad(89))

func _physics_process(delta: float) -> void:
	if not multiplayer.has_multiplayer_peer():
		return
	if not is_multiplayer_authority():
		return

	if not is_on_floor():
		velocity += get_gravity() * delta
	if not _controlled:
		if CameraSettings.is_advanced():
			_track_robot(delta)
		move_and_slide()
		return

	var input_dir := Input.get_vector("MoveLeft", "MoveRight", "MoveForward", "MoveBack")
	var direction = (neck.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
	move_and_slide()

func _track_robot(delta: float) -> void:
	var robot := ControlManager.get_active_robot()
	if robot == null:
		return
	var to_robot: Vector3 = robot.global_position - neck.global_position
	var horizontal := Vector3(to_robot.x, 0, to_robot.z)
	if horizontal.length_squared() < 0.0001:
		return
	var target_yaw := atan2(-to_robot.x, -to_robot.z)
	var clamped_horizontal := maxf(horizontal.length(), advanced_min_horizontal_dist)
	var target_pitch = clamp(
		atan2(to_robot.y, clamped_horizontal) + deg_to_rad(advanced_pitch_offset_deg),
		deg_to_rad(-89), deg_to_rad(89)
	)
	neck.rotation.y = lerp_angle(neck.rotation.y, target_yaw, delta * camera_track_speed)
	camera.rotation.x = lerp_angle(camera.rotation.x, target_pitch, delta * camera_track_speed)
