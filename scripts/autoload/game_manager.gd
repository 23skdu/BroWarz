# scripts/autoload/game_manager.gd
extends Node

enum Mode { SINGLE_PLAYER, MULTIPLAYER, MAP_EDITOR, SPECTATOR }

var current_map: MapData
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
# Alliance graph: team -> Array of allied team ids (defaults to none = FFA).
var alliances: Dictionary = {}
# Pending in-match diplomacy requests: "from>to" -> true. Relayed through the
# host command pipeline so every peer sees the same offers.
var alliance_proposals: Dictionary = {}
# AI match context. Single player uses team 1; co-op uses team 1 as the shared
# opponent; spectator uses both teams. Faction/difficulty maps are keyed by team
# so mirrored corporations and AI-vs-AI sides can be staged explicitly.
var ai_enabled: bool = false
var ai_teams: Array = []
var team_factions: Dictionary = {}
var team_difficulties: Dictionary = {}
var is_spectator: bool = false

func faction_for_team(team: int) -> int:
	var max_id := 7 if is_ai_team(team) else 3
	if team_factions.has(team):
		return clampi(int(team_factions[team]), 0, max_id)
	var fallback := player_faction if team == 0 else ai_faction
	return clampi(fallback, 0, max_id)

func difficulty_for_team(team: int) -> int:
	if team_difficulties.has(team):
		return clampi(int(team_difficulties[team]), 0, 2)
	return clampi(ai_difficulty, 0, 2)

func is_ai_team(team: int) -> bool:
	return ai_enabled and ai_teams.has(team)

func is_allied(a: int, b: int) -> bool:
	return Alliance.are_allied_teams(alliances, a, b)

## Install a validated alliance graph/proposal set. Used by lobby staging,
## quickload and tests; all sides are made symmetric and transitive.
func set_diplomacy_state(graph: Dictionary, proposals: Dictionary, valid_teams: Array = []) -> void:
	var ids: Array[int] = []
	for value in valid_teams:
		var team := Alliance.team_id(value)
		if team >= 0 and not ids.has(team):
			ids.append(team)
	if not ids.is_empty():
		teams = ids
	alliances = Alliance.normalize(graph)
	alliance_proposals = Alliance.clean_proposals(proposals, teams)

## Host-side diplomacy transition. `team` must already be the authoritative
## sender team resolved by NetworkManager.prepare_inbound_command().
func apply_diplomacy(team: int, action: String, target_team: int) -> bool:
	if not Alliance.ACTIONS.has(action):
		return false
	if team < 0 or team > 7 or target_team < 0 or target_team > 7 or team == target_team:
		return false
	if not teams.has(team) or not teams.has(target_team):
		return false
	match action:
		"propose":
			if is_allied(team, target_team):
				return false
			return Alliance.set_proposal(alliance_proposals, team, target_team)
		"cancel":
			return Alliance.cancel_proposal(alliance_proposals, team, target_team)
		"decline":
			if not Alliance.has_proposal(alliance_proposals, target_team, team):
				return false
			return Alliance.cancel_proposal(alliance_proposals, target_team, team)
		"accept":
			if not Alliance.has_proposal(alliance_proposals, target_team, team):
				return false
			if is_allied(team, target_team):
				Alliance.cancel_proposal(alliance_proposals, target_team, team)
				return false
			var side_a := Alliance.members(alliances, team)
			var side_b := Alliance.members(alliances, target_team)
			var changed := Alliance.form(alliances, team, target_team)
			Alliance.clear_proposals_between(alliance_proposals, side_a, side_b)
			return changed
		"break":
			if not is_allied(team, target_team):
				return false
			return Alliance.split(alliances, team, target_team)
	return false

# Sapper fortification movement blocks: Vector2i tile -> {building id: mask}
var fort_blocks: Dictionary = {}
var active_clouds: Array[Dictionary] = []

var _net_id_counter: int = 0

func next_net_id() -> int:
	_net_id_counter += 1
	return _net_id_counter

func _ready() -> void:
	registry.populate_defaults()

func start_single_player(difficulty: int = 1, map: MapData = null, p_faction: int = 0, e_faction: int = 1, map_type_value: int = 2) -> void:
	begin_net_session()
	match_seed = 1337
	match_mode = Mode.SINGLE_PLAYER
	# The map kind is part of the match context. Never inherit it from a prior
	# map-editor session or from merely browsing the main-menu map button.
	map_type = clampi(map_type_value, 0, 3)
	ai_difficulty = clampi(difficulty, 0, 2)
	player_faction = clampi(p_faction, 0, 3)
	ai_faction = clampi(e_faction, 0, 7)
	teams = [0, 1]
	local_team = 0
	fog_enabled = true
	net_transport = "enet"
	ai_enabled = true
	ai_teams = [1]
	team_factions = {0: player_faction, 1: ai_faction}
	team_difficulties = {1: ai_difficulty}
	is_spectator = false
	if registry.units.is_empty():
		registry.populate_defaults()
	current_map = map
	match_started = true

## Local view-only AI-vs-AI match. There is no human seat and no command
## authority; both sides are driven by the host-side simulation in the game
## scene. Fog is disabled so each AI has a symmetric view of the battlefield.
func start_spectator(
	difficulty: int = 1, map: MapData = null, faction_a: int = 0,
	faction_b: int = 1, map_type_value: int = 2,
) -> void:
	begin_net_session()
	match_seed = 1337
	match_mode = Mode.SPECTATOR
	map_type = clampi(map_type_value, 0, 3)
	ai_difficulty = clampi(difficulty, 0, 2)
	player_faction = clampi(faction_a, 0, 7)
	ai_faction = clampi(faction_b, 0, 7)
	team_factions = {0: player_faction, 1: ai_faction}
	team_difficulties = {0: ai_difficulty, 1: ai_difficulty}
	ai_enabled = true
	ai_teams = [0, 1]
	teams = [0, 1]
	local_team = -1
	fog_enabled = false
	net_transport = "enet"
	is_spectator = true
	if registry.units.is_empty():
		registry.populate_defaults()
	current_map = map
	match_started = true

func start_match(map: MapData) -> void:
	if registry.units.is_empty():
		registry.populate_defaults()
	current_map = map
	if active_clouds.is_empty() and map != null:
		active_clouds = Cover.spawn_clouds(float(map.width) * 16.0, float(map.height) * 16.0, match_seed, 8)
	match_started = true

func is_in_cloud(world_pos: Vector2) -> bool:
	return Cover.is_point_in_cloud(active_clouds, world_pos)

func end_match(_winner_id: int) -> void:
	match_started = false

## Drop per-match context when the match scene leaves the tree. The next
## start still calls begin_net_session(), but clearing here prevents a full
## MapData and cloud/fortification arrays from lingering at the main menu.
func clear_match_state() -> void:
	match_started = false
	current_map = null
	fort_blocks.clear()
	active_clouds.clear()

## Called by NetworkManager before a P2P match scene loads: pin every
## setting the simulation must agree on (map, seed, fog, teams, transport).
func stage_net_match(
	map_t: int, seed_value: int, fog: bool, transport: String,
	match_teams: Array, team: int, match_alliances: Dictionary = {},
	match_ai_enabled: bool = false, match_ai_teams: Array = [],
	match_factions: Dictionary = {}, match_difficulties: Dictionary = {},
) -> void:
	begin_net_session()
	match_mode = Mode.MULTIPLAYER
	map_type = clampi(map_t, 0, 2)
	match_seed = seed_value
	fog_enabled = fog
	net_transport = transport if transport in ["enet", "webrtc"] else "enet"
	teams = match_teams.duplicate()
	if teams.is_empty():
		teams = [0, 1]
	local_team = clampi(team, 0, 7)
	set_diplomacy_state(match_alliances, {}, teams)
	ai_enabled = bool(match_ai_enabled)
	ai_teams = []
	for value in match_ai_teams:
		var ai_team := Alliance.team_id(value)
		if ai_team >= 0 and not ai_teams.has(ai_team):
			ai_teams.append(ai_team)
	team_factions = {}
	for key in match_factions.keys():
		var fac_team := Alliance.team_id(key)
		if fac_team >= 0:
			var max_fac := 7 if (ai_enabled and ai_teams.has(fac_team)) else 3
			team_factions[fac_team] = clampi(int(match_factions[key]), 0, max_fac)
	team_difficulties = {}
	for key in match_difficulties.keys():
		var diff_team := Alliance.team_id(key)
		if diff_team >= 0:
			team_difficulties[diff_team] = clampi(int(match_difficulties[key]), 0, 2)
	ai_difficulty = clampi(team_difficulties.get(ai_teams[0] if not ai_teams.is_empty() else 1, 1), 0, 2)
	player_faction = clampi(int(team_factions.get(0, player_faction)), 0, 7 if (ai_enabled and ai_teams.has(0)) else 3)
	ai_faction = clampi(int(team_factions.get(1, ai_faction)), 0, 7 if (ai_enabled and ai_teams.has(1)) else 3)
	is_spectator = false

## Fresh per-match state: net ids and fortification blocks must not leak
## across matches (deterministic ids for replication + clean pathing).
func begin_net_session() -> void:
	_net_id_counter = 0
	ResourceManager.reset()
	fort_blocks.clear()
	alliances.clear()
	alliance_proposals.clear()
	active_clouds.clear()
	ai_enabled = false
	ai_teams = []
	team_factions = {}
	team_difficulties = {}
	is_spectator = false
	# A stale editor map must never be reused by the next match scene.
	current_map = null

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
