# scripts/core/faction.gd
class_name Faction
extends RefCounted

enum Id { AERODYNE, FERROCORE, PELAGIC, VANGUARD }

static func name_of(id: int) -> String:
	match id:
		Id.AERODYNE: return "AeroDyne Industries"
		Id.FERROCORE: return "FerroCore Heavy"
		Id.PELAGIC: return "Pelagic Systems"
		Id.VANGUARD: return "Vanguard Robotics"
	return "Unknown"

static func color_of(id: int) -> Color:
	match id:
		Id.AERODYNE: return Color(0.25, 0.75, 1.0)   # sky blue
		Id.FERROCORE: return Color(1.0, 0.55, 0.15)  # amber
		Id.PELAGIC: return Color(0.15, 0.8, 0.75)    # teal
		Id.VANGUARD: return Color(0.75, 0.35, 0.95)  # violet
	return Color(0.8, 0.8, 0.8)

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
