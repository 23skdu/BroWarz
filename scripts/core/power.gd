# scripts/core/power.gd
class_name Power
extends RefCounted

static func balance(production: float, consumption: float) -> float:
	return production - consumption

static func is_powered(balance_val: float) -> bool:
	return balance_val >= 0.0

static func efficiency(balance_val: float) -> float:
	if balance_val >= 0.0:
		return 1.0
	# brownout: efficiency drops with deficit
	return clampf(1.0 + balance_val / 100.0, 0.3, 1.0)

static func building_power_delta(building_id: String) -> float:
	match building_id:
		"power_plant": return 40.0
		"hq": return 20.0
		"mech_factory_1", "barracks": return -10.0
		"mech_factory_2", "factory": return -15.0
		"mech_factory_3": return -25.0
		"docks": return -8.0
		"shipyard": return -15.0
		"advanced_shipyard": return -25.0
		"aeries_1", "airfield": return -12.0
		"aeries_2": return -20.0
		"radar", "research_lab": return -12.0
		"turret": return -6.0
		"missile_tower": return -8.0
		"silo", "orbital_uplink": return -25.0
		"extractor": return -5.0
	return 0.0

static func team_power_summary(building_ids: Array) -> Dictionary:
	var prod := 0.0
	var cons := 0.0
	for bid in building_ids:
		var d := building_power_delta(str(bid))
		if d >= 0.0:
			prod += d
		else:
			cons += -d
	var bal := balance(prod, cons)
	return {
		"production": prod,
		"consumption": cons,
		"balance": bal,
		"efficiency": efficiency(bal),
		"powered": is_powered(bal),
	}
