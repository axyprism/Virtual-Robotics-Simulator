extends Node

## The input action that triggers a control switch
@export var switch_action: StringName = "SwitchControl"

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(switch_action):
		ControlManager.toggle()
