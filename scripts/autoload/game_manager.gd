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

# Multiplayer match context (staged by NetworkManager before scene load)
var local_team: int = 0
var teams: Array = [0, 1]
var fog_enabled: bool = true
var net_transport: String = "enet"

# Sapper fortification movement blocks: Vector2i tile -> {building id: mask}
var fort_blocks: Dictionary = {}

var _net_id_counter: int = 0

func next_net_id() -> int:
	_net_id_counter += 1
	return _net_id_counter

func _ready() -> void:
	registry.populate_defaults()

func start_single_player(difficulty: int = 1, map: MapData = null, p_faction: int = 0, e_faction: int = 1) -> void:
	match_mode = Mode.SINGLE_PLAYER
	ai_difficulty = clampi(difficulty, 0, 2)
	player_faction = p_faction
	ai_faction = e_faction
	teams = [0, 1]
	local_team = 0
	fog_enabled = true
	net_transport = "enet"
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

## Called by NetworkManager before a P2P match scene loads: pin every
## setting the simulation must agree on (map, seed, fog, teams, transport).
func stage_net_match(
	map_t: int, seed_value: int, fog: bool, transport: String,
	match_teams: Array, team: int,
) -> void:
	match_mode = Mode.MULTIPLAYER
	map_type = clampi(map_t, 0, 2)
	match_seed = seed_value
	fog_enabled = fog
	net_transport = transport if transport in ["enet", "webrtc"] else "enet"
	teams = match_teams.duplicate()
	if teams.is_empty():
		teams = [0, 1]
	local_team = clampi(team, 0, 7)

## Fresh per-match state: net ids and fortification blocks must not leak
## across matches (deterministic ids for replication + clean pathing).
func begin_net_session() -> void:
	_net_id_counter = 0
	fort_blocks.clear()

# --- Fortification movement blocks ----------------------------------------

## Register the footprint of a sapper-built wall/wire as impassable.
func register_fort_block(building: Node2D) -> void:
	if building == null or not is_instance_valid(building):
		return
	var stats = building.get("stats")
	if stats == null or not Fortification.blocks_movement(str(stats.id)):
		return
	var mask := Fortification.block_mask(str(stats.id))
	for tile in _fort_tiles(building):
		var entry: Dictionary = fort_blocks.get(tile, {})
		entry[building.get_instance_id()] = mask
		fort_blocks[tile] = entry

## Remove every block contributed by `building`.
func unregister_fort_block(building: Node2D) -> void:
	if building == null:
		return
	for tile in _fort_tiles(building):
		if not fort_blocks.has(tile):
			continue
		var entry: Dictionary = fort_blocks[tile]
		entry.erase(building.get_instance_id())
		if entry.is_empty():
			fort_blocks.erase(tile)
		else:
			fort_blocks[tile] = entry

## True when a fortification stops `unit_class` on (tx, ty).
func is_tile_blocked(tx: int, ty: int, unit_class: int) -> bool:
	var entry = fort_blocks.get(Vector2i(tx, ty), null)
	if entry == null or not (entry is Dictionary) or (entry as Dictionary).is_empty():
		return false
	var mask := 0
	for m in (entry as Dictionary).values():
		mask |= int(m)
	return Fortification.mask_blocks_unit(mask, unit_class)

## Nearest tile not blocked for `unit_class` within `radius` rings; returns
## the original tile when nothing better exists (best-effort goal adjust).
func nearest_free_tile(tx: int, ty: int, unit_class: int, radius: int = 6) -> Vector2i:
	if not is_tile_blocked(tx, ty, unit_class):
		return Vector2i(tx, ty)
	for r in range(1, radius + 1):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var t := Vector2i(tx + dx, ty + dy)
				if current_map != null and not current_map.in_bounds(t.x, t.y):
					continue
				if not is_tile_blocked(t.x, t.y, unit_class):
					return t
	return Vector2i(tx, ty)

func _fort_tiles(building: Node2D) -> Array:
	var out: Array = []
	var stats = building.get("stats")
	if stats == null:
		return out
	var fp: Vector2i = stats.footprint
	var cx := int(floor(building.global_position.x / 16.0))
	var cy := int(floor(building.global_position.y / 16.0))
	var ox := cx - int(floor(float(fp.x - 1) / 2.0))
	var oy := cy - int(floor(float(fp.y - 1) / 2.0))
	for dy in range(fp.y):
		for dx in range(fp.x):
			out.append(Vector2i(ox + dx, oy + dy))
	return out
