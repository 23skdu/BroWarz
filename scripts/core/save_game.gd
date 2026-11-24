# scripts/core/save_game.gd
class_name SaveGame
extends RefCounted

var version: int = 1
var game_state: Dictionary = {}
var settings: Dictionary = {}

func to_dict() -> Dictionary:
	return {
		"version": version,
		"game_state": game_state.duplicate(true),
		"settings": settings.duplicate(true),
	}

static func from_dict(d: Dictionary) -> SaveGame:
	var s = SaveGame.new()
	s.version = int(d.get("version", 1))
	s.game_state = d.get("game_state", {}).duplicate(true)
	s.settings = d.get("settings", {}).duplicate(true)
	return s
