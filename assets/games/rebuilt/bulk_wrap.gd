@tool
extends EditorScript

# Change "Node2D" to "Node3D" or "Control" depending on your node types
const PARENT_NODE_TYPE = "RigidBody3D" 

func _run() -> void:
	var interface := get_editor_interface()
	var selection := interface.get_selection()
	var selected_nodes := selection.get_selected_nodes()
	
	if selected_nodes.is_empty():
		print("No nodes selected!")
		return
		
	var scene_root := interface.get_edited_scene_root()
	
	# Loop through each selected node individually
	for node in selected_nodes:
		var current_parent := node.get_parent()
		if not current_parent:
			continue
			
		# 1. Create the new independent parent
		var new_parent = ClassDB.instantiate(PARENT_NODE_TYPE)
		new_parent.name = node.name + "Parent"
		
		# 2. Insert the new parent into the scene tree right above the node
		current_parent.add_child(new_parent)
		new_parent.owner = scene_root # Makes it visible and savable in the editor
		
		# If dealing with spatial nodes, match positions before reparenting
		if node is Node2D and new_parent is Node2D:
			new_parent.global_position = node.global_position
		elif node is Node3D and new_parent is Node3D:
			new_parent.global_transform = node.global_transform
			
		# 3. Move the original node into its new unique parent
		node.reparent(new_parent, true)
		node.owner = scene_root
