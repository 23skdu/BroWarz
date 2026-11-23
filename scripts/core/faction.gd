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
