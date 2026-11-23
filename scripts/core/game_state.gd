# scripts/core/game_state.gd
class_name GameState
extends RefCounted

var tick: int = 0
var resources: Dictionary = {}  # player_id -> wallet
var units: Array = []  # Array of Dictionary {id, team, x, y, hp}
var buildings: Array = []

func snapshot() -> Dictionary:
	return {
		"tick": tick,
		"resources": resources.duplicate(true),
		"units": units.duplicate(true),
		"buildings": buildings.duplicate(true),
	}

static func from_snapshot(s: Dictionary) -> GameState:
	var gs = GameState.new()
	gs.tick = int(s.get("tick", 0))
	gs.resources = s.get("resources", {}).duplicate(true)
	gs.units = s.get("units", []).duplicate(true)
	gs.buildings = s.get("buildings", []).duplicate(true)
	return gs

func checksum() -> int:
	# simple deterministic hash
	var h = tick * 31
	for pid in resources.keys():
		var w = resources[pid]
		for k in w.keys():
			h += int(w[k]) * 7 + int(pid) * 13
	for u in units:
		h += int(u.get("id", 0)) * 17 + int(u.get("hp", 0)) * 19
	for b in buildings:
		h += int(b.get("id", 0)) * 23 + int(b.get("hp", 0)) * 29
	return h
