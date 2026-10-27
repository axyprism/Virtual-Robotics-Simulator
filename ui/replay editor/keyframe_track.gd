class_name KeyframeTrack
extends Control

signal keyframe_clicked(index: int)

var slider: HSlider
var times: Array[float] = []
var selected: int = -1
var marker_size: float = 6.0

func setup(target_slider: HSlider) -> void:
	slider = target_slider

func set_keyframes(new_times: Array[float], new_selected: int) -> void:
	times = new_times
	selected = new_selected
	queue_redraw()

func _time_to_x(t: float) -> float:
	var margin := _get_margin()
	var span := maxf(size.x - margin * 2.0, 1.0)
	var range_length := maxf(slider.max_value - slider.min_value, 0.001)
	return margin + (t - slider.min_value) / range_length * span

func _get_margin() -> float:
	var grabber := slider.get_theme_icon("grabber")
	return grabber.get_width() * 0.5 if grabber else 0.0

func _draw() -> void:
	if slider == null:
		return
	var y := size.y * 0.5
	for i in times.size():
		var x := _time_to_x(times[i])
		var color := Color(1.0, 0.8, 0.2) if i == selected else Color(0.8, 0.8, 0.8)
		var points := PackedVector2Array([
			Vector2(x, y - marker_size),
			Vector2(x + marker_size, y),
			Vector2(x, y + marker_size),
			Vector2(x - marker_size, y)
		])
		draw_colored_polygon(points, color)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var best := -1
		var best_dist := marker_size * 1.5
		for i in times.size():
			var dist := absf(_time_to_x(times[i]) - event.position.x)
			if dist <= best_dist:
				best = i
				best_dist = dist
		if best != -1:
			keyframe_clicked.emit(best)
			accept_event()
