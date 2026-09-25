extends CanvasLayer

signal profile_confirmed(robot_name: String, team_number: String)
signal back_pressed

@export_dir var robots_folder: String = "res://systems/robots/scenes/"
@export var card_size: Vector2 = Vector2(300, 300)
@export var orbit_speed: float = 0.6

@onready var margin: MarginContainer = $MarginContainer
@onready var card_row: HBoxContainer = $MarginContainer/PanelContainer/VBoxContainer/ItemList/HBoxContainer
@onready var back_button: Button = $MarginContainer/PanelContainer/VBoxContainer/BackButton
@onready var team_number_field: LineEdit = $MarginContainer/PanelContainer/VBoxContainer/TeamNumberField

var pivots: Array[Node3D] = []


func _ready() -> void:
	back_button.pressed.connect(func(): back_pressed.emit())
	build_cards()


func _process(delta: float) -> void:
	for pivot in pivots:
		pivot.rotate_y(orbit_speed * delta)


func build_cards() -> void:
	var template: Control = card_row.get_child(0)
	for child in card_row.get_children():
		card_row.remove_child(child)
		if child != template:
			child.queue_free()
	for path in get_allowed_robots():
		add_card(template, path)
	template.queue_free()

func get_allowed_robots() -> Array[String]:
	var game := GameManager.current_game
	if game == null:
		return []
	var paths: Array[String] = []
	for scene in game.allowed_robots:
		if scene != null:
			paths.append(scene.resource_path)
	return paths


func add_card(template: Control, scene_path: String) -> void:
	var scene := load(scene_path) as PackedScene
	if scene == null:
		return
	var card: Control = template.duplicate()
	card_row.add_child(card)
	var name_label: Label = card.get_node("RobotName")
	name_label.text = scene_path.get_file().get_basename()
	var container: SubViewportContainer = card.get_node("SubViewportContainer")
	container.stretch = true
	container.custom_minimum_size = card_size
	var select_button: Button = card.get_node("SelectButton")
	var robot_name := scene_path.get_file().get_basename()
	select_button.pressed.connect(func(): _on_select_pressed(robot_name))
	setup_viewport(container.get_node("SubViewport"), scene)


func _on_select_pressed(robot_name: String) -> void:
	var team_number := team_number_field.text.strip_edges()
	if team_number.is_empty():
		team_number_field.placeholder_text = "Enter your team number first"
		return
	profile_confirmed.emit(robot_name, team_number)


func setup_viewport(viewport: SubViewport, scene: PackedScene) -> void:
	viewport.own_world_3d = true
	var robot: Node3D = scene.instantiate()
	robot.process_mode = Node.PROCESS_MODE_DISABLED
	viewport.add_child(robot)
	var sync = robot.get_node_or_null("Sync")
	if sync:
		sync.queue_free()
	var subsystems := robot.get_node_or_null("SubsystemManager")
	if subsystems:
		CommandScheduler.unregister_manager(subsystems)
	var bounds := get_bounds(robot)
	var center := bounds.get_center()
	var radius := maxf(bounds.size.length() * 0.5, 0.5)
	var pivot := Node3D.new()
	pivot.position = center
	viewport.add_child(pivot)
	var camera := Camera3D.new()
	camera.fov = 40.0
	camera.environment = make_environment()
	pivot.add_child(camera)
	camera.position = Vector3(0.0, radius * 0.6, radius / sin(deg_to_rad(camera.fov * 0.5)))
	camera.look_at(center)
	camera.current = true
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-30.0, -30.0, 0.0)
	camera.add_child(light)
	pivots.append(pivot)

func get_bounds(root: Node) -> AABB:
	var bounds := AABB()
	var found := false
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var box := mesh.global_transform * mesh.get_aabb()
		if found:
			bounds = bounds.merge(box)
		else:
			bounds = box
			found = true
	return bounds


func make_environment() -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.15, 0.15, 0.18)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.5
	return env
