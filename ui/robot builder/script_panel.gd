class_name ScriptPanel
extends VBoxContainer

var editor: RobotEditor
var list: VBoxContainer
var registry: Dictionary = {}


func setup(robot_editor: RobotEditor) -> void:
	editor = robot_editor
	registry = CommandRegistry.all()
	var add_button := make_button("Add Binding", on_add_binding)
	add_child(add_button)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	add_child(scroll)
	refresh()


func refresh() -> void:
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	for binding in editor.script_data.bindings:
		list.add_child(build_binding(binding))


func make_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	return button


func list_actions() -> Array[String]:
	var result: Array[String] = []
	for action in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			result.append(String(action))
	result.sort()
	return result


func build_binding(binding: ScriptBinding) -> Control:
	var box := PanelContainer.new()
	var column := VBoxContainer.new()
	box.add_child(column)
	var header := HFlowContainer.new()
	var actions := list_actions()
	var action_options := OptionButton.new()
	for action in actions:
		action_options.add_item(action)
	if not actions.is_empty():
		action_options.select(maxi(actions.find(String(binding.action)), 0))
	action_options.item_selected.connect(on_action_selected.bind(binding, actions))
	header.add_child(action_options)
	var mode_options := OptionButton.new()
	mode_options.add_item("Pressed")
	mode_options.add_item("Held")
	mode_options.select(binding.mode)
	mode_options.item_selected.connect(on_mode_selected.bind(binding))
	header.add_child(mode_options)
	header.add_child(make_button("Remove", on_remove_binding.bind(binding)))
	column.add_child(header)
	column.add_child(build_command(binding.command, null))
	return box


func build_command(node: CommandNode, parent: CommandNode) -> Control:
	if node.is_group():
		return build_group(node, parent)
	return build_leaf(node, parent)


func build_group(node: CommandNode, parent: CommandNode) -> Control:
	var column := VBoxContainer.new()
	var header := HFlowContainer.new()
	var type_options := OptionButton.new()
	type_options.add_item("Sequence")
	type_options.add_item("Parallel")
	type_options.select(0 if node.type == &"Sequence" else 1)
	type_options.item_selected.connect(on_group_type_selected.bind(node))
	header.add_child(type_options)
	var add_options := OptionButton.new()
	add_options.add_item("Sequence")
	add_options.add_item("Parallel")
	for type in registry:
		add_options.add_item(String(type))
	header.add_child(add_options)
	header.add_child(make_button("Add", on_add_child.bind(node, add_options)))
	if parent != null:
		header.add_child(make_button("X", on_remove_child.bind(parent, node)))
	column.add_child(header)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	var children_box := VBoxContainer.new()
	for child in node.children:
		children_box.add_child(build_command(child, node))
	margin.add_child(children_box)
	column.add_child(margin)
	return column


func build_leaf(node: CommandNode, parent: CommandNode) -> Control:
	var row := HFlowContainer.new()
	var label := Label.new()
	label.text = String(node.type)
	row.add_child(label)
	var script: Script = registry.get(node.type)
	if script != null:
		for param in script.call("describe"):
			row.add_child(build_param(node, param))
	row.add_child(make_button("X", on_remove_child.bind(parent, node)))
	return row


func build_param(node: CommandNode, param: Dictionary) -> Control:
	var key := String(param["name"])
	var holder := HBoxContainer.new()
	var label := Label.new()
	label.text = key
	holder.add_child(label)
	match param["type"]:
		"float":
			var box := SpinBox.new()
			box.min_value = -10000.0
			box.max_value = 10000.0
			box.step = 0.01
			box.allow_greater = true
			box.allow_lesser = true
			box.value = float(node.args.get(key, param.get("default", 0.0)))
			box.value_changed.connect(on_arg_changed.bind(node, key))
			holder.add_child(box)
		"bool":
			var check := CheckBox.new()
			check.button_pressed = bool(node.args.get(key, param.get("default", false)))
			check.toggled.connect(on_arg_changed.bind(node, key))
			holder.add_child(check)
		"subsystem":
			var options := OptionButton.new()
			var ids := matching_ids(param["class"])
			for id in ids:
				options.add_item(id)
			var current := String(node.args.get(key, ""))
			if ids.has(current):
				options.select(ids.find(current))
			elif not ids.is_empty():
				options.select(0)
				node.args[key] = ids[0]
			options.item_selected.connect(on_subsystem_selected.bind(node, key, options))
			holder.add_child(options)
	return holder


func matching_ids(target: Script) -> Array[String]:
	var result: Array[String] = []
	for subsystem in editor.get_subsystems():
		var id := str(subsystem.get("subsystem_id"))
		if id != "" and script_inherits(subsystem.get_script(), target):
			result.append(id)
	return result


func script_inherits(script: Script, target: Script) -> bool:
	var current := script
	while current != null:
		if current == target:
			return true
		current = current.get_base_script()
	return false


func make_node(type: StringName) -> CommandNode:
	var node := CommandNode.new()
	node.type = type
	var script: Script = registry.get(type)
	if script != null:
		for param in script.call("describe"):
			if param.has("default"):
				node.args[String(param["name"])] = param["default"]
	return node


func on_add_binding() -> void:
	var binding := ScriptBinding.new()
	var actions := list_actions()
	if not actions.is_empty():
		binding.action = StringName(actions[0])
	binding.command = CommandNode.new()
	editor.script_data.bindings.append(binding)
	refresh()


func on_remove_binding(binding: ScriptBinding) -> void:
	editor.script_data.bindings.erase(binding)
	refresh()


func on_action_selected(index: int, binding: ScriptBinding, actions: Array[String]) -> void:
	binding.action = StringName(actions[index])


func on_mode_selected(index: int, binding: ScriptBinding) -> void:
	binding.mode = index as ScriptBinding.Mode


func on_group_type_selected(index: int, node: CommandNode) -> void:
	node.type = &"Sequence" if index == 0 else &"Parallel"


func on_add_child(node: CommandNode, options: OptionButton) -> void:
	node.children.append(make_node(StringName(options.get_item_text(options.selected))))
	refresh()


func on_remove_child(parent: CommandNode, node: CommandNode) -> void:
	parent.children.erase(node)
	refresh()


func on_arg_changed(value: Variant, node: CommandNode, key: String) -> void:
	node.args[key] = value


func on_subsystem_selected(index: int, node: CommandNode, key: String, options: OptionButton) -> void:
	node.args[key] = options.get_item_text(index)
