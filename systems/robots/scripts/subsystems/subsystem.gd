class_name Subsystem
extends Node3D

@export var subsystem_name: StringName = ""
@export var subsystem_id: StringName = ""

var _manager: SubsystemManager = null
var _child_subsystems: Array[Subsystem] = []
var _active: bool = true

func _setup(manager: SubsystemManager) -> void:
	_manager = manager
	for child in get_children():
		if child is Subsystem:
			_child_subsystems.append(child)
			child._setup(manager)

func update(delta: float) -> void:
	pass

func run_default(delta: float) -> void:
	pass

func set_active(value: bool) -> void:
	_active = value
	for child in _child_subsystems:
		child.set_active(value)

func get_manager() -> SubsystemManager:
	return _manager

func get_robot() -> Node:
	return _manager.get_parent() if _manager else null

func get_sync_nodes() -> Array[Node3D]:
	return []
	
func _sync_colliders() -> void:
	pass

func _tick(delta: float) -> void:
	if not _active:
		return
	update(delta)

func _register_shape(body: RigidBody3D, shape: Shape3D) -> int:
	var owner_id := body.create_shape_owner(self)
	body.shape_owner_add_shape(owner_id, shape)
	return owner_id

func _register_shapes(body: RigidBody3D, shapes: Array[Shape3D]) -> Array[int]:
	var owners: Array[int] = []
	for shape in shapes:
		var owner_id := body.create_shape_owner(self)
		body.shape_owner_add_shape(owner_id, shape)
		owners.append(owner_id)
	return owners
	
func _register_shapes_from_children(body: RigidBody3D, source: Node3D) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for child in source.get_children():
		if child is CollisionShape3D and child.shape:
			var owner_id := body.create_shape_owner(self)
			body.shape_owner_add_shape(owner_id, child.shape)
			entries.append({"owner": owner_id, "offset": child.transform})
			child.disabled = true
	return entries

func _move_shape(body: RigidBody3D, owner_id: int, node: Node3D) -> void:
	body.shape_owner_set_transform(owner_id, body.global_transform.affine_inverse() * node.global_transform)
	
func _move_shapes(body: RigidBody3D, owners: Array[int], offsets: Array[Transform3D], node: Node3D) -> void:
	var base := body.global_transform.affine_inverse() * node.global_transform
	for i in owners.size():
		var offset := offsets[i] if i < offsets.size() else Transform3D()
		body.shape_owner_set_transform(owners[i], base * offset)
		
func _move_registered_shapes(body: RigidBody3D, entries: Array[Dictionary], node: Node3D) -> void:
	var base := body.global_transform.affine_inverse() * node.global_transform
	for entry in entries:
		body.shape_owner_set_transform(entry["owner"], base * entry["offset"])
