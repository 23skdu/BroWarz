# scripts/core/alliance.gd
class_name Alliance
extends RefCounted

# Alliance graph operations. The graph is a team -> Array[team] adjacency map;
# values from the lobby (`{0: [0, 2], 1: [1, 3]}`) are normalized into symmetric
# sides before a match starts so combat, fog and victory sides agree.

const ACTIONS: Array[String] = ["propose", "cancel", "decline", "accept", "break"]

var teams: Array = []

func add_team(t: int) -> void:
	if not teams.has(t):
		teams.append(t)

func remove_team(t: int) -> void:
	teams.erase(t)

func is_allied(t: int) -> bool:
	return teams.has(t)

func size() -> int:
	return teams.size()

## True when the two teams belong to the same connected alliance side.
static func are_allied_teams(alliances: Dictionary, team_a: int, team_b: int) -> bool:
	if team_a == team_b:
		return true
	return members(alliances, team_a).has(team_b)

## Accept integer or JSON-string team ids; reject anything outside 0..7.
static func team_id(raw: Variant) -> int:
	if (raw is int) or (raw is float):
		var value := int(raw)
		return value if value >= 0 and value <= 7 else -1
	if not (raw is String):
		return -1
	var text := raw as String
	if text.is_empty() or text.length() > 2:
		return -1
	for i in range(text.length()):
		var code := text.unicode_at(i)
		if code < 48 or code > 57:
			return -1
	var parsed := text.to_int()
	return parsed if parsed >= 0 and parsed <= 7 else -1

## Directly adjacent teams, following both keys and values so one-way lobby
## maps are treated symmetrically.
static func neighbors(alliances: Dictionary, team: int) -> Array[int]:
	var out: Array[int] = []
	var raw: Variant = alliances.get(team, null)
	# JSON saves turn integer keys into strings; look up both forms.
	if raw == null:
		raw = alliances.get(str(team), null)
	if raw is Alliance:
		for value in (raw as Alliance).teams:
			var other := team_id(value)
			if other >= 0 and not out.has(other):
				out.append(other)
	elif raw is Array:
		for value in raw as Array:
			var other := team_id(value)
			if other >= 0 and not out.has(other):
				out.append(other)
	for key in alliances.keys():
		var side := team_id(key)
		if side < 0 or side == team:
			continue
		var value: Variant = alliances[key]
		if value is Alliance:
			if (value as Alliance).is_allied(team) and not out.has(side):
				out.append(side)
		elif value is Array and (value as Array).has(team) and not out.has(side):
			out.append(side)
	return out

## Every team connected to `team`, including `team` itself, sorted for stable
## side keys and UI display.
static func members(alliances: Dictionary, team: int) -> Array[int]:
	var seen: Array[int] = []
	var queue: Array[int] = [team]
	if team_id(team) < 0:
		return seen
	seen.append(team)
	while not queue.is_empty():
		var current: int = queue.pop_front()
		for other in neighbors(alliances, current):
			if not seen.has(other):
				seen.append(other)
				queue.append(other)
	seen.sort()
	return seen

## Convert any lobby/save representation into symmetric alliance sides.
static func normalize(raw: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	if not (raw is Dictionary):
		return out
	var candidates: Array[int] = []
	for key in raw.keys():
		var owner := team_id(key)
		if owner >= 0 and not candidates.has(owner):
			candidates.append(owner)
		var value: Variant = raw[key]
		if value is Alliance:
			for member in (value as Alliance).teams:
				var member_id := team_id(member)
				if member_id >= 0 and not candidates.has(member_id):
					candidates.append(member_id)
		elif value is Array:
			for member in value as Array:
				var member_id := team_id(member)
				if member_id >= 0 and not candidates.has(member_id):
					candidates.append(member_id)
	for candidate in candidates:
		var side := members(raw, candidate)
		if side.size() < 2:
			continue
		for team in side:
			out[team] = side.duplicate()
	return out

static func proposal_key(from_team: int, to_team: int) -> String:
	return "%d>%d" % [from_team, to_team]

static func set_proposal(proposals: Dictionary, from_team: int, to_team: int) -> bool:
	if from_team == to_team or team_id(from_team) < 0 or team_id(to_team) < 0:
		return false
	var key := proposal_key(from_team, to_team)
	if proposals.has(key):
		return false
	proposals[key] = true
	return true

static func has_proposal(proposals: Dictionary, from_team: int, to_team: int) -> bool:
	return proposals.has(proposal_key(from_team, to_team))

static func cancel_proposal(proposals: Dictionary, from_team: int, to_team: int) -> bool:
	return proposals.erase(proposal_key(from_team, to_team))

## Drop stale requests once two sides merge, and reject malformed loaded keys.
static func clear_proposals_between(proposals: Dictionary, side_a: Array, side_b: Array) -> void:
	for from_team in side_a:
		for to_team in side_b:
			cancel_proposal(proposals, int(from_team), int(to_team))
			cancel_proposal(proposals, int(to_team), int(from_team))

static func clean_proposals(raw: Dictionary, valid_teams: Array = []) -> Dictionary:
	var out: Dictionary = {}
	if not (raw is Dictionary):
		return out
	for key in (raw as Dictionary).keys():
		var parts := String(key).split(">")
		if parts.size() != 2:
			continue
		var from_team := team_id(parts[0])
		var to_team := team_id(parts[1])
		if from_team < 0 or to_team < 0 or from_team == to_team:
			continue
		if not valid_teams.is_empty() and (not valid_teams.has(from_team) or not valid_teams.has(to_team)):
			continue
		out[proposal_key(from_team, to_team)] = true
	return out

## Merge the two connected sides into one symmetric clique.
static func form(alliances: Dictionary, team_a: int, team_b: int) -> bool:
	var side_a := members(alliances, team_a)
	var side_b := members(alliances, team_b)
	var changed := false
	for from_team in side_a:
		for to_team in side_b:
			if from_team == to_team:
				continue
			var list_a := _list_for(alliances, from_team)
			if not list_a.has(to_team):
				list_a.append(to_team)
				changed = true
			var list_b := _list_for(alliances, to_team)
			if not list_b.has(from_team):
				list_b.append(from_team)
				changed = true
	return changed

## Break every link between two sides. When both teams are already on one
## side, the whole side dissolves (equivalent to leaving the alliance).
static func split(alliances: Dictionary, team_a: int, team_b: int) -> bool:
	var side_a := members(alliances, team_a)
	var side_b := members(alliances, team_b)
	var changed := false
	for from_team in side_a:
		for to_team in side_b:
			if from_team == to_team:
				continue
			if _remove_link(alliances, from_team, to_team):
				changed = true
			if _remove_link(alliances, to_team, from_team):
				changed = true
	for key in alliances.keys():
		var list := _list_for(alliances, team_id(key))
		if list.is_empty():
			alliances.erase(key)
	return changed

static func _list_for(alliances: Dictionary, team: int) -> Array:
	var value: Variant = alliances.get(team, null)
	if value is Array:
		return value as Array
	if value is Alliance:
		return (value as Alliance).teams
	var fresh: Array = []
	alliances[team] = fresh
	return fresh

static func _remove_link(alliances: Dictionary, team: int, other: int) -> bool:
	var list := _list_for(alliances, team)
	var index := list.find(other)
	if index < 0:
		return false
	list.remove_at(index)
	return true
