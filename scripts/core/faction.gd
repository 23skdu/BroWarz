# scripts/core/faction.gd
class_name Faction
extends RefCounted

enum Id { AERODYNE, FERROCORE, PELAGIC, VANGUARD, VESPER, THALASSA, GRAVEBOUND, LUMEN }

# Lore: the four corporations are the four weapons divisions of a single
# planetary megacorp ("Terran Herzog Heavy Industries" is the fictional
# holding name). The RTS game is the means by which they settle resource
# dividing on the planet — division borders are drawn by match results.
# IDs 4-7 are AI-only factions (exiled fleets, cults and resurrected armies);
# they are appended after the serialized corporation IDs and never replace
# them.

# Unit classes used by the combat helpers below.
const SEA_CLASSES: Array[int] = [2, 4, 5]       # naval, hover/amphibious, frogbot
const INFANTRY_CLASSES: Array[int] = [0, 6]     # infantry, heavy infantry
const VEHICLE_CLASSES: Array[int] = [1, 7]      # vehicle, mech
const AIR_CLASSES: Array[int] = [3]

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

## Accessible faction color for the selected colorblind palette. Palettes
## shift the red/green (or blue/yellow) axis while keeping each division's
## brightness distinct; chess black/white mirror variants stay unchanged.
## The AI-only factions get hand-tuned alternatives so magenta, blue, olive
## and gold remain separable without relying on a red/green difference.
static func colorblind_color_of(id: int, palette: String = "none", variant: int = 0) -> Color:
	var c := color_of(id, variant)
	if variant != 0:
		return c
	match id:
		Id.VESPER:
			match palette:
				"deuteranopia", "protanopia":
					return Color(0.52, 0.34, 0.98, 1.0)
				"tritanopia":
					return Color(1.0, 0.36, 0.74, 1.0)
				_:
					return c
		Id.THALASSA:
			match palette:
				"deuteranopia", "protanopia":
					return Color(0.18, 0.38, 0.98, 1.0)
				"tritanopia":
					return Color(0.24, 0.62, 1.0, 1.0)
				_:
					return c
		Id.GRAVEBOUND:
			match palette:
				"deuteranopia", "protanopia":
					return Color(0.78, 0.76, 0.22, 1.0)
				"tritanopia":
					return Color(0.62, 0.82, 0.18, 1.0)
				_:
					return c
		Id.LUMEN:
			match palette:
				"deuteranopia", "protanopia":
					return Color(1.0, 0.92, 0.30, 1.0)
				"tritanopia":
					return Color(0.98, 0.80, 0.42, 1.0)
				_:
					return c
	match palette:
		"deuteranopia", "protanopia":
			var luma := 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			return Color(clampf(luma * 0.95, 0.0, 1.0), clampf(luma * 1.05, 0.0, 1.0), clampf(c.b * 0.6 + 0.4, 0.0, 1.0), 1.0)
		"tritanopia":
			return Color(clampf(c.r * 0.6 + 0.4, 0.0, 1.0), clampf(c.g * 0.6 + 0.4, 0.0, 1.0), clampf(c.b * 0.5, 0.0, 1.0), 1.0)
		_:
			return c

static func _base_color(id: int) -> Color:
	match id:
		Id.AERODYNE: return Color(0.25, 0.75, 1.0)   # sky blue
		Id.FERROCORE: return Color(1.0, 0.55, 0.15)  # amber
		Id.PELAGIC: return Color(0.15, 0.8, 0.75)    # teal
		Id.VANGUARD: return Color(0.75, 0.35, 0.95)  # violet
		Id.VESPER: return Color(1.0, 79.0 / 255.0, 216.0 / 255.0)   # #FF4FD8
		Id.THALASSA: return Color(47.0 / 255.0, 123.0 / 255.0, 1.0)  # #2F7BFF
		Id.GRAVEBOUND: return Color(143.0 / 255.0, 191.0 / 255.0, 63.0 / 255.0)  # #8FBF3F
		Id.LUMEN: return Color(242.0 / 255.0, 214.0 / 255.0, 91.0 / 255.0)  # #F2D65B
	return Color(0.8, 0.8, 0.8)

# Resolve a corporation identity for a team; two teams sharing the same
# corporation get the second a black-or-white variant so players can tell
# them apart in a self-versus-self scenario (like chess colors).
static func color_for_team(_faction_id: int, teams_sharing: int) -> int:
	return 2 if teams_sharing > 0 else 0

static func name_of(id: int) -> String:
	match id:
		Id.AERODYNE: return "AeroDyne Industries"
		Id.FERROCORE: return "FerroCore Heavy"
		Id.PELAGIC: return "Pelagic Systems"
		Id.VANGUARD: return "Vanguard Robotics"
		Id.VESPER: return "Vesper Ascendancy"
		Id.THALASSA: return "Thalassa Dominion"
		Id.GRAVEBOUND: return "Gravebound Legion"
		Id.LUMEN: return "Lumen Cabal"
	return "Unknown"


static func accent_of(id: int) -> Color:
	match id:
		Id.AERODYNE: return Color(0.82, 0.97, 1.0)   # stratospheric ice cyan
		Id.FERROCORE: return Color(1.0, 0.88, 0.28)  # forge gold
		Id.PELAGIC: return Color(0.55, 1.0, 0.88)    # bioluminescent aqua
		Id.VANGUARD: return Color(0.58, 1.0, 0.32)   # covert neon lime
		Id.VESPER: return Color(199.0 / 255.0, 1.0, 79.0 / 255.0)  # #C7FF4F
		Id.THALASSA: return Color(100.0 / 255.0, 1.0, 224.0 / 255.0)  # #64FFE0
		Id.GRAVEBOUND: return Color(216.0 / 255.0, 201.0 / 255.0, 163.0 / 255.0)  # #D8C9A3
		Id.LUMEN: return Color(155.0 / 255.0, 123.0 / 255.0, 1.0)  # #9B7BFF
	return Color(1.0, 1.0, 1.0)

static func motto_of(id: int) -> String:
	match id:
		Id.AERODYNE: return "Dominion of the Skies"
		Id.FERROCORE: return "Iron Will, Iron Fist"
		Id.PELAGIC: return "Depths of Power"
		Id.VANGUARD: return "Unseen, Unstoppable"
		Id.VESPER: return "Dominion begins above."
		Id.THALASSA: return "The sea remembers its masters."
		Id.GRAVEBOUND: return "The fallen still march."
		Id.LUMEN: return "We saw you coming."
	return ""

static func background_of(id: int) -> String:
	match id:
		Id.AERODYNE: return "An aerospace megacorp dominating orbital and aerial warfare."
		Id.FERROCORE: return "A heavy-industry giant specializing in armor and siege."
		Id.PELAGIC: return "A naval conglomerate ruling the seas and depths."
		Id.VANGUARD: return "A stealth and infantry specialist of covert operations."
		Id.VESPER: return "An exiled hive-mind fleet that rules the stratosphere with UFO craft."
		Id.THALASSA: return "Undersea city-states that command the oceans and abyssal trenches."
		Id.GRAVEBOUND: return "A resurrected industrial army whose ranks do not tire and whose losses return to the field."
		Id.LUMEN: return "A secretive cartel of seers and operatives that wins through foresight, reconnaissance and influence."
	return ""

## Stable id sets. Human seats (skirmish, co-op human seat, editor test play)
## only ever use 0-3; AI opponents and spectator sides may use 0-7.
static func all_ids() -> Array[int]:
	return [Id.AERODYNE, Id.FERROCORE, Id.PELAGIC, Id.VANGUARD,
		Id.VESPER, Id.THALASSA, Id.GRAVEBOUND, Id.LUMEN]

static func human_ids() -> Array[int]:
	return [Id.AERODYNE, Id.FERROCORE, Id.PELAGIC, Id.VANGUARD]

static func ai_ids() -> Array[int]:
	return all_ids()

static func npc_ids() -> Array[int]:
	return [Id.VESPER, Id.THALASSA, Id.GRAVEBOUND, Id.LUMEN]

static func is_npc(faction: int) -> bool:
	return faction in npc_ids()

static func theme_key(faction: int) -> String:
	match faction:
		Id.AERODYNE: return "aerodyne"
		Id.FERROCORE: return "ferrocore"
		Id.PELAGIC: return "pelagic"
		Id.VANGUARD: return "vanguard"
		Id.VESPER: return "vesper"
		Id.THALASSA: return "thalassa"
		Id.GRAVEBOUND: return "gravebound"
		Id.LUMEN: return "lumen"
	return ""

static func banner_path(faction: int) -> String:
	var key := theme_key(faction)
	if key == "":
		return ""
	return "res://assets/banners/%s.png" % key

static func logo_path(faction: int) -> String:
	return banner_path(faction)

## Short player-facing summary used by menus, faction cards and docs.
static func pros_cons(faction: int) -> Dictionary:
	match faction:
		Id.AERODYNE:
			return {
				"pros": ["-10% air unit cost", "Orbital laser cooldown -15%"],
				"cons": ["No ground or naval bonus"],
			}
		Id.FERROCORE:
			return {
				"pros": ["+10% tank HP", "+25% sapper speed"],
				"cons": ["No air or naval bonus"],
			}
		Id.PELAGIC:
			return {
				"pros": ["Submarines cloak", "-10% sea unit cost"],
				"cons": ["No land firepower bonus"],
			}
		Id.VANGUARD:
			return {
				"pros": ["+20% stealth duration", "-10% mech/infantry cost"],
				"cons": ["No direct firepower bonus"],
			}
		Id.VESPER:
			return {
				"pros": ["+20% air damage", "+30% air speed"],
				"cons": ["-20% ground/vehicle HP"],
			}
		Id.THALASSA:
			return {
				"pros": ["+25% naval HP", "+15% naval damage", "-10% sea unit cost"],
				"cons": ["-15% land and air damage"],
			}
		Id.GRAVEBOUND:
			return {
				"pros": ["+20% infantry HP", "-15% infantry cost"],
				"cons": ["-15% sight", "-20% vehicle/air HP"],
			}
		Id.LUMEN:
			return {
				"pros": ["+25% sight", "+30% stealth duration"],
				"cons": ["+10% all unit costs", "-10% all unit HP"],
			}
	return {"pros": [], "cons": []}

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
		Id.VESPER:
			return {
				"air_damage": 1.2, "air_speed": 1.3, "ground_hp": 0.8,
				"description": "Stratospheric raiders: fast, lethal air wings over fragile ground hulls.",
			}
		Id.THALASSA:
			return {
				"naval_hp": 1.25, "naval_damage": 1.15, "sea_cost": 0.9,
				"land_air_damage": 0.85,
				"description": "Ocean sovereigns: heavily armed fleets, weaker expeditionary forces.",
			}
		Id.GRAVEBOUND:
			return {
				"infantry_hp": 1.2, "infantry_cost": 0.85, "sight": 0.85,
				"vehicle_air_hp": 0.8,
				"description": "Endless resurrected ranks; poor eyesight and brittle machines.",
			}
		Id.LUMEN:
			return {
				"sight": 1.25, "stealth_duration": 1.3, "all_cost": 1.1,
				"all_hp": 0.9,
				"description": "Foresight and reconnaissance bought with expensive, fragile units.",
			}
	return {}

# --- Generic combat modifiers ---------------------------------------------
# Factions 0-3 deliberately keep their original narrow bonuses (their helpers
# return 1.0 for any bonus they never had). Factions 4-7 use unit classes so
# the same hooks work for every unit without special-casing ids in combat.

static func damage_multiplier(faction: int, unit_id: String, unit_class: int = -1) -> float:
	match faction:
		Id.VESPER:
			return 1.2 if _is_air(unit_id, unit_class) else 1.0
		Id.THALASSA:
			return 1.15 if _is_sea(unit_id, unit_class) else 0.85
	return 1.0

static func max_hp_multiplier(faction: int, unit_id: String, unit_class: int = -1) -> float:
	if faction == Id.FERROCORE and unit_id in ["light_tank", "mbt", "heavy_tank"]:
		return float(modifiers(Id.FERROCORE)["tank_hp"])
	var cls := _effective_class(unit_id, unit_class)
	match faction:
		Id.VESPER:
			return 0.8 if cls >= 0 and not _is_air(unit_id, cls) else 1.0
		Id.THALASSA:
			return 1.25 if _is_sea(unit_id, cls) else 1.0
		Id.GRAVEBOUND:
			if cls in INFANTRY_CLASSES:
				return 1.2
			if cls in VEHICLE_CLASSES or _is_air(unit_id, cls):
				return 0.8
			return 1.0
		Id.LUMEN:
			return 0.9
	return 1.0

static func speed_multiplier(faction: int, unit_id: String, unit_class: int = -1) -> float:
	if faction == Id.FERROCORE and unit_id in ["sapperbot", "engineerbot", "adv_engineerbot"]:
		return float(modifiers(Id.FERROCORE)["sapper_speed"])
	if faction == Id.VESPER and _is_air(unit_id, unit_class):
		return 1.3
	return 1.0

static func sight_multiplier(faction: int, _unit_id: String = "", _unit_class: int = -1) -> float:
	# _unit_id/_unit_class are accepted for a uniform call signature; both
	# current sight bonuses apply to every unit in the faction.
	match faction:
		Id.GRAVEBOUND: return 0.85
		Id.LUMEN: return 1.25
	return 1.0

## Class lookup for callers that only have an id (legacy helpers). New code
## passes the authoritative UnitStats.unit_class instead.
const UNIT_CLASS_BY_ID := {
	"riflebot": 0, "stealthbot": 0, "sniperbot": 0, "rocketbot": 0,
	"sapperbot": 0, "engineerbot": 0, "adv_engineerbot": 0, "medicbot": 0,
	"bone_legionary": 0, "ghoul_stalker": 0, "lumen_operative": 0,
	"heavybot": 6,
	"apc": 1, "light_mech": 1, "light_tank": 1, "mbt": 1, "heavy_tank": 1,
	"artillery": 1, "aa_vehicle": 1, "lumen_enforcer": 1,
	"heavy_mech": 7, "siege_mech": 7, "lichen_colossus": 7,
	"patrol_boat": 2, "corvette": 2, "attack_sub": 2, "ballistic_sub": 2,
	"landing_craft": 2, "cruiser": 2, "battleship": 2, "aircraft_carrier": 2,
	"abyssal_trireme": 2, "leviathan_carrier": 2, "nereid_raider": 2,
	"hovercraft": 4,
	"frogbot": 5,
	"scout_drone": 3, "fighter_drone": 3, "bomber_drone": 3, "awacs": 3,
	"ufo_wisp": 3, "ufo_talon": 3, "ufo_nova": 3, "lumen_oracle": 3,
}

static func unit_class_for_id(unit_id: String) -> int:
	return int(UNIT_CLASS_BY_ID.get(unit_id, -1))

static func _effective_class(unit_id: String, unit_class: int) -> int:
	return unit_class if unit_class >= 0 else unit_class_for_id(unit_id)

static func _is_air(unit_id: String, unit_class: int) -> bool:
	return _effective_class(unit_id, unit_class) in AIR_CLASSES

static func _is_sea(unit_id: String, unit_class: int) -> bool:
	return _effective_class(unit_id, unit_class) in SEA_CLASSES

static func effective_max_hp(faction_id: int, unit_id: String, base_hp: int, unit_class: int = -1) -> int:
	return int(round(float(base_hp) * max_hp_multiplier(faction_id, unit_id, unit_class)))

static func effective_speed(faction_id: int, unit_id: String, base_speed: float, unit_class: int = -1) -> float:
	return base_speed * speed_multiplier(faction_id, unit_id, unit_class)

static func effective_cloak_duration(faction_id: int, base_duration: float = 10.0) -> float:
	var mods := modifiers(faction_id)
	return Stealth.cloak_duration(base_duration, float(mods.get("stealth_duration", 1.0)))

static func effective_unit_cost(faction_id: int, unit_stats: UnitStats) -> Dictionary:
	var cost := unit_stats.cost_dict()
	var mods := modifiers(faction_id)
	var cls := _effective_class(unit_stats.id, unit_stats.unit_class)
	var mult := 1.0
	if cls == 3 and mods.has("air_cost"):
		mult = float(mods["air_cost"])
	elif cls in SEA_CLASSES and mods.has("sea_cost"):
		mult = float(mods["sea_cost"])
	elif (cls in INFANTRY_CLASSES or cls in VEHICLE_CLASSES or unit_stats.id == "light_mech") and mods.has("mech_cost"):
		# Original Vanguard "mech cost" also covered infantry (and light_mech
		# despite its recorded vehicle class); keep that exact behavior.
		mult = float(mods["mech_cost"])
	elif cls in INFANTRY_CLASSES and mods.has("infantry_cost"):
		mult = float(mods["infantry_cost"])
	elif mods.has("all_cost"):
		mult = float(mods["all_cost"])
	if mult != 1.0:
		for k in cost.keys():
			cost[k] = int(round(float(cost[k]) * mult))
	return cost
