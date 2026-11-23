# scripts/core/settings_store.gd
class_name SettingsStore
extends RefCounted

var data: Dictionary = {}

func set_value(key: String, value) -> void:
	data[key] = value

func get_value(key: String, default = null):
	return data.get(key, default)

func has(key: String) -> bool:
	return data.has(key)

func remove(key: String) -> void:
	data.erase(key)

func to_dict() -> Dictionary:
	return data.duplicate(true)

static func from_dict(d: Dictionary) -> SettingsStore:
	var s = SettingsStore.new()
	s.data = d.duplicate(true)
	return s
