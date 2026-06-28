class_name Command
extends RefCounted

## Which subsystems this command exclusively needs — prevents conflicts
var required: Array[Subsystem] = []

## The robot context this command runs on (set by scheduler at schedule time)
var robot: Node = null

## Override these four in subclasses
func on_start() -> void:
	pass

func on_update(_delta: float) -> void:
	pass

func on_end(_interrupted: bool) -> void:
	pass

## Return true when the command is done
func is_finished() -> bool:
	return true

## Helper: require a subsystem and return self for chaining
func require(subsystem: Subsystem) -> Command:
	required.append(subsystem)
	return self
