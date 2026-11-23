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
