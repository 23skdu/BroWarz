# scripts/core/ai.gd
class_name AI
extends RefCounted

# Simple heuristic helpers for skirmish AI.

static func should_expand(resource_rate: float, threshold: float = 5.0) -> bool:
	return resource_rate >= threshold

static func choose_weakest_target(targets: Array) -> int:
	# targets: Array of Dictionary { "id": int, "strength": float }
	if targets.is_empty():
		return -1
	var best_id = int(targets[0].get("id", -1))
	var best_str = float(targets[0].get("strength", INF))
	for t in targets:
		var s = float(t.get("strength", INF))
		if s < best_str:
			best_str = s
			best_id = int(t.get("id", -1))
	return best_id

static func desired_army_composition(resources: Dictionary) -> Dictionary:
	# returns ratios based on available resources
	var iron = int(resources.get("iron", 0))
	var oil = int(resources.get("oil", 0))
	var geo = int(resources.get("geo", 0))
	var inf = 0.5
	var veh = 0.3
	var air = 0.2
	if geo > iron:
		air = 0.3
		veh = 0.2
	if oil < iron:
		inf = 0.6
		veh = 0.25
		air = 0.15
	return {"infantry": inf, "vehicle": veh, "air": air}

static func retreat_threshold(hp_ratio: float, threshold: float = 0.3) -> bool:
	return hp_ratio < threshold
