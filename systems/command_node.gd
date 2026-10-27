class_name CommandNode
extends Resource

@export var type: StringName = &"Sequence"
@export var args: Dictionary = {}
@export var children: Array[CommandNode] = []


func is_group() -> bool:
	return type == &"Sequence" or type == &"Parallel"
