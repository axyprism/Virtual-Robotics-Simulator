class_name Player
extends CharacterBody3D

const SPEED         = 5.0
const JUMP_VELOCITY = 4.5
## How often the authority peer broadcasts its state (seconds)
const SYNC_INTERVAL = 0.05

@onready var neck:          Node3D         = $Neck
@onready var camera:        Camera3D       = $Neck/Camera3D
@onready var remote_visual: MeshInstance3D = $RemoteVisual

var _controlled:   bool  = true

func _ready() -> void:
	if not is_multiplayer_authority():
		remote_visual.visible = true
		set_physics_process(false)
		set_process_unhandled_input(false)
		return
	remote_visual.visible = false
	camera.current        = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func set_controlled(value: bool) -> void:
	_controlled = value
	if not _controlled:
		velocity.x = 0.0
		velocity.z = 0.0
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		camera.current = true
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		return
	if event.is_action_pressed("SwitchControl"):
		print("attempting to switch")
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
	## Guard: no peer assigned yet (can happen on first frame)
	if not multiplayer.has_multiplayer_peer():
		return
	if not is_multiplayer_authority():
		return

	if not is_on_floor():
		velocity += get_gravity() * delta
	if not _controlled:
		move_and_slide()
		return

	var input_dir := Input.get_vector("MoveLeft", "MoveRight", "MoveForward", "MoveBack")
	var direction  = (neck.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
	move_and_slide()
