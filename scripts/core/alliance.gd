# scripts/core/alliance.gd
class_name Alliance
extends RefCounted

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

static func are_allied_teams(alliances: Dictionary, team_a: int, team_b: int) -> bool:
	if team_a == team_b:
		return true
	var a: Variant = alliances.get(team_a, null)
	if a is Alliance:
		return (a as Alliance).is_allied(team_b)
	if a is Array:
		return (a as Array).has(team_b)
	return false
