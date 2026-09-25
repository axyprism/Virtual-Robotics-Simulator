extends Node

var is_vr: bool = false

func _ready() -> void:
	var xr_interface = XRServer.find_interface("XRSimulator")
	if not xr_interface:
		xr_interface = XRServer.find_interface("OpenXR")
	
	if xr_interface and xr_interface.initialize():
		is_vr = true
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		get_viewport().use_xr = true
		print("VR mode")
	else:
		is_vr = false
		get_viewport().use_xr = false
		print("PC mode")
