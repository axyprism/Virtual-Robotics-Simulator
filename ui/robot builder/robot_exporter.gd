class_name RobotExporter
extends Node

var editor: RobotEditor
var dialog: FileDialog


func setup(robot_editor: RobotEditor) -> void:
	editor = robot_editor
	dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = PackedStringArray(["*.tscn"])
	dialog.file_selected.connect(export_robot)
	add_child(dialog)


func open() -> void:
	dialog.popup_centered_ratio(0.6)


func set_owners(node: Node, root: Node) -> void:
	for child in node.get_children():
		child.owner = root
		if child.scene_file_path == "":
			set_owners(child, root)


func export_robot(path: String) -> void:
	if editor.drivetrain == null:
		return
	var root := editor.robot_root
	root.process_mode = Node.PROCESS_MODE_INHERIT
	if editor.root_script != null:
		root.set_script(editor.root_script)
	var runner := ScriptRunner.new()
	runner.name = "ScriptRunner"
	runner.robot_script = editor.script_data
	root.add_child(runner)
	set_owners(root, root)
	var packed := PackedScene.new()
	var error := packed.pack(root)
	if error == OK:
		error = ResourceSaver.save(packed, path)
	if error != OK:
		push_error("Export failed: %s" % error_string(error))
	root.remove_child(runner)
	runner.free()
	if editor.root_script != null:
		root.set_script(null)
	root.process_mode = Node.PROCESS_MODE_DISABLED
