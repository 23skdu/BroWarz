# scripts/core/unit_registry.gd
class_name UnitRegistry
extends RefCounted

var units: Dictionary = {}  # id -> UnitStats
var buildings: Dictionary = {}  # id -> BuildingStats

## Unique NPC hulls, keyed by faction id. These ids are append-only: never
## renumber an existing unit id because saves and replays store it verbatim.
const NPC_UNIQUE_UNITS := {
	4: ["ufo_wisp", "ufo_talon", "ufo_nova"],
	5: ["abyssal_trireme", "leviathan_carrier", "nereid_raider"],
	6: ["bone_legionary", "ghoul_stalker", "lichen_colossus"],
	7: ["lumen_operative", "lumen_oracle", "lumen_enforcer"],
}

func register_unit(s: UnitStats) -> void:
	units[s.id] = s

func register_building(s: BuildingStats) -> void:
	buildings[s.id] = s

func get_unit(id: String) -> UnitStats:
	return units.get(id, null)

func get_building(id: String) -> BuildingStats:
	return buildings.get(id, null)

func has_unit(id: String) -> bool:
	return units.has(id)

func has_building(id: String) -> bool:
	return buildings.has(id)

static func transport_capacity(unit_id: String) -> int:
	match unit_id:
		"landing_craft": return 4
		"apc": return 3
		"hovercraft": return 2
		"aircraft_carrier", "leviathan_carrier": return 4
	return 0

static func can_embark(transport_id: String, passenger_id: String, passenger_class: int) -> bool:
	var cap := transport_capacity(transport_id)
	if cap <= 0 or transport_id == passenger_id:
		return false
	if transport_id == "aircraft_carrier" or transport_id == "leviathan_carrier":
		return passenger_class == 3
	# Amphibious transports & APCs carry infantry (0), frogbot commandos (5), and heavy infantry (6)
	return passenger_class in [0, 5, 6]

## Worker IDs that can repair, capture and construct fortifications.
## `sapperbot` is the unified role; the engineer/medic ids are aliases.
static func is_worker_unit(unit_id: String) -> bool:
	return unit_id in ["sapperbot", "engineerbot", "adv_engineerbot", "medicbot"]

## Fast reconnaissance platforms the AI sends ahead of its main squad.
static func is_scout_unit(unit_id: String) -> bool:
	return unit_id in ["scout_drone", "awacs", "patrol_boat", "light_mech", "sniperbot", "ufo_wisp", "lumen_oracle"]

## True for the twelve faction-exclusive AI hulls.
static func is_ai_only(unit_id: String) -> bool:
	for roster in NPC_UNIQUE_UNITS.values():
		if unit_id in roster:
			return true
	return false

## Native NPC faction id (4-7), or -1 for shared/human units.
static func npc_faction_for_unit(unit_id: String) -> int:
	for faction_id in NPC_UNIQUE_UNITS.keys():
		if unit_id in NPC_UNIQUE_UNITS[faction_id]:
			return int(faction_id)
	return -1

## Unique roster for an NPC faction; the ordinary shared roster otherwise.
func units_for_faction(faction_id: int) -> Array:
	if NPC_UNIQUE_UNITS.has(faction_id):
		return (NPC_UNIQUE_UNITS[faction_id] as Array).duplicate()
	var out: Array = []
	for uid in units.keys():
		var s: UnitStats = units[uid]
		if s != null and not s.ai_only:
			out.append(str(uid))
	out.sort()
	return out

## Escort hulls that can drop naval early-warning sonar buoys.
static func can_deploy_sonar_buoy(unit_id: String) -> bool:
	return unit_id == "corvette"

## Production structures eligible for worker capture (HQs and defenses excluded).
static func is_production_building(building_id: String) -> bool:
	return building_id in [
		"barracks", "factory", "airfield", "shipyard",
		"docks", "mech_factory_1", "mech_factory_2", "mech_factory_3",
		"advanced_shipyard", "aeries_1", "aeries_2",
	]

static func requires_advanced_builder(building_id: String) -> bool:
	return building_id in ["mech_factory_3", "advanced_shipyard", "aeries_2"]

static func can_unit_construct(builder_unit_id: String, building_id: String) -> bool:
	if builder_unit_id == "sapperbot":
		return Fortification.is_fortification(building_id)
	if builder_unit_id == "adv_engineerbot":
		return true
	if builder_unit_id == "engineerbot":
		return not requires_advanced_builder(building_id)
	return false

static func producer_ids_for_unit(unit_id: String, unit_class: int = 0) -> Array[String]:
	match unit_id:
		"engineerbot":
			return ["hq", "mech_factory_1", "barracks"]
		"adv_engineerbot", "apc", "mbt", "artillery", "aa_vehicle":
			return ["mech_factory_2", "factory"]
		"heavy_tank", "heavy_mech", "siege_mech":
			return ["mech_factory_3", "factory"]
		"patrol_boat", "landing_craft", "hovercraft", "frogbot":
			return ["docks", "shipyard"]
		"corvette", "attack_sub", "cruiser":
			return ["shipyard", "advanced_shipyard"]
		"battleship", "aircraft_carrier", "ballistic_sub":
			return ["advanced_shipyard", "shipyard"]
		"scout_drone", "fighter_drone":
			return ["aeries_1", "aeries_2", "airfield"]
		"bomber_drone", "awacs":
			return ["aeries_2", "aeries_1", "airfield"]
		# NPC-exclusive hulls: every one has at least one ordinary producer so
		# AI teams can field them after their faction-specific build order.
		"ufo_wisp", "ufo_talon", "ufo_nova":
			return ["airfield", "aeries_1", "aeries_2"]
		"abyssal_trireme", "nereid_raider":
			return ["shipyard", "docks", "advanced_shipyard"]
		"leviathan_carrier":
			return ["shipyard", "advanced_shipyard", "docks"]
		"bone_legionary", "ghoul_stalker", "lumen_operative":
			return ["barracks", "mech_factory_1"]
		"lichen_colossus":
			return ["factory", "mech_factory_2", "mech_factory_3"]
		"lumen_oracle":
			return ["research_lab", "airfield", "aeries_1", "aeries_2"]
		"lumen_enforcer":
			return ["factory", "mech_factory_2"]
	match unit_class:
		1, 7:
			return ["mech_factory_2", "mech_factory_1", "factory"]
		2, 4, 5:
			return ["docks", "shipyard", "advanced_shipyard"]
		3:
			return ["aeries_1", "aeries_2", "airfield"]
		_:
			return ["mech_factory_1", "barracks"]

## Register an alias id that resolves to the sapperbot worker role.
func _register_alias(alias_id: String) -> void:
	var base: UnitStats = units.get("sapperbot", null)
	if base == null:
		return
	units[alias_id] = base.duplicate()
	units[alias_id].id = alias_id

func populate_defaults() -> void:
	# Infantry & Mechanized (Part 8)
	_add_u("riflebot", "Riflebot", 100, 130.0, Damage.ArmorClass.UNARMORED, Damage.DamageType.KINETIC, 12, 180.0, 280.0, 0, 50, 0, 25, 3.0, 0, false, false)
	_add_u("heavybot", "Heavybot", 180, 95.0, Damage.ArmorClass.LIGHT, Damage.DamageType.KINETIC, 18, 190.0, 260.0, 10, 80, 0, 35, 4.0, 6, false, false)
	_add_u("sapperbot", "Sapperbot", 110, 135.0, Damage.ArmorClass.LIGHT, Damage.DamageType.EXPLOSIVE, 35, 100.0, 250.0, 20, 70, 0, 25, 4.0, 0, false, true)
	_add_u("stealthbot", "Stealthbot", 85, 150.0, Damage.ArmorClass.UNARMORED, Damage.DamageType.ENERGY, 26, 170.0, 340.0, 30, 75, 20, 30, 4.5, 0, true, false)
	_add_u("sniperbot", "Sniperbot", 80, 115.0, Damage.ArmorClass.UNARMORED, Damage.DamageType.KINETIC, 40, 340.0, 380.0, 25, 90, 10, 30, 5.0, 0, false, false)
	_add_u("rocketbot", "Rocketbot", 105, 115.0, Damage.ArmorClass.LIGHT, Damage.DamageType.EXPLOSIVE, 28, 230.0, 280.0, 25, 85, 0, 30, 4.0, 0, false, false)
	# Sapperbot is the unified worker role (sapper/engineer/medic merged);
	# engineerbot/medicbot/adv_engineerbot are compatibility aliases.
	_register_alias("engineerbot")
	_register_alias("adv_engineerbot")
	_register_alias("medicbot")
	_add_u("apc", "APC/IFV", 240, 155.0, Damage.ArmorClass.MEDIUM, Damage.DamageType.KINETIC, 16, 200.0, 300.0, 50, 110, 0, 20, 5.0, 1, false, false)
	_add_u("light_mech", "Light Mech", 260, 145.0, Damage.ArmorClass.MEDIUM, Damage.DamageType.KINETIC, 22, 210.0, 310.0, 60, 120, 20, 20, 5.5, 1, false, false)
	# Vehicles & Heavy Mechs (Part 9)
	_add_u("light_tank", "Light Tank", 280, 140.0, Damage.ArmorClass.MEDIUM, Damage.DamageType.EXPLOSIVE, 26, 220.0, 300.0, 60, 130, 0, 20, 5.5, 1, false, false)
	_add_u("mbt", "Main Battle Tank", 420, 115.0, Damage.ArmorClass.HEAVY, Damage.DamageType.EXPLOSIVE, 42, 250.0, 300.0, 90, 180, 20, 25, 7.0, 1, false, false)
	_add_u("heavy_tank", "Heavy Tank", 580, 90.0, Damage.ArmorClass.HEAVY, Damage.DamageType.EXPLOSIVE, 58, 260.0, 290.0, 120, 240, 40, 30, 8.5, 1, false, false)
	_add_u("artillery", "Self-Propelled Artillery", 240, 85.0, Damage.ArmorClass.MEDIUM, Damage.DamageType.EXPLOSIVE, 65, 420.0, 320.0, 100, 190, 30, 25, 8.0, 1, false, false)
	_add_u("aa_vehicle", "Anti-Air Vehicle", 260, 130.0, Damage.ArmorClass.MEDIUM, Damage.DamageType.KINETIC, 30, 300.0, 360.0, 75, 140, 20, 20, 6.0, 1, false, false)
	_add_u("heavy_mech", "Heavy Killer Mech", 850, 85.0, Damage.ArmorClass.HEAVY, Damage.DamageType.ENERGY, 85, 290.0, 360.0, 180, 320, 140, 40, 11.0, 7, false, false)
	_add_u("siege_mech", "Siege Mech", 650, 75.0, Damage.ArmorClass.HEAVY, Damage.DamageType.THERMAL, 95, 450.0, 360.0, 160, 280, 160, 40, 11.0, 7, false, false)
	# Naval & Submarines (Part 10)
	_add_u("patrol_boat", "Patrol Sea Drone", 240, 150.0, Damage.ArmorClass.NAVAL, Damage.DamageType.KINETIC, 22, 230.0, 320.0, 50, 110, 0, 15, 5.0, 2, false, false)
	_add_u("corvette", "Missile Corvette", 420, 120.0, Damage.ArmorClass.NAVAL, Damage.DamageType.EXPLOSIVE, 46, 320.0, 350.0, 100, 200, 30, 25, 7.5, 2, false, false)
	_add_u("attack_sub", "Attack Submarine", 320, 115.0, Damage.ArmorClass.SUBMERGED, Damage.DamageType.EXPLOSIVE, 52, 270.0, 310.0, 110, 190, 50, 25, 8.0, 2, true, false)
	_add_u("ballistic_sub", "Ballistic Missile Submarine", 420, 100.0, Damage.ArmorClass.SUBMERGED, Damage.DamageType.EXPLOSIVE, 80, 320.0, 300.0, 180, 260, 120, 35, 12.0, 2, true, false)
	_add_u("landing_craft", "Landing Craft", 260, 135.0, Damage.ArmorClass.NAVAL, Damage.DamageType.KINETIC, 12, 180.0, 290.0, 40, 100, 0, 15, 5.0, 2, false, false)
	_add_u("hovercraft", "Eel-Prone Hovercraft", 220, 160.0, Damage.ArmorClass.LIGHT, Damage.DamageType.KINETIC, 18, 210.0, 320.0, 60, 90, 0, 20, 5.0, 4, false, false)
	# Naval capital ships + frogbots
	_add_u("cruiser", "Cruiser", 620, 110.0, Damage.ArmorClass.NAVAL, Damage.DamageType.KINETIC, 48, 320.0, 340.0, 150, 260, 40, 30, 9.0, 2, false, false)
	_add_u("battleship", "Battleship", 980, 85.0, Damage.ArmorClass.NAVAL, Damage.DamageType.EXPLOSIVE, 95, 420.0, 360.0, 220, 380, 120, 45, 14.0, 2, false, false)
	_add_u("aircraft_carrier", "Aircraft Carrier", 880, 90.0, Damage.ArmorClass.NAVAL, Damage.DamageType.KINETIC, 35, 300.0, 400.0, 200, 360, 140, 40, 13.0, 2, false, false)
	_add_u("frogbot", "Frogbot (Stealth)", 130, 120.0, Damage.ArmorClass.UNARMORED, Damage.DamageType.EXPLOSIVE, 75, 120.0, 260.0, 40, 80, 30, 20, 5.5, 5, true, false)
	# Air & Orbital (Part 11)
	_add_u("scout_drone", "Scout Aerial Drone", 120, 220.0, Damage.ArmorClass.AIR, Damage.DamageType.KINETIC, 10, 190.0, 460.0, 40, 60, 10, 10, 3.5, 3, false, false)
	_add_u("fighter_drone", "Fighter Drone", 210, 200.0, Damage.ArmorClass.AIR, Damage.DamageType.KINETIC, 32, 260.0, 380.0, 80, 120, 30, 15, 5.5, 3, false, false)
	_add_u("bomber_drone", "Bomber Drone", 290, 165.0, Damage.ArmorClass.AIR, Damage.DamageType.EXPLOSIVE, 62, 240.0, 350.0, 110, 160, 50, 20, 7.0, 3, false, false)
	_add_u("awacs", "AWACS Radar Drone", 260, 175.0, Damage.ArmorClass.AIR, Damage.DamageType.EMP, 15, 240.0, 540.0, 90, 130, 60, 20, 6.5, 3, false, false)

	# AI-only faction hulls (factions 4-7). Appended only: save/replay unit ids
	# for the original roster must keep their existing numeric meaning.
	# Vesper Ascendancy — aerial saucers, every hull is air class 3.
	_add_u("ufo_wisp", "UFO Wisp", 140, 250.0, Damage.ArmorClass.AIR, Damage.DamageType.KINETIC, 12, 180.0, 620.0, 40, 60, 10, 0, 3.5, 3, false, false, true, 4)
	_add_u("ufo_talon", "UFO Talon", 230, 220.0, Damage.ArmorClass.AIR, Damage.DamageType.EXPLOSIVE, 38, 260.0, 420.0, 80, 130, 30, 0, 5.5, 3, false, false, true, 4)
	_add_u("ufo_nova", "UFO Nova", 300, 170.0, Damage.ArmorClass.AIR, Damage.DamageType.EXPLOSIVE, 68, 240.0, 360.0, 120, 180, 55, 0, 7.5, 3, false, false, true, 4)
	# Thalassa Dominion — Atlantean naval hulls, class 2.
	_add_u("abyssal_trireme", "Abyssal Trireme", 520, 135.0, Damage.ArmorClass.NAVAL, Damage.DamageType.EXPLOSIVE, 44, 340.0, 380.0, 95, 180, 20, 0, 7.0, 2, false, false, true, 5)
	_add_u("leviathan_carrier", "Leviathan Carrier", 900, 95.0, Damage.ArmorClass.NAVAL, Damage.DamageType.KINETIC, 40, 300.0, 420.0, 190, 340, 120, 0, 13.0, 2, false, false, true, 5)
	_add_u("nereid_raider", "Nereid Raider", 280, 180.0, Damage.ArmorClass.NAVAL, Damage.DamageType.KINETIC, 28, 200.0, 350.0, 50, 100, 0, 0, 5.0, 2, false, false, true, 5)
	# Gravebound Legion — undead infantry and rot-forged heavy mech.
	_add_u("bone_legionary", "Bone Legionary", 140, 125.0, Damage.ArmorClass.LIGHT, Damage.DamageType.KINETIC, 20, 170.0, 270.0, 15, 55, 0, 20, 3.5, 0, false, false, true, 6)
	_add_u("ghoul_stalker", "Ghoul Stalker", 100, 170.0, Damage.ArmorClass.UNARMORED, Damage.DamageType.TOXIC, 32, 160.0, 330.0, 25, 70, 15, 35, 4.5, 0, true, false, true, 6)
	_add_u("lichen_colossus", "Lichen Colossus", 820, 80.0, Damage.ArmorClass.HEAVY, Damage.DamageType.THERMAL, 80, 280.0, 320.0, 160, 290, 130, 60, 11.0, 7, false, false, true, 6)
	# Lumen Cabal — covert Operatives, all-seeing Oracles and armored Enforcers.
	_add_u("lumen_operative", "Lumen Operative", 110, 160.0, Damage.ArmorClass.LIGHT, Damage.DamageType.ENERGY, 30, 180.0, 360.0, 30, 75, 20, 25, 4.5, 0, true, false, true, 7)
	_add_u("lumen_oracle", "Lumen Oracle", 220, 185.0, Damage.ArmorClass.AIR, Damage.DamageType.EMP, 18, 280.0, 560.0, 90, 125, 60, 20, 6.5, 3, false, false, true, 7)
	_add_u("lumen_enforcer", "Lumen Enforcer", 620, 105.0, Damage.ArmorClass.HEAVY, Damage.DamageType.ENERGY, 68, 260.0, 330.0, 120, 210, 80, 30, 9.0, 1, false, false, true, 7)

	# Buildings & Tiered Factories (Part 15)
	_add_b("hq", "Corporate HQ", 1200, 0, 400, 0, 100, Vector2i(3, 3), "engineerbot", 12.0, true)
	_add_b("docks", "Naval Docks", 550, 50, 160, 0, 25, Vector2i(2, 2), "patrol_boat", 5.5, false)
	_add_b("mech_factory_1", "Mech Factory 1", 650, 60, 170, 0, 40, Vector2i(2, 2), "riflebot", 6.0, false)
	_add_b("mech_factory_2", "Mech Factory 2", 850, 120, 260, 50, 50, Vector2i(3, 2), "mbt", 8.5, false)
	_add_b("mech_factory_3", "Mech Factory 3", 1150, 220, 420, 150, 70, Vector2i(3, 3), "heavy_mech", 12.0, false)
	_add_b("shipyard", "Naval Shipyard", 750, 90, 220, 30, 30, Vector2i(3, 2), "corvette", 7.5, false)
	_add_b("advanced_shipyard", "Advanced Shipyard", 1050, 180, 360, 110, 50, Vector2i(3, 3), "battleship", 11.5, false)
	_add_b("aeries_1", "Aeries Level 1", 650, 90, 190, 40, 30, Vector2i(2, 2), "fighter_drone", 7.0, false)
	_add_b("aeries_2", "Aeries Level 2", 920, 170, 310, 110, 45, Vector2i(3, 2), "bomber_drone", 10.0, false)
	# Legacy aliases for existing missions/AI
	_add_b("barracks", "Robot Barracks (Mech Factory 1)", 600, 40, 150, 0, 50, Vector2i(2, 2), "riflebot", 6.0, false)
	_add_b("factory", "Armor & Mech Factory (Mech Factory 2)", 800, 100, 240, 40, 40, Vector2i(3, 2), "mbt", 8.0, false)
	_add_b("airfield", "Drone Airfield (Aeries Level 1)", 650, 100, 200, 50, 30, Vector2i(2, 2), "fighter_drone", 7.0, false)
	_add_b("extractor", "Resource Extractor", 450, 30, 120, 0, 20, Vector2i(2, 2), "", 5.0, false)
	_add_b("farm", "Hydroponic Farm", 400, 20, 100, 0, 30, Vector2i(2, 2), "", 4.5, false)
	_add_b("power_plant", "Geothermal Plant", 550, 50, 160, 20, 20, Vector2i(2, 2), "", 6.0, false)
	_add_b("research_lab", "Research Lab", 600, 80, 180, 60, 30, Vector2i(2, 2), "", 7.0, false)
	_add_b("radar", "Radar Array", 480, 60, 140, 50, 20, Vector2i(2, 2), "", 5.5, false, 480.0)
	_add_b("turret", "Defense Turret", 520, 40, 150, 20, 15, Vector2i(1, 1), "", 4.5, false)
	_add_b("silo", "Nuclear Missile Silo", 900, 250, 400, 300, 80, Vector2i(3, 3), "", 14.0, false)
	_add_b("orbital_uplink", "Orbital Laser Uplink", 850, 200, 350, 280, 60, Vector2i(2, 2), "", 12.0, false)
	# Sapper fortifications (Part 3/11 follow-up)
	_add_b("missile_tower", "Missile Tower", 600, 30, 120, 60, 0, Vector2i(2, 2), "", 6.0, false, 320.0)
	_add_b("wall", "Barrier Wall", 900, 0, 45, 0, 0, Vector2i(1, 1), "", 2.0, false)
	_add_b("barbed_wire", "Barbed Wire", 150, 0, 15, 0, 0, Vector2i(1, 1), "", 1.0, false)

func _add_u(
	id: String, dname: String, hp_v: int, spd: float, armor: int, dmg_t: int, dmg: int,
	rng: float, sgt: float, oil: int, iron: int, geo: int, food: int, btime: float,
	uclass: int, stl: bool, bld: bool, ai_only_flag: bool = false, native_fac: int = -1
) -> void:
	var s := UnitStats.new()
	s.id = id
	s.display_name = dname
	s.hp = hp_v
	s.speed = spd
	s.armor_class = armor
	s.damage_type = dmg_t
	s.base_damage = dmg
	s.range_px = rng
	s.sight = sgt
	s.cost_oil = oil
	s.cost_iron = iron
	s.cost_geo = geo
	s.cost_food = food
	s.build_time = btime
	s.unit_class = uclass
	s.stealth = stl
	s.can_build = bld
	s.ai_only = ai_only_flag
	s.native_faction = native_fac
	register_unit(s)

func _add_b(id: String, dname: String, hp_v: int, oil: int, iron: int, geo: int, food: int, fp: Vector2i, prod: String, btime: float, hq: bool, radar_range: float = 0.0) -> void:
	var b := BuildingStats.new()
	b.id = id
	b.display_name = dname
	b.hp = hp_v
	b.cost_oil = oil
	b.cost_iron = iron
	b.cost_geo = geo
	b.cost_food = food
	b.footprint = fp
	b.produces = prod
	b.build_time = btime
	b.is_hq = hq
	b.radar_range = radar_range
	register_building(b)
