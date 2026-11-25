# scripts/autoload/settings_manager.gd
extends Node

const SETTINGS_PATH := "user://settings.cfg"

const DEFAULT_SETTINGS := {
	"master_volume": 1.0,
	"music_volume": 0.8,
	"sfx_volume": 1.0,
	"soundtrack": "aerodyne",
	"muted": false,
	"subtitles": true,
	"ui_scale": 1.0,
	"colorblind": "none",
	"camera_speed": 420.0,
	"hotkey_camera_up": KEY_W,
	"hotkey_camera_down": KEY_S,
	"hotkey_camera_left": KEY_A,
	"hotkey_camera_right": KEY_D,
}

const HOTKEY_ACTIONS := ["camera_up", "camera_down", "camera_left", "camera_right"]
const COLORBLIND_PALETTES := ["none", "deuteranopia", "protanopia", "tritanopia"]

var store := SettingsStore.new()
var settings: Dictionary = DEFAULT_SETTINGS.duplicate()

func _ready() -> void:
	load_settings()
	apply_to_scene()

func get_setting(key: String, default = null):
	return settings.get(key, default)

func set_setting(key: String, value) -> void:
	settings[key] = value
	store.set_value(key, value)
	_apply_setting(key, value)

func save_settings(path: String = SETTINGS_PATH) -> Error:
	var cfg := ConfigFile.new()
	for k in settings.keys():
		cfg.set_value("browarz", str(k), settings[k])
	return cfg.save(path)

func load_settings(path: String = SETTINGS_PATH) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	for k in DEFAULT_SETTINGS.keys():
		if cfg.has_section_key("browarz", str(k)):
			set_setting(str(k), cfg.get_value("browarz", str(k), DEFAULT_SETTINGS[k]))

func reset_defaults() -> void:
	settings = DEFAULT_SETTINGS.duplicate()
	store.data = settings.duplicate(true)
	apply_to_scene()

## Push the persisted settings into live systems (audio, viewport UI scale).
func apply_to_scene() -> void:
	if is_instance_valid(AudioManager):
		AudioManager.muted = bool(settings.get("muted", false))
		var track := String(settings.get("soundtrack", AudioManager.DEFAULT_SOUNDTRACK))
		if AudioManager.has_soundtrack(track):
			AudioManager.set_soundtrack(track)
		AudioManager.apply_settings()
	_apply_ui_scale(float(settings.get("ui_scale", 1.0)))
	_refresh_faction_colors()

func _refresh_faction_colors() -> void:
	var tree := get_tree()
	if tree == null:
		return
	tree.call_group("units", "refresh_colorblind")
	tree.call_group("buildings", "refresh_colorblind")

func hotkey(action: String) -> int:
	return int(settings.get("hotkey_" + action, KEY_W))

func bind_hotkey(action: String, keycode: int) -> void:
	if action in HOTKEY_ACTIONS:
		set_setting("hotkey_" + action, keycode)

func colorblind_palette() -> String:
	var palette := String(settings.get("colorblind", "none"))
	return palette if palette in COLORBLIND_PALETTES else "none"

func subtitles_enabled() -> bool:
	return bool(settings.get("subtitles", true))

func _apply_setting(key: String, value) -> void:
	if key in ["muted", "master_volume", "music_volume"] and is_instance_valid(AudioManager):
		if key == "muted":
			AudioManager.muted = bool(value)
		AudioManager.apply_settings()
	elif key == "soundtrack":
		if is_instance_valid(AudioManager):
			AudioManager.set_soundtrack(str(value))
	elif key == "ui_scale":
		_apply_ui_scale(float(value))
	elif key == "colorblind":
		# Palette textures are keyed by color; drop old entries before units
		# rebuild their sprites for the new palette.
		UnitVisual.clear_shared_cache()
		_refresh_faction_colors()

func _apply_ui_scale(scale: float) -> void:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return
	tree.root.content_scale_factor = clampf(scale, 0.5, 2.0)
