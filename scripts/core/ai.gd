# scripts/core/ai.gd
class_name AI
extends RefCounted

# Skirmish AI controller and tactical heuristic helpers.
enum Difficulty { EASY = 0, NORMAL = 1, HARD = 2 }

static func difficulty_name(diff: int) -> String:
	match diff:
		Difficulty.EASY: return "Easy"
		Difficulty.HARD: return "Hard"
		_: return "Normal"

static func income_multiplier(diff: int) -> float:
	match diff:
		Difficulty.EASY: return 0.8
		Difficulty.HARD: return 1.35
		_: return 1.0

static func decision_interval(diff: int) -> float:
	match diff:
		Difficulty.EASY: return 3.2
		Difficulty.HARD: return 1.2
		_: return 2.0

static func attack_wave_threshold(diff: int, elapsed_minutes: float = 0.0) -> int:
	var base := 5
	match diff:
		Difficulty.EASY: base = 7
		Difficulty.HARD: base = 4
		_: base = 5
	return base + int(floor(clampf(elapsed_minutes, 0.0, 10.0) * 0.5))

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
	var iron = int(resources.get("iron", resources.get(Economy.Res.IRON, 0)))
	var oil = int(resources.get("oil", resources.get(Economy.Res.OIL, 0)))
	var geo = int(resources.get("geo", resources.get(Economy.Res.GEOTHERMAL, 0)))
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

static func choose_production_unit(wallet: Dictionary, enemy_counts: Dictionary, tech_tier: int = 1) -> String:
	# Counter-pick against enemy army composition while respecting budget and tech tier.
	var oil := int(wallet.get(Economy.Res.OIL, wallet.get("oil", 0)))
	var iron := int(wallet.get(Economy.Res.IRON, wallet.get("iron", 0)))
	var geo := int(wallet.get(Economy.Res.GEOTHERMAL, wallet.get("geo", 0)))
	var enemy_air := int(enemy_counts.get("air", 0))
	var enemy_veh := int(enemy_counts.get("vehicle", 0))
	var enemy_inf := int(enemy_counts.get("infantry", 0))
	var enemy_bld := int(enemy_counts.get("fortifications", 0))

	if tech_tier >= 3 and oil >= 180 and iron >= 320 and geo >= 140:
		return "heavy_mech"
	if enemy_air >= 2 and oil >= 75 and iron >= 140:
		return "aa_vehicle"
	if enemy_veh >= 3:
		if tech_tier >= 2 and oil >= 110 and iron >= 160 and geo >= 50:
			return "bomber_drone"
		if oil >= 25 and iron >= 85:
			return "rocketbot"
	if enemy_bld >= 2 and oil >= 100 and iron >= 190:
		return "artillery"
	if tech_tier >= 2 and oil >= 90 and iron >= 180:
		return "mbt"
	if oil >= 60 and iron >= 130 and enemy_inf >= 3:
		return "light_tank"
	if oil >= 30 and iron >= 75 and geo >= 20:
		return "stealthbot"
	if oil >= 10 and iron >= 80:
		return "heavybot"
	return "riflebot"

static func select_next_building(building_counts: Dictionary, pop_used: int, pop_cap: int) -> String:
	if pop_used + 2 >= pop_cap:
		return "farm"
	if int(building_counts.get("extractor", 0)) < 2:
		return "extractor"
	if int(building_counts.get("barracks", 0)) < 1:
		return "barracks"
	if int(building_counts.get("factory", 0)) < 1:
		return "factory"
	if int(building_counts.get("extractor", 0)) < 4:
		return "extractor"
	if int(building_counts.get("airfield", 0)) < 1:
		return "airfield"
	if int(building_counts.get("research_lab", 0)) < 1:
		return "research_lab"
	if int(building_counts.get("turret", 0)) < 2:
		return "turret"
	return "extractor"

static func choose_tactical_state(own_combat_count: int, enemy_near_base: int, wave_threshold: int) -> String:
	if enemy_near_base > 0:
		return "defend"
	if own_combat_count >= wave_threshold:
		return "attack"
	if own_combat_count >= maxi(1, wave_threshold / 2):
		return "harass"
	return "rally"
