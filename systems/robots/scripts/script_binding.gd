class_name ScriptBinding
extends Resource

enum Mode { PRESSED, HELD }

@export var action: StringName = &""
@export var mode: Mode = Mode.PRESSED
@export var command: CommandNode
