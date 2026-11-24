# scripts/core/faction.gd
class_name Faction
extends RefCounted

enum Id { AERODYNE, FERROCORE, PELAGIC, VANGUARD }

# Lore: the four corporations are the four weapons divisions of a single
# planetary megacorp ("Terran Herzog Heavy Industries" is the fictional
# holding name). The RTS game is the means by which they settle resource
# dividimg on the planet — division borders are drawn by match results.

# For when two players (teams) run the *same* corporation against each
# other in a self-vs-self scenario, they settle dividing resources chess-
# style: the first team keeps the corporation's base color, the second
# plays the opponent's black-and-white variant (chess black = off-base).
static func color_of(id: int, variant: int = 0) -> Color:
	var c := _base_color(id)
	if variant == 1:
		return Color(0.08, 0.08, 0.10, 1.0)  # chess black
	if variant == 2:
		return Color(0.97, 0.97, 0.98, 1.0)  # chess white
	return c

static func _base_color(id: int) -> Color:
	match id:
		Id.AERODYNE: return Color(0.25, 0.75, 1.0)   # sky blue
		Id.FERROCORE: return Color(1.0, 0.55, 0.15)  # amber
		Id.PELAGIC: return Color(0.15, 0.8, 0.75)    # teal
		Id.VANGUARD: return Color(0.75, 0.35, 0.95)  # violet
	return Color(0.8, 0.8, 0.8)

# Resolve a corporation identity for a team; two teams sharing the same
# corporation get the second a black-or-white variant so players can tell
# them apart in a self-versus-self scenario (like chess colors).
static func color_for_team(faction_id: int, teams_sharing: int) -> int:
	return 2 if teams_sharing > 0 else 0

static func name_of(id: int) -> String:
	match id:
		Id.AERODYNE: return "AeroDyne Industries"
		Id.FERROCORE: return "FerroCore Heavy"
		Id.PELAGIC: return "Pelagic Systems"
		Id.VANGUARD: return "Vanguard Robotics"
	return "Unknown"


static func accent_of(id: int) -> Color:
	match id:
		Id.AERODYNE: return Color(0.82, 0.97, 1.0)   # stratospheric ice cyan
		Id.FERROCORE: return Color(1.0, 0.88, 0.28)  # forge gold
		Id.PELAGIC: return Color(0.55, 1.0, 0.88)    # bioluminescent aqua
		Id.VANGUARD: return Color(0.58, 1.0, 0.32)   # covert neon lime
	return Color(1.0, 1.0, 1.0)

static func motto_of(id: int) -> String:
	match id:
		Id.AERODYNE: return "Dominion of the Skies"
		Id.FERROCORE: return "Iron Will, Iron Fist"
		Id.PELAGIC: return "Depths of Power"
		Id.VANGUARD: return "Unseen, Unstoppable"
	return ""

static func background_of(id: int) -> String:
	match id:
		Id.AERODYNE: return "An aerospace megacorp dominating orbital and aerial warfare."
		Id.FERROCORE: return "A heavy-industry giant specializing in armor and siege."
		Id.PELAGIC: return "A naval conglomerate ruling the seas and depths."
		Id.VANGUARD: return "A stealth and infantry specialist of covert operations."
	return ""

# Returns numeric modifiers for a faction.
static func modifiers(id: int) -> Dictionary:
	match id:
		Id.AERODYNE:
			return {"air_cost": 0.9, "orbital_cooldown": 0.85}
		Id.FERROCORE:
			return {"tank_hp": 1.1, "sapper_speed": 1.25}
		Id.PELAGIC:
			return {"sub_cloak": true, "sea_cost": 0.9}
		Id.VANGUARD:
			return {"stealth_duration": 1.2, "mech_cost": 0.9}
	return {}

static func effective_max_hp(faction_id: int, unit_id: String, base_hp: int) -> int:
	var mods := modifiers(faction_id)
	if mods.has("tank_hp") and unit_id in ["light_tank", "mbt", "heavy_tank"]:
		return int(round(float(base_hp) * float(mods["tank_hp"])))
	return base_hp

static func effective_speed(faction_id: int, unit_id: String, base_speed: float) -> float:
	var mods := modifiers(faction_id)
	if mods.has("sapper_speed") and unit_id in ["sapperbot", "engineerbot", "adv_engineerbot"]:
		return base_speed * float(mods["sapper_speed"])
	return base_speed

static func effective_cloak_duration(faction_id: int, base_duration: float = 10.0) -> float:
	var mods := modifiers(faction_id)
	return Stealth.cloak_duration(base_duration, float(mods.get("stealth_duration", 1.0)))

static func effective_unit_cost(faction_id: int, unit_stats: UnitStats) -> Dictionary:
	var cost := unit_stats.cost_dict()
	var mods := modifiers(faction_id)
	var mult := 1.0
	if unit_stats.unit_class == 3 and mods.has("air_cost"):
		mult = float(mods["air_cost"])
	elif (unit_stats.unit_class == 2 or unit_stats.unit_class == 4 or unit_stats.unit_class == 5) and mods.has("sea_cost"):
		mult = float(mods["sea_cost"])
	elif (unit_stats.unit_class == 0 or unit_stats.unit_class == 6 or unit_stats.unit_class == 7 or unit_stats.id == "light_mech") and mods.has("mech_cost"):
		mult = float(mods["mech_cost"])
	if mult != 1.0:
		for k in cost.keys():
			cost[k] = int(round(float(cost[k]) * mult))
	return cost
