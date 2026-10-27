class_name CommandRegistry
extends RefCounted

static var cache: Dictionary = {}


static func all() -> Dictionary:
	if cache.is_empty():
		for info in ProjectSettings.get_global_class_list():
			var script := load(info["path"]) as Script
			if script != null and script.has_method("describe"):
				cache[StringName(info["class"])] = script
	return cache
