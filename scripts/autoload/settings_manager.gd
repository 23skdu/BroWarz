# scripts/autoload/settings_manager.gd
extends Node

const SETTINGS_PATH := "user://settings.cfg"

var store := SettingsStore.new()
var settings: Dictionary = {
	"master_volume": 1.0,
	"music_volume": 0.8,
	"sfx_volume": 1.0,
	"ui_scale": 1.0,
	"colorblind": "none",
	"camera_speed": 420.0,
}

func _ready() -> void:
	load_settings()

func get_setting(key: String, default = null):
	return settings.get(key, default)

func set_setting(key: String, value) -> void:
	settings[key] = value
	store.set_value(key, value)

func save_settings(path: String = SETTINGS_PATH) -> Error:
	var cfg := ConfigFile.new()
	for k in settings.keys():
		cfg.set_value("browarz", str(k), settings[k])
	return cfg.save(path)

func load_settings(path: String = SETTINGS_PATH) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	for k in settings.keys():
		if cfg.has_section_key("browarz", str(k)):
			set_setting(str(k), cfg.get_value("browarz", str(k), settings[k]))
