class_name CommandFactory
extends RefCounted


static func build(node: CommandNode, manager: SubsystemManager) -> Command:
	if node.is_group():
		var group := CommandGroup.sequence() if node.type == &"Sequence" else CommandGroup.parallel()
		for child in node.children:
			var built := build(child, manager)
			if built == null:
				return null
			group.add(built)
		return group
	var script: Script = CommandRegistry.all().get(node.type)
	if script == null:
		push_warning("Unknown command: %s" % node.type)
		return null
	var values: Array = []
	for param in script.call("describe"):
		var value = node.args.get(String(param["name"]), param.get("default"))
		if param["type"] == "subsystem":
			value = manager.get_subsystem_by_id(String(value))
			if value == null:
				push_warning("Missing subsystem for %s" % node.type)
				return null
		values.append(value)
	return script.callv("new", values) as Command
