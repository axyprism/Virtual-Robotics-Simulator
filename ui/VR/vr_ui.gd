extends Node3D

@onready var viewport: SubViewport = $SubViewport

func attach_canvas(canvas_layer: CanvasLayer) -> void:
	canvas_layer.reparent(viewport)
	global_position = VRManager.get_parent().global_position + Vector3(0, 1.5, -1.5)
