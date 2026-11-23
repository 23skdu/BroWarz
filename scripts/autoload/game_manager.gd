# scripts/autoload/game_manager.gd
extends Node

var current_map: MapData
var players: Dictionary = {}
var match_started: bool = false

func start_match(map: MapData) -> void:
	current_map = map
	match_started = true

func end_match(winner_id: int) -> void:
	match_started = false
