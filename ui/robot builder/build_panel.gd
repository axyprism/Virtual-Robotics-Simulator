class_name BuildPanel
extends VBoxContainer

var editor: RobotEditor
var selection: Node3D
var tree: Tree
var properties: PropertiesPanel
var drivetrain_options: OptionButton
var subsystem_options: OptionButton
var shape_options: OptionButton
var model_options: OptionButton
var collision_check: CheckBox
var remove_button: Button


func setup(robot_editor: RobotEditor) -> void:
	editor = robot_editor
	drivetrain_options = OptionButton.new()
	add_child(drivetrain_options)
	add_child(make_button("Set Drivetrain", on_set_drivetrain))
	subsystem_options = OptionButton.new()
	add_child(subsystem_options)
	add_child(make_button("Add Subsystem", on_add_subsystem))
	collision_check = CheckBox.new()
	collision_check.text = "Auto collision"
	collision_check.button_pressed = true
	add_child(collision_check)
	shape_options = OptionButton.new()
	for shape in RobotParts.SHAPES:
		shape_options.add_item(shape)
	add_child(shape_options)
	add_child(make_button("Add Primitive", on_add_primitive))
	model_options = OptionButton.new()
	add_child(model_options)
	add_child(make_button("Add Model", on_add_model))
	tree = Tree.new()
	tree.hide_root = true
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.custom_minimum_size.y = 200
	tree.item_selected.connect(on_item_selected)
	tree.nothing_selected.connect(on_nothing_selected)
	add_child(tree)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	properties = PropertiesPanel.new()
	properties.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(properties)
	add_child(scroll)
	remove_button = make_button("Remove", on_remove)
	add_child(remove_button)
	discover_parts()
	refresh_tree()


func make_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	return button


func discover_parts() -> void:
	for info in ProjectSettings.get_global_class_list():
		var script := load(info["path"]) as Script
		if script == null or not script.has_method("build"):
			continue
		if not script_inherits(script, Subsystem):
			continue
		var target: OptionButton = drivetrain_options if script.call("is_drivetrain") else subsystem_options
		target.add_item(str(info["class"]))
		target.set_item_metadata(target.item_count - 1, script)
	for path in list_models():
		model_options.add_item(path.get_file())
		model_options.set_item_metadata(model_options.item_count - 1, path)


func script_inherits(script: Script, target: Script) -> bool:
	var current := script
	while current != null:
		if current == target:
			return true
		current = current.get_base_script()
	return false

func list_models() -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(editor.models_dir)
	if dir == null:
		return result
	for file in dir.get_files():
		var file_name := file.trim_suffix(".remap")
		if file_name.ends_with(".glb") or file_name.ends_with(".gltf"):
			result.append(editor.models_dir.path_join(file_name))
	return result


func show_selection() -> void:
	refresh_tree()
	properties.inspect(selection)


func refresh_tree() -> void:
	tree.clear()
	if editor.drivetrain != null:
		var root := tree.create_item()
		add_tree_item(editor.drivetrain, root)
	update_state()


func add_tree_item(node: Node, parent_item: TreeItem) -> void:
	var item := tree.create_item(parent_item)
	item.set_text(0, item_label(node))
	item.set_metadata(0, node)
	if node == selection:
		item.select(0)
	if node is Subsystem:
		collect_items(node, item)


func collect_items(node: Node, item: TreeItem) -> void:
	for child in node.get_children():
		if child is Subsystem or RobotParts.is_part(child):
			add_tree_item(child, item)
		else:
			collect_items(child, item)


func item_label(node: Node) -> String:
	if node is Subsystem:
		var id := str(node.get("subsystem_id"))
		if id != "":
			return id
	return str(node.name)


func update_state() -> void:
	remove_button.disabled = selection == null or selection == editor.drivetrain


func on_item_selected() -> void:
	var item := tree.get_selected()
	if item == null:
		return
	selection = item.get_metadata(0) as Node3D
	properties.inspect(selection)
	update_state()


func on_nothing_selected() -> void:
	selection = null
	properties.inspect(null)
	update_state()


func find_subsystem(from: Node) -> Node3D:
	var node := from
	while node != null and node != editor.manager:
		if node is Subsystem:
			return node as Node3D
		node = node.get_parent()
	return editor.drivetrain


func display_id(text: String) -> String:
	return text.replace("Subsystem", "")


func make_unique_id(base: String) -> StringName:
	var ids: Array[StringName] = []
	for subsystem in editor.get_subsystems():
		ids.append(StringName(str(subsystem.get("subsystem_id"))))
	var candidate := base
	var index := 2
	while ids.has(StringName(candidate)):
		candidate = "%s%d" % [base, index]
		index += 1
	return StringName(candidate)


func on_set_drivetrain() -> void:
	if drivetrain_options.selected == -1:
		return
	var script: Script = drivetrain_options.get_item_metadata(drivetrain_options.selected)
	if editor.drivetrain != null:
		editor.manager.remove_child(editor.drivetrain)
		editor.drivetrain.queue_free()
		editor.drivetrain = null
	editor.drivetrain = script.call("build")
	editor.drivetrain.set("subsystem_id", make_unique_id(display_id(drivetrain_options.get_item_text(drivetrain_options.selected))))
	editor.manager.add_child(editor.drivetrain)
	selection = editor.drivetrain
	show_selection()


func on_add_subsystem() -> void:
	var target := find_subsystem(selection)
	if target == null or subsystem_options.selected == -1:
		return
	var script: Script = subsystem_options.get_item_metadata(subsystem_options.selected)
	var instance: Node3D = script.call("build")
	instance.set("subsystem_id", make_unique_id(display_id(subsystem_options.get_item_text(subsystem_options.selected))))
	(target as Subsystem).get_mount().add_child(instance, true)
	selection = instance
	show_selection()


func on_add_primitive() -> void:
	var target := find_subsystem(selection)
	if target == null:
		return
	var shape := shape_options.get_item_text(shape_options.selected)
	var mount := (target as Subsystem).get_mount()
	selection = RobotParts.add_primitive(mount, shape, Vector3(0.1, 0.1, 0.1), Color(0.6, 0.6, 0.6), collision_check.button_pressed)
	show_selection()


func on_add_model() -> void:
	var target := find_subsystem(selection)
	if target == null or model_options.selected == -1:
		return
	var path: String = model_options.get_item_metadata(model_options.selected)
	var mount := (target as Subsystem).get_mount()
	var part := RobotParts.add_model(mount, path, collision_check.button_pressed)
	if part == null:
		return
	selection = part
	show_selection()


func on_remove() -> void:
	if selection == null or selection == editor.drivetrain:
		return
	var parent := selection.get_parent()
	if RobotParts.is_part(selection):
		RobotParts.remove_part(selection)
	else:
		parent.remove_child(selection)
		selection.queue_free()
	selection = find_subsystem(parent)
	show_selection()
