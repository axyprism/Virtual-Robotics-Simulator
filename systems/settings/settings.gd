extends Node

signal setting_changed(key: String, value)

const SAVE_PATH := "user://settings.cfg"
const SECTION := "settings"

var _values: Dictionary = {}
var _defaults: Dictionary = {}

func _ready() -> void:
	_load()

func get_value(key: String, fallback: Variant = null) -> Variant:
	if _values.has(key):
		return _values[key]
	if _defaults.has(key):
		return _defaults[key]
	return fallback

func set_value(key: String, value: Variant) -> void:
	if _values.has(key) and _values[key] == value:
		return
	_values[key] = value
	setting_changed.emit(key, value)
	_save()

func set_default(key: String, value: Variant) -> void:
	if not _defaults.has(key):
		_defaults[key] = value

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for key in cfg.get_section_keys(SECTION):
		_values[key] = cfg.get_value(SECTION, key)

func _save() -> void:
	var cfg := ConfigFile.new()
	for key in _values:
		cfg.set_value(SECTION, key, _values[key])
	cfg.save(SAVE_PATH)
