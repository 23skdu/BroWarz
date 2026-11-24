# scripts/autoload/game_manager.gd
extends Node

enum Mode { SINGLE_PLAYER, MULTIPLAYER, MAP_EDITOR }

var current_map: MapData
var players: Dictionary = {}
var match_started: bool = false
var match_mode: int = Mode.SINGLE_PLAYER
var ai_difficulty: int = 1  # 0 Easy, 1 Normal, 2 Hard
var player_faction: int = 0
var ai_faction: int = 1
var match_seed: int = 1337
var map_type: int = 2  # 0 desert, 1 islands, 2 forest
var registry: UnitRegistry = UnitRegistry.new()

func _ready() -> void:
	registry.populate_defaults()

func start_single_player(difficulty: int = 1, map: MapData = null, p_faction: int = 0, e_faction: int = 1) -> void:
	match_mode = Mode.SINGLE_PLAYER
	ai_difficulty = clampi(difficulty, 0, 2)
	player_faction = p_faction
	ai_faction = e_faction
	if registry.units.is_empty():
		registry.populate_defaults()
	if map != null:
		current_map = map
	match_started = true

func start_match(map: MapData) -> void:
	if registry.units.is_empty():
		registry.populate_defaults()
	current_map = map
	match_started = true

func end_match(_winner_id: int) -> void:
	match_started = false
