# scripts/autoload/audio_manager.gd
extends Node

var muted: bool = false
var last_played_sfx: String = ""
var current_music: String = "menu"

func play_sfx(sfx_name: String) -> void:
	if muted:
		return
	last_played_sfx = sfx_name

func set_music(track_name: String) -> void:
	current_music = track_name
