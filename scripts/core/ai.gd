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

static func attack_wave_threshold(
	diff: int, elapsed_minutes: float = 0.0, spectator: bool = false
) -> int:
	var base := 5
	match diff:
		Difficulty.EASY: base = 7
		Difficulty.HARD: base = 4
		_: base = 5
	var threshold := base + int(floor(clampf(elapsed_minutes, 0.0, 10.0) * 0.5))
	# AI-vs-AI spectator matches should produce visible combat sooner.
	if spectator:
		threshold = maxi(2, threshold - 2)
	return threshold

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

static func choose_production_unit(
	wallet: Dictionary, enemy_counts: Dictionary, tech_tier: int = 1, faction_id: int = -1
) -> String:
	# Counter-pick against enemy army composition while respecting budget and tech tier.
	var oil := int(wallet.get(Economy.Res.OIL, wallet.get("oil", 0)))
	var iron := int(wallet.get(Economy.Res.IRON, wallet.get("iron", 0)))
	var geo := int(wallet.get(Economy.Res.GEOTHERMAL, wallet.get("geo", 0)))
	var food := int(wallet.get(Economy.Res.FOOD, wallet.get("food", 0)))
	var enemy_air := int(enemy_counts.get("air", 0))
	var enemy_veh := int(enemy_counts.get("vehicle", 0))
	var enemy_inf := int(enemy_counts.get("infantry", 0))
	var enemy_bld := int(enemy_counts.get("fortifications", 0))

	# AI-only NPC factions prioritize their signature hulls when affordable.
	match faction_id:
		Faction.Id.VESPER:
			if tech_tier >= 2 and oil >= 120 and iron >= 180 and geo >= 55:
				return "ufo_nova"
			if oil >= 80 and iron >= 130 and geo >= 30:
				return "ufo_talon"
			if oil >= 40 and iron >= 60 and geo >= 10:
				return "ufo_wisp"
		Faction.Id.THALASSA:
			if tech_tier >= 3 and oil >= 171 and iron >= 306 and geo >= 108:
				return "leviathan_carrier"
			if tech_tier >= 2 and oil >= 86 and iron >= 162 and geo >= 18:
				return "abyssal_trireme"
			if oil >= 45 and iron >= 90:
				return "nereid_raider"
		Faction.Id.GRAVEBOUND:
			if tech_tier >= 3 and oil >= 160 and iron >= 290 and geo >= 130 and food >= 60:
				return "lichen_colossus"
			if oil >= 22 and iron >= 60 and geo >= 13:
				return "ghoul_stalker"
			if oil >= 13 and iron >= 47:
				return "bone_legionary"
		Faction.Id.LUMEN:
			if tech_tier >= 2 and oil >= 132 and iron >= 231 and geo >= 88:
				return "lumen_enforcer"
			if oil >= 99 and iron >= 138 and geo >= 66:
				return "lumen_oracle"
			if oil >= 33 and iron >= 83 and geo >= 22:
				return "lumen_operative"

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

static func select_next_building(
	building_counts: Dictionary, pop_used: int, pop_cap: int, faction_id: int = -1
) -> String:
	if pop_used + 2 >= pop_cap:
		return "farm"
	# NPC factions open toward their signature production facility first.
	match faction_id:
		Faction.Id.VESPER:
			if int(building_counts.get("airfield", 0)) < 1:
				return "airfield"
			if int(building_counts.get("extractor", 0)) < 2:
				return "extractor"
			if int(building_counts.get("barracks", 0)) < 1:
				return "barracks"
			if int(building_counts.get("extractor", 0)) < 4:
				return "extractor"
			if int(building_counts.get("research_lab", 0)) < 1:
				return "research_lab"
			if int(building_counts.get("turret", 0)) < 2:
				return "turret"
			return "extractor"
		Faction.Id.THALASSA:
			if int(building_counts.get("shipyard", 0)) < 1:
				return "shipyard"
			if int(building_counts.get("barracks", 0)) < 1:
				return "barracks"
			if int(building_counts.get("extractor", 0)) < 2:
				return "extractor"
			if int(building_counts.get("docks", 0)) < 1:
				return "docks"
			if int(building_counts.get("factory", 0)) < 1:
				return "factory"
			if int(building_counts.get("extractor", 0)) < 4:
				return "extractor"
			if int(building_counts.get("research_lab", 0)) < 1:
				return "research_lab"
			if int(building_counts.get("turret", 0)) < 2:
				return "turret"
			return "extractor"
		Faction.Id.LUMEN:
			if int(building_counts.get("barracks", 0)) < 1:
				return "barracks"
			if int(building_counts.get("extractor", 0)) < 2:
				return "extractor"
			if int(building_counts.get("research_lab", 0)) < 1:
				return "research_lab"
			if int(building_counts.get("factory", 0)) < 1:
				return "factory"
			if int(building_counts.get("airfield", 0)) < 1:
				return "airfield"
			if int(building_counts.get("extractor", 0)) < 4:
				return "extractor"
			if int(building_counts.get("turret", 0)) < 2:
				return "turret"
			return "extractor"
	# Matches now open with an HQ only: the first expansion must restore basic
	# unit production before the AI invests in economy buildings.
	if int(building_counts.get("barracks", 0)) < 1:
		return "barracks"
	if int(building_counts.get("extractor", 0)) < 2:
		return "extractor"
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

## Opening grace period (seconds) before the AI may leave its rally point.
## Starting squads must not be thrown across the map on the first AI tick.
static func rally_grace(diff: int, spectator: bool = false) -> float:
	var grace := 60.0
	match diff:
		Difficulty.EASY: grace = 90.0
		Difficulty.HARD: grace = 45.0
		_: grace = 60.0
	# Spectator matches should reach contact quickly enough to watch.
	return grace * (0.6 if spectator else 1.0)

## Minimum spacing between AI build/train actions so a fast economy cannot
## produce a full army in a handful of ticks.
static func build_interval(diff: int) -> float:
	match diff:
		Difficulty.EASY: return 18.0
		Difficulty.HARD: return 9.0
		_: return 14.0

static func train_interval(diff: int) -> float:
	match diff:
		Difficulty.EASY: return 10.0
		Difficulty.HARD: return 5.0
		_: return 7.0

static func order_interval(diff: int) -> float:
	match diff:
		Difficulty.EASY: return 6.0
		Difficulty.HARD: return 3.0
		_: return 4.0

## Sweep points for scout drones. The AI knows the map's likely enemy quadrant
## but never receives live enemy coordinates from fog or spectator knowledge.
static func scout_route(base_pos: Vector2, world_size: Vector2) -> Array:
	var far_x := world_size.x * (0.8 if base_pos.x < world_size.x * 0.5 else 0.2)
	var far_y := world_size.y * (0.8 if base_pos.y < world_size.y * 0.5 else 0.2)
	return [Vector2(far_x, far_y), base_pos]

static func choose_tactical_state(own_combat_count: int, enemy_near_base: int, wave_threshold: int) -> String:
	if enemy_near_base > 0:
		return "defend"
	if own_combat_count >= wave_threshold:
		return "attack"
	if own_combat_count >= maxi(1, int(float(wave_threshold) * 0.5)):
		return "harass"
	return "rally"
