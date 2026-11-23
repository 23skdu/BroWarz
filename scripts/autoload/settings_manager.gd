# scripts/autoload/settings_manager.gd
extends Node

var settings: Dictionary = {
	"master_volume": 1.0,
	"music_volume": 0.8,
	"sfx_volume": 1.0,
	"ui_scale": 1.0,
	"colorblind": "none",
}

func get_setting(key: String, default = null):
	return settings.get(key, default)

func set_setting(key: String, value) -> void:
	settings[key] = value
