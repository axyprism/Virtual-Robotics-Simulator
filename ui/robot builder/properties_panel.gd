class_name PropertiesPanel
extends VBoxContainer

var target: Node3D
var position_boxes: Array[SpinBox] = []
var rotation_boxes: Array[SpinBox] = []
var size_boxes: Array[SpinBox] = []


func inspect(node: Node3D) -> void:
	target = node
	for child in get_children():
		remove_child(child)
		child.queue_free()
	position_boxes.clear()
	rotation_boxes.clear()
	size_boxes.clear()
	if target == null:
		return
	add_child(make_row("Position", target.position, position_boxes, 0.001, on_transform_changed))
	add_child(make_row("Rotation", target.rotation_degrees, rotation_boxes, 0.1, on_transform_changed))
	if RobotParts.is_part(target):
		build_part_props()


func build_part_props() -> void:
	if target.get_meta("kind") == "primitive":
		var shape_option := OptionButton.new()
		for shape in RobotParts.SHAPES:
			shape_option.add_item(shape)
		shape_option.select(RobotParts.SHAPES.find(target.get_meta("shape")))
		shape_option.item_selected.connect(on_shape_selected)
		add_child(shape_option)
		add_child(make_row("Size", target.get_meta("size"), size_boxes, 0.001, on_size_changed))
		var color_button := ColorPickerButton.new()
		color_button.color = target.get_meta("color")
		color_button.color_changed.connect(on_color_changed)
		add_child(color_button)
	var collision_box := CheckBox.new()
	collision_box.text = "Collision"
	collision_box.button_pressed = target.get_meta("collision", false)
	collision_box.toggled.connect(on_collision_toggled)
	add_child(collision_box)


func make_row(title: String, value: Vector3, boxes: Array[SpinBox], step: float, callback: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = title
	label.custom_minimum_size.x = 70
	row.add_child(label)
	for i in 3:
		var box := SpinBox.new()
		box.min_value = -1000.0
		box.max_value = 1000.0
		box.step = step
		box.allow_greater = true
		box.allow_lesser = true
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.value = value[i]
		box.value_changed.connect(callback)
		boxes.append(box)
		row.add_child(box)
	return row


func read_boxes(boxes: Array[SpinBox]) -> Vector3:
	return Vector3(boxes[0].value, boxes[1].value, boxes[2].value)


func write_boxes(boxes: Array[SpinBox], value: Vector3) -> void:
	for i in 3:
		boxes[i].set_value_no_signal(value[i])


func apply_transform(node: Node3D, new_position: Vector3, new_rotation_deg: Vector3) -> void:
	node.position = new_position
	node.rotation_degrees = new_rotation_deg
	if RobotParts.is_part(node):
		RobotParts.sync_collision(node)


func update_transform_boxes() -> void:
	if target == null:
		return
	write_boxes(position_boxes, target.position)
	write_boxes(rotation_boxes, target.rotation_degrees)


func on_transform_changed(_value: float) -> void:
	if target == null:
		return
	apply_transform(target, read_boxes(position_boxes), read_boxes(rotation_boxes))


func on_size_changed(_value: float) -> void:
	target.set_meta("size", read_boxes(size_boxes).max(Vector3.ONE * 0.001))
	RobotParts.rebuild(target)


func on_shape_selected(index: int) -> void:
	target.set_meta("shape", RobotParts.SHAPES[index])
	RobotParts.rebuild(target)


func on_color_changed(color: Color) -> void:
	target.set_meta("color", color)
	RobotParts.rebuild(target)


func on_collision_toggled(enabled: bool) -> void:
	target.set_meta("collision", enabled)
	RobotParts.rebuild(target)
