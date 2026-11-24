# scripts/core/vision.gd
class_name Vision
extends RefCounted

enum FogState { UNEXPLORED, EXPLORED, VISIBLE }

static func in_sight(sight_range: float, distance: float) -> bool:
	return distance <= sight_range

static func stealth_detected(sight_range: float, distance: float, target_stealth: bool, has_radar: bool = false) -> bool:
	if not target_stealth:
		return in_sight(sight_range, distance)
	# cloaked units: detected at close range or by radar
	if has_radar and distance <= sight_range:
		return true
	return distance <= sight_range * 0.35

static func fog_state(explored: bool, visible: bool) -> int:
	if visible:
		return FogState.VISIBLE
	if explored:
		return FogState.EXPLORED
	return FogState.UNEXPLORED

static func shared_vision(team_vision: Dictionary, observer_team: int, target_team: int) -> bool:
	# team_vision maps team -> Array of allied teams
	var allies: Array = team_vision.get(observer_team, [])
	return observer_team == target_team or allies.has(target_team)

static func is_sonar_unit(unit_or_building_id: String) -> bool:
	return unit_or_building_id in [
		"corvette", "cruiser", "attack_sub", "ballistic_sub",
		"patrol_boat", "awacs", "docks", "shipyard", "advanced_shipyard",
	]

static func sub_detected(sight_range: float, distance: float, observer_has_sonar: bool = false) -> bool:
	if observer_has_sonar and distance <= sight_range:
		return true
	return distance <= sight_range * 0.25
