class_name EditorCamera
extends Node

signal follow_interrupted

var following: bool = false
var blocked_controls: Array[Control] = []
var orbit_speed: float = 0.005
var pan_speed: float = 0.001
var zoom_factor: float = 1.1
var trackpad_zoom_speed: float = 0.05
var min_distance: float = 0.5
var max_distance: float = 50.0
var distance: float = 5.0
var dragging: bool = false
var container: SubViewportContainer
var pivot: Node3D
var camera: Camera3D


func setup(view_container: SubViewportContainer, view_pivot: Node3D, view_camera: Camera3D) -> void:
	container = view_container
	pivot = view_pivot
	camera = view_camera
	camera.position = Vector3(0, 0, distance)
	pivot.rotation.x = deg_to_rad(-25.0)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var inside: bool = _is_inside(event.position)
		if event.button_index == MOUSE_BUTTON_RIGHT:
			dragging = event.pressed and inside
		elif event.pressed and inside:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				zoom(1.0 / zoom_factor)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				zoom(zoom_factor)
	elif event is InputEventMouseMotion and dragging:
		if Input.is_key_pressed(KEY_SHIFT):
			pan(event.relative)
		else:
			orbit(event.relative)
	elif event is InputEventPanGesture:
		if _is_inside(event.position):
			zoom(1.0 + event.delta.y * trackpad_zoom_speed)
	elif event is InputEventMagnifyGesture:
		if _is_inside(event.position):
			zoom(1.0 / event.factor)


func orbit(relative: Vector2) -> void:
	pivot.rotation.y -= relative.x * orbit_speed
	pivot.rotation.x = clamp(pivot.rotation.x - relative.y * orbit_speed, -PI / 2.0 + 0.01, PI / 2.0 - 0.01)


func pan(relative: Vector2) -> void:
	var basis: Basis = pivot.global_transform.basis
	var offset: Vector3 = basis.x * -relative.x + basis.y * relative.y
	pivot.position += offset * pan_speed * distance


func zoom(factor: float) -> void:
	distance = clamp(distance * factor, min_distance, max_distance)
	camera.position = Vector3(0, 0, distance)

func get_view() -> Dictionary:
	return {
		"pos": camera.global_position,
		"rot": camera.global_rotation,
		"fov": camera.fov
	}

func apply_view(pos: Vector3, rot: Vector3, fov: float) -> void:
	pivot.global_rotation = rot
	pivot.global_position = pos - pivot.global_transform.basis.z * distance
	camera.fov = fov

func _interrupt_follow() -> void:
	if following:
		following = false
		follow_interrupted.emit()

func _is_inside(point: Vector2) -> bool:
	if not container.get_global_rect().has_point(point):
		return false
	for control in blocked_controls:
		if control.is_visible_in_tree() and control.get_global_rect().has_point(point):
			return false
	return true
