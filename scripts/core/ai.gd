# scripts/core/ai.gd
class_name AI
extends RefCounted

# Skirmish AI controller and tactical heuristic helpers.
enum Difficulty { EASY = 0, NORMAL = 1, HARD = 2 }

const ECONOMY_BUILDINGS: Array[String] = ["extractor", "farm", "power_plant", "research_lab"]
const DEFENSE_BUILDINGS: Array[String] = ["turret", "missile_tower"]

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

## Per-faction tactical doctrine parameters (corporations 0-3 and NPCs 4-7).
## Controls retreat discipline, wave aggression, flanking share, tech order,
## cloud usage, and defensive fortification preference.
static func doctrine(faction_id: int) -> Dictionary:
	match faction_id:
		Faction.Id.AERODYNE:
			return {
				"retreat_hp": 0.30,
				"wave_bias": 0,
				"flank_ratio": 0.40,
				"commit_ratio": 0.72,
				"prefer_clouds": true,
				"fortify_pref": "missile_tower",
				"tech_priority": ["railgun_cal", "super_heavy", "strategic_uplinks", "reactive_armor", "cloak_caps"],
			}
		Faction.Id.FERROCORE:
			return {
				"retreat_hp": 0.24,
				"wave_bias": 1,
				"flank_ratio": 0.20,
				"commit_ratio": 0.65,
				"prefer_clouds": false,
				"fortify_pref": "wall",
				"tech_priority": ["reactive_armor", "super_heavy", "railgun_cal", "strategic_uplinks", "cloak_caps"],
			}
		Faction.Id.PELAGIC:
			return {
				"retreat_hp": 0.28,
				"wave_bias": 0,
				"flank_ratio": 0.35,
				"commit_ratio": 0.70,
				"prefer_clouds": false,
				"fortify_pref": "missile_tower",
				"tech_priority": ["reactive_armor", "cloak_caps", "railgun_cal", "super_heavy", "strategic_uplinks"],
			}
		Faction.Id.VANGUARD:
			return {
				"retreat_hp": 0.32,
				"wave_bias": 0,
				"flank_ratio": 0.50,
				"commit_ratio": 0.75,
				"prefer_clouds": false,
				"fortify_pref": "missile_tower",
				"tech_priority": ["railgun_cal", "cloak_caps", "reactive_armor", "super_heavy", "strategic_uplinks"],
			}
		Faction.Id.VESPER:
			return {
				"retreat_hp": 0.34,
				"wave_bias": -1,
				"flank_ratio": 0.50,
				"commit_ratio": 0.72,
				"prefer_clouds": true,
				"fortify_pref": "missile_tower",
				"tech_priority": ["railgun_cal", "super_heavy", "strategic_uplinks", "reactive_armor", "cloak_caps"],
			}
		Faction.Id.THALASSA:
			return {
				"retreat_hp": 0.26,
				"wave_bias": 0,
				"flank_ratio": 0.35,
				"commit_ratio": 0.68,
				"prefer_clouds": false,
				"fortify_pref": "missile_tower",
				"tech_priority": ["reactive_armor", "railgun_cal", "super_heavy", "strategic_uplinks", "cloak_caps"],
			}
		Faction.Id.GRAVEBOUND:
			return {
				"retreat_hp": 0.15,
				"wave_bias": -1,
				"flank_ratio": 0.25,
				"commit_ratio": 0.50,
				"prefer_clouds": false,
				"fortify_pref": "wall",
				"tech_priority": ["reactive_armor", "super_heavy", "railgun_cal", "strategic_uplinks", "cloak_caps"],
			}
		Faction.Id.LUMEN:
			return {
				"retreat_hp": 0.38,
				"wave_bias": 0,
				"flank_ratio": 0.55,
				"commit_ratio": 0.85,
				"prefer_clouds": true,
				"fortify_pref": "missile_tower",
				"tech_priority": ["railgun_cal", "cloak_caps", "reactive_armor", "super_heavy", "strategic_uplinks"],
			}
	return {
		"retreat_hp": 0.28,
		"wave_bias": 0,
		"flank_ratio": 0.30,
		"commit_ratio": 0.68,
		"prefer_clouds": false,
		"fortify_pref": "missile_tower",
		"tech_priority": ["reactive_armor", "railgun_cal", "super_heavy", "cloak_caps", "strategic_uplinks"],
	}

static func attack_wave_threshold(
	diff: int, elapsed_minutes: float = 0.0, spectator: bool = false, faction_id: int = -1
) -> int:
	var base := 5
	match diff:
		Difficulty.EASY: base = 7
		Difficulty.HARD: base = 4
		_: base = 5
	var threshold := base + int(floor(clampf(elapsed_minutes, 0.0, 10.0) * 0.5))
	if faction_id >= 0:
		threshold += int(doctrine(faction_id).get("wave_bias", 0))
	# AI-vs-AI spectator matches should produce visible combat sooner.
	if spectator:
		threshold = maxi(2, threshold - 2)
	return maxi(2, threshold)

static func should_expand(resource_rate: float, threshold: float = 5.0) -> bool:
	return resource_rate >= threshold

static func choose_weakest_target(targets: Array) -> int:
	# targets: Array of Dictionary { "id": int, "strength": float }
	if targets.is_empty():
		return -1
	var best_id: int = int(targets[0].get("id", -1))
	var best_str: float = float(targets[0].get("strength", INF))
	for t in targets:
		var s: float = float(t.get("strength", INF))
		if s < best_str:
			best_str = s
			best_id = int(t.get("id", -1))
	return best_id

static func desired_army_composition(resources: Dictionary) -> Dictionary:
	# returns ratios based on available resources
	var iron: int = int(resources.get("iron", resources.get(Economy.Res.IRON, 0)))
	var oil: int = int(resources.get("oil", resources.get(Economy.Res.OIL, 0)))
	var geo: int = int(resources.get("geo", resources.get(Economy.Res.GEOTHERMAL, 0)))
	var inf: float = 0.5
	var veh: float = 0.3
	var air: float = 0.2
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

## Classify a unit into its combined-arms tactical role.
static func unit_role(unit_id: String, unit_class: int = 0, range_px: float = 180.0, stealth: bool = false) -> String:
	if UnitRegistry.is_worker_unit(unit_id):
		return "worker"
	if unit_id in ["scout_drone", "awacs", "ufo_wisp", "lumen_oracle"]:
		return "scout"
	if unit_class == 2:
		return "naval"
	if unit_id in ["aa_vehicle", "fighter_drone", "ufo_talon"]:
		return "anti_air"
	if unit_id in ["artillery", "siege_mech", "sniperbot"] or (range_px >= 340.0 and unit_class != 3):
		return "standoff"
	if stealth or unit_id in ["bomber_drone", "ufo_nova", "hovercraft", "light_mech", "frogbot"]:
		return "raider"
	return "vanguard"

## Estimate a unit's tactical combat value for force-ratio checks and focus fire.
static func unit_combat_power(hp: float, base_damage: float, range_px: float, unit_class: int = 0) -> float:
	var range_factor: float = 1.0 + clampf((range_px - 160.0) / 400.0, 0.0, 0.65)
	var domain_factor: float = 1.15 if unit_class in [3, 7] else (1.05 if unit_class in [1, 2] else 1.0)
	return maxf(1.0, (maxf(1.0, hp) * 0.25 + maxf(1.0, base_damage) * 3.5) * range_factor * domain_factor)

## Score a candidate target for a given attacker using damage-type counters,
## unit-role multipliers, focus-fire finish priority, threat weight and distance.
static func score_target(attacker: Dictionary, target: Dictionary) -> float:
	var attacker_id: String = str(attacker.get("id", ""))
	var attacker_role: String = str(attacker.get("role", "vanguard"))
	var dmg_type: Damage.DamageType = int(attacker.get("damage_type", Damage.DamageType.KINETIC)) as Damage.DamageType
	var attacker_range: float = maxf(80.0, float(attacker.get("range_px", 180.0)))
	var attacker_pos: Vector2 = attacker.get("pos", Vector2.ZERO)

	var target_armor: Damage.ArmorClass = int(target.get("armor_class", Damage.ArmorClass.LIGHT)) as Damage.ArmorClass
	var type_mult: float = Damage.multiplier(dmg_type, target_armor)
	if type_mult <= 0.0:
		return 0.0
	var role_mult: float = Damage.unit_role_multiplier(attacker_id, target_armor)
	var eff_mult: float = type_mult * role_mult

	var hp: float = maxf(1.0, float(target.get("hp", 100.0)))
	var max_hp: float = maxf(hp, float(target.get("max_hp", hp)))
	var hp_ratio: float = clampf(hp / max_hp, 0.0, 1.0)
	var finish_bonus: float = 1.0 + 0.55 * (1.0 - hp_ratio)

	var is_building: bool = bool(target.get("is_building", false))
	var is_hq: bool = bool(target.get("is_hq", false))
	var is_production: bool = bool(target.get("is_production", false))
	var is_economy: bool = bool(target.get("is_economy", false))
	var is_defense: bool = bool(target.get("is_defense", false))
	var target_class: int = int(target.get("unit_class", 0))
	var threat: float = maxf(0.0, float(target.get("threat", 20.0)))

	var role_priority: float = 1.0
	match attacker_role:
		"anti_air":
			if target_armor == Damage.ArmorClass.AIR or target_class == 3:
				role_priority = 2.4
			elif is_building:
				role_priority = 0.65
		"standoff":
			if is_defense or is_production or is_hq:
				role_priority = 1.65
			elif threat >= 50.0:
				role_priority = 1.35
		"raider":
			if is_economy:
				role_priority = 1.95
			elif is_production:
				role_priority = 1.50
			elif not is_building and threat >= 55.0:
				role_priority = 1.45
			elif is_defense:
				role_priority = 0.70
		"naval":
			if target_armor == Damage.ArmorClass.NAVAL or target_armor == Damage.ArmorClass.SUBMERGED:
				role_priority = 1.85
			elif is_production or is_economy:
				role_priority = 1.25
		_:
			if is_defense:
				role_priority = 1.30
			elif is_hq:
				role_priority = 1.25
			elif is_production:
				role_priority = 1.20
			elif not is_building:
				role_priority = 1.15

	var threat_factor: float = 1.0 + clampf(threat / 100.0, 0.0, 0.85)
	var target_pos: Vector2 = target.get("pos", Vector2.ZERO)
	var dist: float = attacker_pos.distance_to(target_pos)
	var in_range_bonus: float = 1.35 if dist <= attacker_range else 1.0
	var dist_falloff: float = 1.0 / (1.0 + dist / maxf(180.0, attacker_range * 1.4))

	return eff_mult * finish_bonus * role_priority * threat_factor * in_range_bonus * dist_falloff

## Pick the highest-scoring target dictionary from `targets`, or `{}` if none valid.
static func choose_best_target(attacker: Dictionary, targets: Array) -> Dictionary:
	var best: Dictionary = {}
	var best_score: float = 0.0
	for raw in targets:
		if not (raw is Dictionary):
			continue
		var t: Dictionary = raw as Dictionary
		var s: float = score_target(attacker, t)
		if s > best_score:
			best_score = s
			best = t
	return best

static func _can_produce(uid: String, available_producers: Array) -> bool:
	if available_producers.is_empty():
		return true
	var uclass: int = Faction.unit_class_for_id(uid)
	for prod_id in UnitRegistry.producer_ids_for_unit(uid, uclass):
		if available_producers.has(prod_id):
			return true
	return false

static func _can_train(
	uid: String, oil: int, iron: int, geo: int, food: int,
	req_oil: int, req_iron: int, req_geo: int, req_food: int,
	available_producers: Array
) -> bool:
	return oil >= req_oil and iron >= req_iron and geo >= req_geo and food >= req_food \
		and _can_produce(uid, available_producers)

static func choose_production_unit(
	wallet: Dictionary, enemy_counts: Dictionary, tech_tier: int = 1, faction_id: int = -1,
	own_counts: Dictionary = {}, available_producers: Array = []
) -> String:
	# Counter-pick against enemy army composition while respecting budget,
	# faction doctrine, existing producers, and tech tier.
	var oil: int = int(wallet.get(Economy.Res.OIL, wallet.get("oil", 0)))
	var iron: int = int(wallet.get(Economy.Res.IRON, wallet.get("iron", 0)))
	var geo: int = int(wallet.get(Economy.Res.GEOTHERMAL, wallet.get("geo", 0)))
	var food: int = int(wallet.get(Economy.Res.FOOD, wallet.get("food", 0)))
	var enemy_air: int = int(enemy_counts.get("air", 0))
	var enemy_veh: int = int(enemy_counts.get("vehicle", 0))
	var enemy_inf: int = int(enemy_counts.get("infantry", 0))
	var enemy_naval: int = int(enemy_counts.get("naval", 0))
	var enemy_sub: int = int(enemy_counts.get("submerged", 0))
	var enemy_stealth: int = int(enemy_counts.get("stealth", 0))
	var enemy_bld: int = int(enemy_counts.get("fortifications", 0))

	var own_workers: int = int(own_counts.get("worker", 1))
	var own_scouts: int = int(own_counts.get("scout", 1))
	var own_aa: int = int(own_counts.get("anti_air", 0))
	var own_naval: int = int(own_counts.get("naval", 0))
	var own_total: int = int(own_counts.get("total", 0))

	# Replace lost workers or scouts once a small force exists.
	if own_counts.has("worker") and own_workers < 1 and own_total >= 2 \
			and _can_train("sapperbot", oil, iron, geo, food, 20, 70, 0, 0, available_producers):
		return "sapperbot"
	if own_counts.has("scout") and own_scouts < 1 and own_total >= 3:
		if faction_id == Faction.Id.VESPER and _can_train("ufo_wisp", oil, iron, geo, food, 40, 60, 10, 0, available_producers):
			return "ufo_wisp"
		if faction_id == Faction.Id.LUMEN and _can_train("lumen_oracle", oil, iron, geo, food, 99, 138, 66, 0, available_producers):
			return "lumen_oracle"
		if _can_train("scout_drone", oil, iron, geo, food, 40, 60, 10, 0, available_producers):
			return "scout_drone"

	# Urgent threat counters (applied even for NPCs when an enemy force threatens
	# a hard counter gap; skipped when enemy_counts is empty).
	if enemy_air >= 2 and own_aa < enemy_air:
		if faction_id == Faction.Id.VESPER and _can_train("ufo_talon", oil, iron, geo, food, 80, 130, 30, 0, available_producers):
			return "ufo_talon"
		if _can_train("aa_vehicle", oil, iron, geo, food, 75, 140, 0, 0, available_producers):
			return "aa_vehicle"
		if _can_train("fighter_drone", oil, iron, geo, food, 80, 120, 30, 0, available_producers):
			return "fighter_drone"
	if enemy_sub >= 1 and own_naval < enemy_sub + 1 \
			and _can_train("corvette", oil, iron, geo, food, 100, 200, 30, 0, available_producers):
		return "corvette"
	if enemy_stealth >= 1 and own_scouts < 2:
		if faction_id == Faction.Id.LUMEN and _can_train("lumen_oracle", oil, iron, geo, food, 99, 138, 66, 0, available_producers):
			return "lumen_oracle"
		if _can_train("awacs", oil, iron, geo, food, 90, 130, 60, 0, available_producers):
			return "awacs"
	if enemy_naval >= 2 and own_naval < enemy_naval:
		if faction_id == Faction.Id.THALASSA and tech_tier >= 2 \
				and _can_train("abyssal_trireme", oil, iron, geo, food, 86, 162, 18, 0, available_producers):
			return "abyssal_trireme"
		if _can_train("attack_sub", oil, iron, geo, food, 110, 190, 50, 0, available_producers):
			return "attack_sub"
		if _can_train("corvette", oil, iron, geo, food, 100, 200, 30, 0, available_producers):
			return "corvette"

	# AI-only NPC factions prioritize their signature hulls when affordable & producible.
	match faction_id:
		Faction.Id.VESPER:
			if tech_tier >= 2 and _can_train("ufo_nova", oil, iron, geo, food, 120, 180, 55, 0, available_producers):
				return "ufo_nova"
			if _can_train("ufo_talon", oil, iron, geo, food, 80, 130, 30, 0, available_producers):
				return "ufo_talon"
			if _can_train("ufo_wisp", oil, iron, geo, food, 40, 60, 10, 0, available_producers):
				return "ufo_wisp"
		Faction.Id.THALASSA:
			if tech_tier >= 3 and _can_train("leviathan_carrier", oil, iron, geo, food, 171, 306, 108, 0, available_producers):
				return "leviathan_carrier"
			if tech_tier >= 2 and _can_train("abyssal_trireme", oil, iron, geo, food, 86, 162, 18, 0, available_producers):
				return "abyssal_trireme"
			if _can_train("nereid_raider", oil, iron, geo, food, 45, 90, 0, 0, available_producers):
				return "nereid_raider"
		Faction.Id.GRAVEBOUND:
			if tech_tier >= 3 and _can_train("lichen_colossus", oil, iron, geo, food, 160, 290, 130, 60, available_producers):
				return "lichen_colossus"
			if _can_train("ghoul_stalker", oil, iron, geo, food, 22, 60, 13, 0, available_producers):
				return "ghoul_stalker"
			if _can_train("bone_legionary", oil, iron, geo, food, 13, 47, 0, 0, available_producers):
				return "bone_legionary"
		Faction.Id.LUMEN:
			if tech_tier >= 2 and _can_train("lumen_enforcer", oil, iron, geo, food, 132, 231, 88, 0, available_producers):
				return "lumen_enforcer"
			if _can_train("lumen_oracle", oil, iron, geo, food, 99, 138, 66, 0, available_producers):
				return "lumen_oracle"
			if _can_train("lumen_operative", oil, iron, geo, food, 33, 83, 22, 0, available_producers):
				return "lumen_operative"
		Faction.Id.AERODYNE:
			if tech_tier >= 2 and _can_train("bomber_drone", oil, iron, geo, food, 99, 144, 45, 0, available_producers):
				return "bomber_drone"
			if _can_train("fighter_drone", oil, iron, geo, food, 72, 108, 27, 0, available_producers):
				return "fighter_drone"
		Faction.Id.FERROCORE:
			if tech_tier >= 3 and _can_train("heavy_tank", oil, iron, geo, food, 120, 240, 40, 0, available_producers):
				return "heavy_tank"
			if enemy_bld >= 2 and _can_train("artillery", oil, iron, geo, food, 100, 190, 30, 0, available_producers):
				return "artillery"
			if tech_tier >= 2 and _can_train("mbt", oil, iron, geo, food, 90, 180, 20, 0, available_producers):
				return "mbt"
		Faction.Id.PELAGIC:
			if tech_tier >= 3 and _can_train("battleship", oil, iron, geo, food, 198, 342, 108, 0, available_producers):
				return "battleship"
			if tech_tier >= 2 and _can_train("attack_sub", oil, iron, geo, food, 99, 171, 45, 0, available_producers):
				return "attack_sub"
			if _can_train("corvette", oil, iron, geo, food, 90, 180, 27, 0, available_producers):
				return "corvette"
		Faction.Id.VANGUARD:
			if enemy_veh >= 3 and _can_train("rocketbot", oil, iron, geo, food, 23, 77, 0, 0, available_producers):
				return "rocketbot"
			if _can_train("stealthbot", oil, iron, geo, food, 27, 68, 18, 0, available_producers):
				return "stealthbot"
			if _can_train("sniperbot", oil, iron, geo, food, 23, 81, 9, 0, available_producers):
				return "sniperbot"
			if _can_train("light_mech", oil, iron, geo, food, 54, 108, 18, 0, available_producers):
				return "light_mech"

	if tech_tier >= 3 and _can_train("heavy_mech", oil, iron, geo, food, 180, 320, 140, 0, available_producers):
		return "heavy_mech"
	if enemy_air >= 2 and _can_train("aa_vehicle", oil, iron, geo, food, 75, 140, 0, 0, available_producers):
		return "aa_vehicle"
	if enemy_veh >= 3:
		if tech_tier >= 2 and _can_train("bomber_drone", oil, iron, geo, food, 110, 160, 50, 0, available_producers):
			return "bomber_drone"
		if _can_train("rocketbot", oil, iron, geo, food, 25, 85, 0, 0, available_producers):
			return "rocketbot"
	if enemy_bld >= 2 and _can_train("artillery", oil, iron, geo, food, 100, 190, 0, 0, available_producers):
		return "artillery"
	if tech_tier >= 2 and _can_train("mbt", oil, iron, geo, food, 90, 180, 0, 0, available_producers):
		return "mbt"
	if enemy_inf >= 3 and _can_train("light_tank", oil, iron, geo, food, 60, 130, 0, 0, available_producers):
		return "light_tank"
	if _can_train("stealthbot", oil, iron, geo, food, 30, 75, 20, 0, available_producers):
		return "stealthbot"
	if _can_train("heavybot", oil, iron, geo, food, 10, 80, 0, 0, available_producers):
		return "heavybot"
	if _can_produce("riflebot", available_producers):
		return "riflebot"
	# Fallback if only specialized producers exist (e.g. airfield-only or docks-only).
	if _can_train("light_tank", oil, iron, geo, food, 60, 130, 0, 0, available_producers):
		return "light_tank"
	if _can_train("scout_drone", oil, iron, geo, food, 40, 60, 10, 0, available_producers):
		return "scout_drone"
	if _can_train("patrol_boat", oil, iron, geo, food, 50, 110, 0, 0, available_producers):
		return "patrol_boat"
	return "riflebot"

static func select_next_building(
	building_counts: Dictionary, pop_used: int, pop_cap: int, faction_id: int = -1,
	power_balance: float = 999.0, enemy_counts: Dictionary = {}, has_water: bool = true,
	tech_tier: int = 1
) -> String:
	if pop_used + 2 >= pop_cap:
		return "farm"

	var barracks := int(building_counts.get("barracks", 0))
	var factory := int(building_counts.get("factory", 0))
	var airfield := int(building_counts.get("airfield", 0))
	var shipyard := int(building_counts.get("shipyard", 0))
	var docks := int(building_counts.get("docks", 0))
	var extractors := int(building_counts.get("extractor", 0))
	var lab := int(building_counts.get("research_lab", 0))
	var radar := int(building_counts.get("radar", 0))
	var turrets := int(building_counts.get("turret", 0))
	var missile_towers := int(building_counts.get("missile_tower", 0))
	var power_plants := int(building_counts.get("power_plant", 0))
	var has_basic_prod := (barracks + factory + airfield + shipyard + docks) >= 1

	# Prevent and recover from power brownouts once opening production is online.
	if power_balance < 0.0:
		return "power_plant"
	if has_basic_prod and power_balance <= 5.0 and power_plants < 6:
		return "power_plant"

	# Reactive counter-buildings against observed enemy threats.
	if has_basic_prod:
		if int(enemy_counts.get("stealth", 0)) > 0 and radar < 1:
			return "radar"
		if int(enemy_counts.get("air", 0)) >= 2 and turrets + missile_towers < 2:
			return "turret"

	# Faction-aware build orders (NPCs 4-7 and corporations 0-3).
	match faction_id:
		Faction.Id.VESPER:
			if airfield < 1:
				return "airfield"
			if extractors < 2:
				return "extractor"
			if barracks < 1:
				return "barracks"
			if extractors < 4:
				return "extractor"
			if lab < 1:
				return "research_lab"
			if radar < 1:
				return "radar"
			if turrets < 2:
				return "turret"
			return "extractor"
		Faction.Id.THALASSA:
			if has_water and shipyard < 1:
				return "shipyard"
			if barracks < 1:
				return "barracks"
			if extractors < 2:
				return "extractor"
			if has_water and docks < 1:
				return "docks"
			if factory < 1:
				return "factory"
			if extractors < 4:
				return "extractor"
			if lab < 1:
				return "research_lab"
			if radar < 1:
				return "radar"
			if turrets < 2:
				return "turret"
			return "extractor"
		Faction.Id.GRAVEBOUND:
			if barracks < 1:
				return "barracks"
			if extractors < 2:
				return "extractor"
			if radar < 1:
				return "radar"  # Offsets Gravebound's -15% sight penalty.
			if factory < 1:
				return "factory"
			if extractors < 4:
				return "extractor"
			if lab < 1:
				return "research_lab"
			if airfield < 1:
				return "airfield"
			if turrets < 2:
				return "turret"
			return "extractor"
		Faction.Id.LUMEN:
			if barracks < 1:
				return "barracks"
			if extractors < 2:
				return "extractor"
			if lab < 1:
				return "research_lab"
			if factory < 1:
				return "factory"
			if airfield < 1:
				return "airfield"
			if radar < 1:
				return "radar"
			if extractors < 4:
				return "extractor"
			if turrets < 2:
				return "turret"
			return "extractor"
		Faction.Id.AERODYNE:
			if barracks < 1:
				return "barracks"
			if extractors < 2:
				return "extractor"
			if airfield < 1:
				return "airfield"
			if lab < 1:
				return "research_lab"
			if factory < 1:
				return "factory"
			if extractors < 4:
				return "extractor"
			if radar < 1:
				return "radar"
			if turrets < 2:
				return "turret"
			return "extractor"
		Faction.Id.FERROCORE:
			if barracks < 1:
				return "barracks"
			if extractors < 2:
				return "extractor"
			if factory < 1:
				return "factory"
			if lab < 1:
				return "research_lab"
			if turrets < 2:
				return "turret"
			if extractors < 4:
				return "extractor"
			if airfield < 1:
				return "airfield"
			if radar < 1:
				return "radar"
			return "extractor"
		Faction.Id.PELAGIC:
			if barracks < 1:
				return "barracks"
			if extractors < 2:
				return "extractor"
			if has_water and shipyard < 1:
				return "shipyard"
			if factory < 1:
				return "factory"
			if has_water and docks < 1:
				return "docks"
			if extractors < 4:
				return "extractor"
			if lab < 1:
				return "research_lab"
			if airfield < 1:
				return "airfield"
			if turrets < 2:
				return "turret"
			return "extractor"
		Faction.Id.VANGUARD:
			if barracks < 1:
				return "barracks"
			if extractors < 2:
				return "extractor"
			if lab < 1:
				return "research_lab"
			if factory < 1:
				return "factory"
			if extractors < 4:
				return "extractor"
			if radar < 1:
				return "radar"
			if airfield < 1:
				return "airfield"
			if turrets < 2:
				return "turret"
			return "extractor"

	# Matches open with an HQ only: the first expansion restores basic
	# unit production before the AI invests in economy buildings.
	if barracks < 1:
		return "barracks"
	if extractors < 2:
		return "extractor"
	if factory < 1:
		return "factory"
	if extractors < 4:
		return "extractor"
	if airfield < 1:
		return "airfield"
	if lab < 1:
		return "research_lab"
	if tech_tier >= 2 and radar < 1:
		return "radar"
	if turrets < 2:
		return "turret"
	return "extractor"

## Select the next research node according to faction doctrine and enemy threats.
static func choose_tech_node(available_nodes: Array, faction_id: int = -1, enemy_counts: Dictionary = {}) -> String:
	if available_nodes.is_empty():
		return ""
	# If enemy fields heavy armor/air, prioritize firepower or armor early.
	if int(enemy_counts.get("vehicle", 0)) >= 3 and available_nodes.has("railgun_cal"):
		return "railgun_cal"
	var priority: Array = doctrine(faction_id).get("tech_priority", [])
	for nid in priority:
		if available_nodes.has(nid):
			return str(nid)
	return str(available_nodes[0])

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

## Multi-sector scouting loop visiting contested mid-map deposits, opposite
## quadrant, flanks, and last-remembered contact (strictly fog-compliant).
static func scout_waypoints(
	base_pos: Vector2, world_size: Vector2,
	deposit_positions: Array = [], known_enemy_pos: Vector2 = Vector2.INF
) -> Array[Vector2]:
	var w := maxf(256.0, world_size.x)
	var h := maxf(256.0, world_size.y)
	var far_x := w * (0.82 if base_pos.x < w * 0.5 else 0.18)
	var far_y := h * (0.82 if base_pos.y < h * 0.5 else 0.18)
	var mid := Vector2(w * 0.5, h * 0.5)
	var flank_a := Vector2(far_x, h * 0.5)
	var flank_b := Vector2(w * 0.5, far_y)

	var points: Array[Vector2] = []
	# First probe near a contested mid-map deposit if any exist.
	var best_dep := Vector2.INF
	var best_dep_score := INF
	for dp in deposit_positions:
		var p: Vector2 = dp
		var dist_mid := p.distance_to(mid)
		var dist_base := p.distance_to(base_pos)
		if dist_base >= 240.0 and dist_mid < best_dep_score:
			best_dep_score = dist_mid
			best_dep = p
	if best_dep != Vector2.INF:
		points.append(best_dep)
	else:
		points.append(mid)
	if known_enemy_pos != Vector2.INF:
		points.append(Vector2(
			clampf(known_enemy_pos.x, 48.0, w - 48.0),
			clampf(known_enemy_pos.y, 48.0, h - 48.0),
		))
	points.append(Vector2(far_x, far_y))
	points.append(flank_a)
	points.append(flank_b)
	return points

## Compute a flanking approach waypoint offset perpendicular to the direct axis.
static func flank_waypoint(
	from_pos: Vector2, target_pos: Vector2, world_size: Vector2,
	side: int = 1, offset_px: float = 240.0
) -> Vector2:
	var dir := target_pos - from_pos
	if dir.length_squared() < 1.0:
		return target_pos
	var norm := dir.normalized()
	var perp := Vector2(-norm.y, norm.x) * (1.0 if side >= 0 else -1.0)
	var mid := from_pos.lerp(target_pos, 0.55) + perp * offset_px
	var w := maxf(256.0, world_size.x)
	var h := maxf(256.0, world_size.y)
	return Vector2(clampf(mid.x, 32.0, w - 32.0), clampf(mid.y, 32.0, h - 32.0))

## Compute optimal standoff firing position for long-range artillery/snipers.
## Pulls back if enemies press inside close range; closes to ~82% range if far.
static func standoff_position(
	unit_pos: Vector2, target_pos: Vector2, weapon_range_px: float, world_size: Vector2
) -> Vector2:
	var ideal_dist := maxf(120.0, weapon_range_px * 0.82)
	var away := unit_pos - target_pos
	if away.length_squared() < 1.0:
		away = Vector2(-1.0, 0.0)
	else:
		away = away.normalized()
	var desired := target_pos + away * ideal_dist
	var w := maxf(256.0, world_size.x)
	var h := maxf(256.0, world_size.y)
	return Vector2(clampf(desired.x, 32.0, w - 32.0), clampf(desired.y, 32.0, h - 32.0))

## Pick a passable rally/staging point ahead of base that maximizes terrain
## cover and attack bonuses for `unit_class` (avoiding swamps/wasteland/water).
static func choose_tactical_rally(
	map: MapData, base_pos: Vector2, enemy_hint_pos: Vector2,
	unit_class: int, world_size: Vector2
) -> Vector2:
	var w := maxf(256.0, world_size.x)
	var h := maxf(256.0, world_size.y)
	var dir := enemy_hint_pos - base_pos
	if dir.length_squared() < 1.0:
		dir = Vector2(-1.0, -1.0) if base_pos.x > w * 0.5 else Vector2(1.0, 1.0)
	else:
		dir = dir.normalized()
	var fallback := Vector2(
		clampf(base_pos.x + dir.x * 220.0, 48.0, w - 48.0),
		clampf(base_pos.y + dir.y * 220.0, 48.0, h - 48.0),
	)
	if map == null:
		return fallback

	var heavy := unit_class in [6, 7]
	var base_angle := dir.angle()
	var best_pos := fallback
	var best_score := -INF
	var radii := [180.0, 240.0, 300.0] if unit_class != 2 else [160.0, 260.0, 380.0, 500.0]
	for r_val in radii:
		var r := float(r_val)
		for step in range(-4, 5):
			var ang := base_angle + float(step) * 0.26
			var cand := Vector2(
				clampf(base_pos.x + cos(ang) * r, 32.0, w - 32.0),
				clampf(base_pos.y + sin(ang) * r, 32.0, h - 32.0),
			)
			var tx := clampi(int(cand.x / 16.0), 0, map.width - 1)
			var ty := clampi(int(cand.y / 16.0), 0, map.height - 1)
			var terrain := map.get_terrain(tx, ty)
			if not MapData.is_passable(terrain, unit_class, heavy):
				continue
			var def_mod := Cover.defense_modifier_for_unit(terrain, unit_class, false)
			var atk_mod := Cover.attack_modifier_for_unit(terrain, unit_class, false)
			var spd_mod := MapData.speed_multiplier(terrain, unit_class, heavy, false)
			# Lower def_mod means less incoming damage (better cover); higher atk/spd is better.
			var score := (1.4 - def_mod) * 2.2 + atk_mod * 1.4 + spd_mod * 0.45 - absf(float(step)) * 0.08
			if score > best_score:
				best_score = score
				best_pos = Vector2(float(tx) * 16.0 + 8.0, float(ty) * 16.0 + 8.0)
	return best_pos

## Pick a safe retreat destination: damaged ground units head to the nearest
## friendly repair worker (sapperbot) or behind HQ; damaged air units prefer
## ducking into a nearby safe drifting cloud (-25% incoming damage).
static func choose_retreat_point(
	unit_pos: Vector2, base_pos: Vector2, unit_class: int,
	repair_positions: Array, clouds: Array, world_size: Vector2
) -> Vector2:
	var w := maxf(256.0, world_size.x)
	var h := maxf(256.0, world_size.y)
	var to_center := Vector2(w * 0.5, h * 0.5) - base_pos
	var back_dir := -to_center.normalized() if to_center.length_squared() > 1.0 else Vector2(-1.0, -1.0).normalized()
	var safe_home := Vector2(
		clampf(base_pos.x + back_dir.x * 64.0, 32.0, w - 32.0),
		clampf(base_pos.y + back_dir.y * 64.0, 32.0, h - 32.0),
	)
	if unit_class == 3 and not clouds.is_empty():
		var best_cloud := Vector2.INF
		var best_d := 420.0
		for c in clouds:
			if not (c is Dictionary):
				continue
			var cpos: Vector2 = (c as Dictionary).get("pos", Vector2.INF)
			if cpos == Vector2.INF:
				continue
			# Prefer a cloud closer to home than the unit currently is.
			var d_unit := unit_pos.distance_to(cpos)
			if d_unit < best_d and cpos.distance_to(base_pos) <= unit_pos.distance_to(base_pos) + 120.0:
				best_d = d_unit
				best_cloud = cpos
		if best_cloud != Vector2.INF:
			return Vector2(clampf(best_cloud.x, 32.0, w - 32.0), clampf(best_cloud.y, 32.0, h - 32.0))
	if unit_class != 2:
		var best_repair := Vector2.INF
		var best_r_dist := 480.0
		for rp in repair_positions:
			var rpos: Vector2 = rp
			var d_home := rpos.distance_to(base_pos)
			var d_unit := unit_pos.distance_to(rpos)
			if d_home <= 460.0 and d_unit < best_r_dist:
				best_r_dist = d_unit
				best_repair = rpos
		if best_repair != Vector2.INF:
			return best_repair
	return safe_home

## Find the highest-value visible enemy cluster center for Orbital Laser / Nuke.
## Callers MUST pass only fog-visible enemy entries: [{pos: Vector2, value: float}].
static func choose_strategic_strike_target(
	enemy_entries: Array, radius_px: float, min_value: float
) -> Vector2:
	if enemy_entries.is_empty():
		return Vector2.INF
	var best_pos := Vector2.INF
	var best_val := 0.0
	var r2 := radius_px * radius_px
	for cand in enemy_entries:
		if not (cand is Dictionary):
			continue
		var cpos: Vector2 = (cand as Dictionary).get("pos", Vector2.INF)
		if cpos == Vector2.INF:
			continue
		var cluster_val := 0.0
		for other in enemy_entries:
			if not (other is Dictionary):
				continue
			var opos: Vector2 = (other as Dictionary).get("pos", Vector2.INF)
			if opos != Vector2.INF and cpos.distance_squared_to(opos) <= r2:
				cluster_val += float((other as Dictionary).get("value", 0.0))
		if cluster_val > best_val:
			best_val = cluster_val
			best_pos = cpos
	if best_val < min_value:
		return Vector2.INF
	return best_pos

## Pick a forward perimeter fortification tile facing `enemy_hint_pos`.
static func choose_fortification_site(
	map: MapData, base_pos: Vector2, enemy_hint_pos: Vector2,
	occupied: Dictionary, bid: String
) -> Vector2:
	if map == null:
		return Vector2.INF
	var fp := Vector2i(2, 2) if bid == "missile_tower" else Vector2i(1, 1)
	var dir := enemy_hint_pos - base_pos
	if dir.length_squared() < 1.0:
		dir = Vector2(-1.0, -1.0)
	else:
		dir = dir.normalized()
	var base_angle := dir.angle()
	for dist in [128.0, 160.0, 192.0]:
		for step in [0, 1, -1, 2, -2, 3, -3]:
			var ang := base_angle + float(step) * 0.25
			var cand := base_pos + Vector2(cos(ang), sin(ang)) * float(dist)
			var origin := Vector2i(int(cand.x / 16.0), int(cand.y / 16.0))
			if Placement.can_place_building(map, bid, fp, origin, occupied):
				return Vector2(float(origin.x) * 16.0 + 8.0, float(origin.y) * 16.0 + 8.0)
	return Vector2.INF

## Decide whether a corvette should drop a sonar buoy near its forward waters.
static func should_deploy_sonar(
	corvette_pos: Vector2, enemy_hint_pos: Vector2,
	active_buoys: Array, team: int, enemy_counts: Dictionary
) -> Vector2:
	var naval_threat := int(enemy_counts.get("submerged", 0)) > 0 or int(enemy_counts.get("naval", 0)) >= 1
	if not naval_threat and corvette_pos.distance_to(enemy_hint_pos) > 900.0:
		return Vector2.INF
	var dir := enemy_hint_pos - corvette_pos
	var drop_pos := corvette_pos
	if dir.length_squared() > 1.0:
		drop_pos = corvette_pos + dir.normalized() * minf(SonarBuoy.DEPLOY_RANGE_PX * 0.7, dir.length() * 0.5)
	for buoy in active_buoys:
		if not (buoy is Dictionary):
			continue
		var owner_t := int((buoy as Dictionary).get("owner_team", -1))
		if owner_t == team:
			var bpos: Vector2 = (buoy as Dictionary).get("pos", Vector2.INF)
			if bpos != Vector2.INF and bpos.distance_to(drop_pos) < SonarBuoy.RADIUS_PX * 0.85:
				return Vector2.INF
	return drop_pos

static func choose_tactical_state(
	own_combat_count: int, enemy_near_base: int, wave_threshold: int,
	own_power: float = -1.0, enemy_power: float = 0.0, faction_id: int = -1,
	difficulty: int = Difficulty.NORMAL
) -> String:
	if enemy_near_base > 0:
		return "defend"
	var half_wave := maxi(1, int(float(wave_threshold) * 0.5))
	if own_power >= 0.0 and enemy_power > 0.0 and difficulty >= Difficulty.NORMAL:
		var ratio := own_power / maxf(1.0, enemy_power)
		var commit_ratio := float(doctrine(faction_id).get("commit_ratio", 0.68))
		if own_combat_count >= wave_threshold:
			if ratio >= commit_ratio:
				return "attack"
			return "harass" if own_combat_count >= half_wave else "regroup"
		if ratio >= 1.35 and own_combat_count >= maxi(2, wave_threshold - 1):
			return "attack"
		if own_combat_count >= half_wave:
			return "regroup" if ratio < 0.55 else "harass"
		return "rally"
	if own_combat_count >= wave_threshold:
		return "attack"
	if own_combat_count >= half_wave:
		return "harass"
	return "rally"
