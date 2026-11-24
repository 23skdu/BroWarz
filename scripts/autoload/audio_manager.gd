extends Node

var muted: bool = false
var last_played_sfx: String = ""
var current_music: String = "menu"
var _players: Dictionary = {}
var _music_player: AudioStreamPlayer = null

func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	add_child(_music_player)

const SFX_ALIASES := {
	"weapon_fire": "click",
	"order_move": "click",
	"tech_up": "laser",
	"unit_explode": "explosion",
	"building_explode": "explosion",
	"orbital_laser": "laser",
	"nuclear_launch": "nuke",
	"eel_hazard": "eel",
}

func play_sfx(sfx_name: String) -> void:
	if muted:
		return
	last_played_sfx = sfx_name
	var resolved := String(SFX_ALIASES.get(sfx_name, sfx_name))
	var path := "res://assets/sfx/%s.wav" % resolved
	if not ResourceLoader.exists(path):
		return
	var player := AudioStreamPlayer.new()
	player.stream = ResourceLoader.load(path, "AudioStreamWAV", ResourceLoader.CACHE_MODE_IGNORE)
	var master_v := float(SettingsManager.get_setting("master_volume", 1.0))
	var sfx_v := float(SettingsManager.get_setting("sfx_volume", 1.0))
	player.volume_db = linear_to_db(clampf(master_v * sfx_v, 0.001, 1.0))
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for child in get_children():
			if child is AudioStreamPlayer:
				child.stop()
				child.stream = null
				if is_instance_valid(child):
					child.free()
		_music_player = null

func set_music(track_name: String) -> void:
	current_music = track_name
	if muted or _music_player == null:
		return
	var path := "res://assets/music/%s.wav" % track_name
	if not ResourceLoader.exists(path):
		return
	_music_player.stream = ResourceLoader.load(path, "AudioStreamWAV", ResourceLoader.CACHE_MODE_IGNORE)
	_music_player.play()
