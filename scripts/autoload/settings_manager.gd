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
	"graphics_quality": "high",
	"reduced_motion": false,
	"ui_scale": 1.0,
	"colorblind": "none",
	"camera_speed": 420.0,
	"hotkey_camera_up": KEY_W,
	"hotkey_camera_down": KEY_S,
	"hotkey_camera_left": KEY_A,
	"hotkey_camera_right": KEY_D,
	"hotkey_cmd_hold": KEY_H,
	"hotkey_cmd_stop": KEY_Z,
	"hotkey_cmd_patrol": KEY_Y,
	"hotkey_cmd_guard": KEY_J,
	"hotkey_cmd_formation": KEY_Q,
	"hotkey_cmd_embark": KEY_E,
	"hotkey_cmd_disembark": KEY_U,
	"hotkey_cmd_capture": KEY_C,
	"hotkey_cmd_sonar_buoy": KEY_K,
	"hotkey_cmd_tech": KEY_T,
	"hotkey_cmd_research": KEY_R,
	"hotkey_cmd_laser": KEY_L,
	"hotkey_cmd_nuke": KEY_N,
	"hotkey_build_extractor": KEY_B,
	"hotkey_build_turret": KEY_V,
	"hotkey_build_power": KEY_P,
	"hotkey_build_wall": KEY_F,
	"hotkey_build_wire": KEY_G,
	"hotkey_build_missile_tower": KEY_M,
	"recent_maps": [],
	"webrtc_stun_url": "stun:stun.l.google.com:19302",
	"webrtc_turn_url": "",
}

const HOTKEY_ACTIONS := [
	"camera_up", "camera_down", "camera_left", "camera_right",
	"cmd_hold", "cmd_stop", "cmd_patrol", "cmd_guard", "cmd_formation",
	"cmd_embark", "cmd_disembark", "cmd_capture", "cmd_sonar_buoy",
	"cmd_tech", "cmd_research", "cmd_laser", "cmd_nuke",
	"build_extractor", "build_turret", "build_power",
	"build_wall", "build_wire", "build_missile_tower",
]
const MAX_RECENT_MAPS: int = 8
const COLORBLIND_PALETTES := ["none", "deuteranopia", "protanopia", "tritanopia"]
const GRAPHICS_QUALITIES := ["low", "medium", "high"]

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
	var key := "hotkey_" + action
	return int(settings.get(key, DEFAULT_SETTINGS.get(key, KEY_W)))

func bind_hotkey(action: String, keycode: int) -> void:
	if action in HOTKEY_ACTIONS:
		set_setting("hotkey_" + action, keycode)

func recent_maps() -> Array[String]:
	var out: Array[String] = []
	var raw: Variant = settings.get("recent_maps", [])
	if raw is Array:
		for item in raw as Array:
			var s := String(item).strip_edges()
			if not s.is_empty() and not out.has(s):
				out.append(s)
	return out

func add_recent_map(path: String) -> void:
	var clean := path.strip_edges()
	if clean.is_empty():
		return
	var list := recent_maps()
	list.erase(clean)
	list.insert(0, clean)
	if list.size() > MAX_RECENT_MAPS:
		list.resize(MAX_RECENT_MAPS)
	set_setting("recent_maps", list)

func webrtc_stun_url() -> String:
	var raw := String(settings.get("webrtc_stun_url", DEFAULT_SETTINGS["webrtc_stun_url"])).strip_edges()
	return raw if NetSecurity.is_valid_ice_url(raw) else String(DEFAULT_SETTINGS["webrtc_stun_url"])

func webrtc_turn_url() -> String:
	var raw := String(settings.get("webrtc_turn_url", "")).strip_edges()
	return raw if NetSecurity.is_valid_ice_url(raw) else ""

func colorblind_palette() -> String:
	var palette := String(settings.get("colorblind", "none"))
	return palette if palette in COLORBLIND_PALETTES else "none"

func subtitles_enabled() -> bool:
	return bool(settings.get("subtitles", true))

func graphics_quality() -> String:
	var q := String(settings.get("graphics_quality", "high")).to_lower()
	return q if q in GRAPHICS_QUALITIES else "high"

func reduced_motion() -> bool:
	return bool(settings.get("reduced_motion", false))

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
	elif key in ["graphics_quality", "reduced_motion"]:
		var tree := get_tree()
		if tree != null:
			tree.call_group("game_scenes", "refresh_graphics_quality")

func _apply_ui_scale(scale: float) -> void:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return
	tree.root.content_scale_factor = clampf(scale, 0.5, 2.0)
