# scripts/core/unit_registry.gd
class_name UnitRegistry
extends RefCounted

var units: Dictionary = {}  # id -> UnitStats
var buildings: Dictionary = {}  # id -> BuildingStats

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

func populate_defaults() -> void:
	# Infantry & Mechanized (Part 8)
	_add_u("riflebot", "Riflebot", 100, 130.0, Damage.ArmorClass.UNARMORED, Damage.DamageType.KINETIC, 12, 180.0, 280.0, 0, 50, 0, 25, 3.0, 0, false, false)
	_add_u("heavybot", "Heavybot", 180, 95.0, Damage.ArmorClass.LIGHT, Damage.DamageType.KINETIC, 18, 190.0, 260.0, 10, 80, 0, 35, 4.0, 6, false, false)
	_add_u("sapperbot", "Sapperbot", 110, 135.0, Damage.ArmorClass.LIGHT, Damage.DamageType.EXPLOSIVE, 35, 100.0, 250.0, 20, 70, 0, 25, 4.0, 0, false, true)
	_add_u("stealthbot", "Stealthbot", 85, 150.0, Damage.ArmorClass.UNARMORED, Damage.DamageType.ENERGY, 26, 170.0, 340.0, 30, 75, 20, 30, 4.5, 0, true, false)
	_add_u("sniperbot", "Sniperbot", 80, 115.0, Damage.ArmorClass.UNARMORED, Damage.DamageType.KINETIC, 40, 340.0, 380.0, 25, 90, 10, 30, 5.0, 0, false, false)
	_add_u("rocketbot", "Rocketbot", 105, 115.0, Damage.ArmorClass.LIGHT, Damage.DamageType.EXPLOSIVE, 28, 230.0, 280.0, 25, 85, 0, 30, 4.0, 0, false, false)
	_add_u("medicbot", "Medicbot", 110, 130.0, Damage.ArmorClass.LIGHT, Damage.DamageType.ENERGY, 8, 140.0, 280.0, 20, 60, 15, 30, 3.5, 0, false, false)
	_add_u("engineerbot", "Engineerbot", 120, 125.0, Damage.ArmorClass.LIGHT, Damage.DamageType.KINETIC, 6, 110.0, 280.0, 10, 60, 0, 25, 3.0, 0, false, true)
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
	# Naval capital ships + frogmen
	_add_u("cruiser", "Cruiser", 620, 110.0, Damage.ArmorClass.NAVAL, Damage.DamageType.KINETIC, 48, 320.0, 340.0, 150, 260, 40, 30, 9.0, 2, false, false)
	_add_u("battleship", "Battleship", 980, 85.0, Damage.ArmorClass.NAVAL, Damage.DamageType.EXPLOSIVE, 95, 420.0, 360.0, 220, 380, 120, 45, 14.0, 2, false, false)
	_add_u("aircraft_carrier", "Aircraft Carrier", 880, 90.0, Damage.ArmorClass.NAVAL, Damage.DamageType.KINETIC, 35, 300.0, 400.0, 200, 360, 140, 40, 13.0, 2, false, false)
	_add_u("frogman", "Frogman (Stealth)", 130, 120.0, Damage.ArmorClass.UNARMORED, Damage.DamageType.EXPLOSIVE, 75, 120.0, 260.0, 40, 80, 30, 20, 5.5, 5, true, false)
	# Air & Orbital (Part 11)
	_add_u("scout_drone", "Scout Aerial Drone", 120, 220.0, Damage.ArmorClass.AIR, Damage.DamageType.KINETIC, 10, 190.0, 460.0, 40, 60, 10, 10, 3.5, 3, false, false)
	_add_u("fighter_drone", "Fighter Drone", 210, 200.0, Damage.ArmorClass.AIR, Damage.DamageType.KINETIC, 32, 260.0, 380.0, 80, 120, 30, 15, 5.5, 3, false, false)
	_add_u("bomber_drone", "Bomber Drone", 290, 165.0, Damage.ArmorClass.AIR, Damage.DamageType.EXPLOSIVE, 62, 240.0, 350.0, 110, 160, 50, 20, 7.0, 3, false, false)
	_add_u("awacs", "AWACS Radar Drone", 260, 175.0, Damage.ArmorClass.AIR, Damage.DamageType.EMP, 15, 240.0, 540.0, 90, 130, 60, 20, 6.5, 3, false, false)

	# Buildings (Part 15)
	_add_b("hq", "Corporate HQ", 1200, 0, 400, 0, 100, Vector2i(3, 3), "engineerbot", 12.0, true)
	_add_b("barracks", "Robot Barracks", 600, 40, 150, 0, 50, Vector2i(2, 2), "riflebot", 6.0, false)
	_add_b("factory", "Armor & Mech Factory", 800, 100, 240, 40, 40, Vector2i(3, 2), "mbt", 8.0, false)
	_add_b("airfield", "Drone Airfield", 650, 100, 200, 50, 30, Vector2i(2, 2), "fighter_drone", 7.0, false)
	_add_b("shipyard", "Naval Shipyard", 750, 90, 220, 30, 30, Vector2i(3, 2), "patrol_boat", 7.5, false)
	_add_b("extractor", "Resource Extractor", 450, 30, 120, 0, 20, Vector2i(2, 2), "", 5.0, false)
	_add_b("farm", "Hydroponic Farm", 400, 20, 100, 0, 30, Vector2i(2, 2), "", 4.5, false)
	_add_b("power_plant", "Geothermal Plant", 550, 50, 160, 20, 20, Vector2i(2, 2), "", 6.0, false)
	_add_b("research_lab", "Research Lab", 600, 80, 180, 60, 30, Vector2i(2, 2), "", 7.0, false)
	_add_b("radar", "Radar Array", 480, 60, 140, 50, 20, Vector2i(2, 2), "", 5.5, false)
	_add_b("turret", "Defense Turret", 520, 40, 150, 20, 15, Vector2i(1, 1), "", 4.5, false)
	_add_b("silo", "Nuclear Missile Silo", 900, 250, 400, 300, 80, Vector2i(3, 3), "", 14.0, false)
	_add_b("orbital_uplink", "Orbital Laser Uplink", 850, 200, 350, 280, 60, Vector2i(2, 2), "", 12.0, false)

func _add_u(
	id: String, dname: String, hp_v: int, spd: float, armor: int, dmg_t: int, dmg: int,
	rng: float, sgt: float, oil: int, iron: int, geo: int, food: int, btime: float,
	uclass: int, stl: bool, bld: bool
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
	register_unit(s)

func _add_b(id: String, dname: String, hp_v: int, oil: int, iron: int, geo: int, food: int, fp: Vector2i, prod: String, btime: float, hq: bool) -> void:
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
	register_building(b)
