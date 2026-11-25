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
	if _music_player == null:
		return
	var path := "res://assets/music/%s.wav" % track_name
	if not ResourceLoader.exists(path):
		return
	var stream := ResourceLoader.load(path, "AudioStreamWAV", ResourceLoader.CACHE_MODE_IGNORE) as AudioStreamWAV
	if stream != null:
		# The importer may not persist loop settings in every export path.
		# Force a forward loop so the ambience never drops into silence.
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = -1
	_music_player.stream = stream
	apply_settings()

## Re-apply persisted volume/mute to the music bed. Settings changes must be
## audible immediately, and unmuting must resume the current track.
func apply_settings() -> void:
	if _music_player == null:
		return
	var master_v := float(SettingsManager.get_setting("master_volume", 1.0))
	var music_v := float(SettingsManager.get_setting("music_volume", 0.8))
	_music_player.volume_db = linear_to_db(clampf(master_v * music_v, 0.001, 1.0))
	if muted:
		_music_player.stop()
	elif current_music != "" and _music_player.stream != null and not _music_player.playing:
		_music_player.play()

func music_is_playing() -> bool:
	return _music_player != null and _music_player.playing
