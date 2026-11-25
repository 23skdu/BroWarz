extends Node

## Music/SFX playback. `menu` and `battle` are logical cue names; the selected
## faction soundtrack supplies the actual WAV for both cues, so switching the
## soundtrack changes the menu bed and the in-match bed together.
const SOUNDTRACKS := {
	"aerodyne": {
		"faction": 0,
		"label": "AeroDyne Industries — Dominion of the Skies",
		"theme": "Bright major arpeggios, glassy aerial pads and high shimmer.",
	},
	"ferrocore": {
		"faction": 1,
		"label": "FerroCore Heavy — Iron Will, Iron Fist",
		"theme": "E-minor industrial riff, sub bass and hammered anvil percussion.",
	},
	"pelagic": {
		"faction": 2,
		"label": "Pelagic Systems — Depths of Power",
		"theme": "Rolling A-dorian 6/8 tides with submerged marimba plucks.",
	},
	"vanguard": {
		"faction": 3,
		"label": "Vanguard Robotics — Unseen, Unstoppable",
		"theme": "Sparse whole-tone stabs, radar ticks and a covert sub drone.",
	},
}
const SOUNDTRACK_ORDER := ["aerodyne", "ferrocore", "pelagic", "vanguard"]
const DEFAULT_SOUNDTRACK := "aerodyne"
const LOGICAL_TRACKS := ["menu", "battle"]

var muted: bool = false
var current_music: String = "menu"
var soundtrack: String = DEFAULT_SOUNDTRACK
var _music_player: AudioStreamPlayer = null

func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	add_child(_music_player)
	if is_instance_valid(SettingsManager):
		var configured := String(SettingsManager.get_setting("soundtrack", DEFAULT_SOUNDTRACK))
		if SOUNDTRACKS.has(configured):
			soundtrack = configured

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

static func has_soundtrack(id: String) -> bool:
	return SOUNDTRACKS.has(id)

static func soundtrack_label(id: String = "") -> String:
	var key := id if id != "" else DEFAULT_SOUNDTRACK
	var entry: Dictionary = SOUNDTRACKS.get(key, SOUNDTRACKS[DEFAULT_SOUNDTRACK])
	return String(entry["label"])

static func soundtrack_theme(id: String = "") -> String:
	var key := id if id != "" else DEFAULT_SOUNDTRACK
	var entry: Dictionary = SOUNDTRACKS.get(key, SOUNDTRACKS[DEFAULT_SOUNDTRACK])
	return String(entry["theme"])

static func soundtrack_faction(id: String = "") -> int:
	var key := id if id != "" else DEFAULT_SOUNDTRACK
	var entry: Dictionary = SOUNDTRACKS.get(key, SOUNDTRACKS[DEFAULT_SOUNDTRACK])
	return int(entry["faction"])

func next_soundtrack() -> String:
	var index := SOUNDTRACK_ORDER.find(soundtrack)
	if index < 0:
		index = 0
	else:
		index = (index + 1) % SOUNDTRACK_ORDER.size()
	return String(SOUNDTRACK_ORDER[index])

## Select a faction bed. Persisting is the caller's job (SettingsManager);
## this only swaps the live stream when music is already playing.
func set_soundtrack(id: String) -> bool:
	if not SOUNDTRACKS.has(id):
		return false
	soundtrack = id
	if _music_player != null and _music_player.stream != null and current_music != "":
		set_music(current_music)
	return true

func play_sfx(sfx_name: String) -> void:
	if muted:
		return
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
	# Headless/dummy audio backends may never emit `finished`. A watchdog
	# guarantees the transient player is released even in that case.
	var lifetime := 1.0
	if player.stream != null:
		lifetime = float(player.stream.get_length()) + 0.5
	var player_id := player.get_instance_id()
	var watchdog := get_tree().create_timer(lifetime)
	watchdog.timeout.connect(func():
		var live := instance_from_id(player_id)
		if live is AudioStreamPlayer:
			(live as AudioStreamPlayer).queue_free()
	)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for child in get_children():
			if child is AudioStreamPlayer:
				child.stop()
				child.stream = null
				if is_instance_valid(child):
					child.free()
		_music_player = null

func _music_path(track_name: String) -> String:
	# Menu/battle cues intentionally follow the selected faction soundtrack.
	if track_name in LOGICAL_TRACKS and SOUNDTRACKS.has(soundtrack):
		return "res://assets/music/%s.wav" % soundtrack
	return "res://assets/music/%s.wav" % track_name

func set_music(track_name: String) -> void:
	current_music = track_name
	if _music_player == null:
		return
	var path := _music_path(track_name)
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
