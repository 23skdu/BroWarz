extends Node

var muted: bool = false
var last_played_sfx: String = ""
var current_music: String = "menu"
var _players: Dictionary = {}

func play_sfx(sfx_name: String) -> void:
	if muted:
		return
	last_played_sfx = sfx_name
	var path := "res://assets/sfx/%s.wav" % sfx_name
	if not ResourceLoader.exists(path):
		return
	var player := AudioStreamPlayer.new()
	player.stream = load(path)
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)

func set_music(track_name: String) -> void:
	current_music = track_name
