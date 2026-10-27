class_name RobotParts
extends RefCounted

const SHAPES: Array[String] = ["Box", "Cylinder", "Sphere"]


static func is_part(node: Node) -> bool:
	return node.has_meta("kind")


static func add_primitive(parent: Node3D, shape: String, size: Vector3, color: Color, with_collision: bool) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = shape
	part.set_meta("kind", "primitive")
	part.set_meta("shape", shape)
	part.set_meta("size", size)
	part.set_meta("color", color)
	part.set_meta("collision", with_collision)
	parent.add_child(part, true)
	rebuild(part)
	return part


static func add_model(parent: Node3D, path: String, with_collision: bool) -> Node3D:
	var scene := load(path) as PackedScene
	if scene == null:
		return null
	var part := scene.instantiate() as Node3D
	part.set_meta("kind", "model")
	part.set_meta("collision", with_collision)
	parent.add_child(part, true)
	rebuild(part)
	return part


static func rebuild(part: Node3D) -> void:
	if part.get_meta("kind") == "primitive":
		var mesh_node := part as MeshInstance3D
		var material := StandardMaterial3D.new()
		material.albedo_color = part.get_meta("color")
		mesh_node.mesh = make_mesh(part.get_meta("shape"), part.get_meta("size"))
		mesh_node.material_override = material
	sync_collision(part)


static func make_mesh(shape: String, size: Vector3) -> Mesh:
	match shape:
		"Cylinder":
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = size.x / 2.0
			cylinder.bottom_radius = size.x / 2.0
			cylinder.height = size.y
			return cylinder
		"Sphere":
			var sphere := SphereMesh.new()
			sphere.radius = size.x / 2.0
			sphere.height = size.x
			return sphere
	var box := BoxMesh.new()
	box.size = size
	return box


static func make_shape(shape: String, size: Vector3) -> Shape3D:
	match shape:
		"Cylinder":
			var cylinder := CylinderShape3D.new()
			cylinder.radius = size.x / 2.0
			cylinder.height = size.y
			return cylinder
		"Sphere":
			var sphere := SphereShape3D.new()
			sphere.radius = size.x / 2.0
			return sphere
	var box := BoxShape3D.new()
	box.size = size
	return box


static func collision_node(part: Node3D) -> CollisionShape3D:
	var parent := part.get_parent()
	if parent == null:
		return null
	return parent.get_node_or_null(NodePath(str(part.name) + "Collision")) as CollisionShape3D


static func sync_collision(part: Node3D) -> void:
	var wanted: bool = part.get_meta("collision", false)
	var node := collision_node(part)
	if not wanted:
		if node != null:
			node.get_parent().remove_child(node)
			node.queue_free()
		return
	if node == null:
		node = CollisionShape3D.new()
		node.name = str(part.name) + "Collision"
		part.get_parent().add_child(node)
	var offset := Transform3D()
	if part.get_meta("kind") == "primitive":
		node.shape = make_shape(part.get_meta("shape"), part.get_meta("size"))
	else:
		var box := model_aabb(part)
		var box_shape := BoxShape3D.new()
		box_shape.size = box.size
		node.shape = box_shape
		offset.origin = box.get_center()
	node.transform = part.transform * offset


static func model_aabb(part: Node3D) -> AABB:
	var result := AABB()
	var first := true
	var inverse := part.global_transform.affine_inverse()
	for found in part.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := found as MeshInstance3D
		var box: AABB = inverse * mesh_node.global_transform * mesh_node.get_aabb()
		if first:
			result = box
			first = false
		else:
			result = result.merge(box)
	return result


static func remove_part(part: Node3D) -> void:
	var node := collision_node(part)
	if node != null:
		node.get_parent().remove_child(node)
		node.queue_free()
	part.get_parent().remove_child(part)
	part.queue_free()
