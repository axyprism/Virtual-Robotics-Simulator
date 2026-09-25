class_name VRPlayer
extends XROrigin3D

const SPEED := 5.0

@onready var camera: XRCamera3D = $XRCamera3D
@onready var left_hand: XRController3D = $LeftController
@onready var right_hand: XRController3D = $RightController
@onready var remote_visual: MeshInstance3D = $RemoteVisual

var _controlled: bool = true

func _ready() -> void:
	if not is_multiplayer_authority():
		remote_visual.visible = true
		set_physics_process(false)
		return
	remote_visual.visible = false
	left_hand.button_pressed.connect(_on_controller_button)
	
func _on_controller_button(name: String) -> void:
	if name == "menu_button":
		get_tree().get_first_node_in_group("UI")._toggle()

func set_controlled(value: bool) -> void:
	_controlled = value

func _physics_process(delta: float) -> void:
	if not multiplayer.has_multiplayer_peer():
		return
	if not is_multiplayer_authority():
		return
	if not _controlled:
		return

	var axis := left_hand.get_vector2("primary")
	if axis.length() > 0.1:
		var forward := -camera.global_transform.basis.z
		var right := camera.global_transform.basis.x
		forward.y = 0.0
		right.y = 0.0
		var move := (forward * -axis.y + right * axis.x).normalized()
		global_position += move * SPEED * delta
