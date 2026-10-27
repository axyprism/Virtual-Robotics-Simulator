class_name RobotEditor
extends CanvasLayer

@export var models_dir: String = "res://assets/models"
@export var root_script: Script

@onready var container: SubViewportContainer = $RobotContainer/SubViewportContainer
@onready var pivot: Node3D = $RobotContainer/SubViewportContainer/SubViewport/Pivot
@onready var camera: Camera3D = $RobotContainer/SubViewportContainer/SubViewport/Pivot/Camera3D
@onready var panel: VBoxContainer = $Control/PanelContainer/VBoxContainer
@onready var robot_root: Node3D = $RobotContainer/Robot

var manager: Node
var drivetrain: Node3D
var script_data: RobotScript = RobotScript.new()
var script_panel: ScriptPanel
var exporter: RobotExporter


func _ready() -> void:
	robot_root.process_mode = Node.PROCESS_MODE_DISABLED
	manager = SubsystemManager.new()
	manager.name = "SubsystemManager"
	manager.add_to_group("subsystem_managers", true)
	robot_root.add_child(manager)
	CommandScheduler.unregister_manager(manager)
	manager.name = "SubsystemManager"
	manager.add_to_group("subsystem_managers", true)
	robot_root.add_child(manager)
	var editor_camera := EditorCamera.new()
	add_child(editor_camera)
	editor_camera.setup(container, pivot, camera)
	exporter = RobotExporter.new()
	add_child(exporter)
	exporter.setup(self)
	for child in panel.get_children():
		child.queue_free()
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(tabs)
	var build_panel := BuildPanel.new()
	build_panel.name = "Build"
	tabs.add_child(build_panel)
	build_panel.setup(self)
	script_panel = ScriptPanel.new()
	script_panel.name = "Script"
	tabs.add_child(script_panel)
	script_panel.setup(self)
	tabs.tab_changed.connect(on_tab_changed)
	var export_button := Button.new()
	export_button.text = "Export"
	export_button.pressed.connect(exporter.open)
	panel.add_child(export_button)


func on_tab_changed(_index: int) -> void:
	script_panel.refresh()


func get_subsystems() -> Array[Node]:
	var result: Array[Node] = []
	collect_subsystems(manager, result)
	return result


func collect_subsystems(node: Node, result: Array[Node]) -> void:
	for child in node.get_children():
		if child is Subsystem:
			result.append(child)
		collect_subsystems(child, result)
