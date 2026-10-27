extends Node
class_name ReplayExporter

var output_dir: String = "user://replay_export/"
var frame_rate: int = 30
var _frame_index: int = 0
var _exporting: bool = false
var _viewport: Viewport

func start_export(viewport: Viewport) -> void:
	_viewport = viewport
	_frame_index = 0
	_exporting = true
	DirAccess.make_dir_recursive_absolute(output_dir)

func stop_export() -> void:
	_exporting = false

func capture_frame() -> void:
	if not _exporting:
		return
	var image := _viewport.get_texture().get_image()
	var path := output_dir + "frame_%05d.png" % _frame_index
	image.save_png(path)
	_frame_index += 1

func get_ffmpeg_command(output_path: String) -> String:
	var real_dir := ProjectSettings.globalize_path(output_dir)
	return "ffmpeg -framerate %d -i \"%sframe_%%05d.png\" -c:v libx264 -pix_fmt yuv420p \"%s\"" % [frame_rate, real_dir, output_path]
