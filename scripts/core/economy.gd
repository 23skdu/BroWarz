# scripts/core/economy.gd
class_name Economy
extends RefCounted

# Resource types
enum Res { OIL, IRON, GEOTHERMAL, FOOD }

static func empty_wallet() -> Dictionary:
	return {Res.OIL: 0, Res.IRON: 0, Res.GEOTHERMAL: 0, Res.FOOD: 0}

static func can_afford(wallet: Dictionary, cost: Dictionary) -> bool:
	for k in cost.keys():
		if int(wallet.get(k, 0)) < int(cost.get(k, 0)):
			return false
	return true

static func spend(wallet: Dictionary, cost: Dictionary) -> bool:
	if not can_afford(wallet, cost):
		return false
	for k in cost.keys():
		wallet[k] = int(wallet.get(k, 0)) - int(cost.get(k, 0))
	return true

static func grant(wallet: Dictionary, income: Dictionary) -> void:
	for k in income.keys():
		wallet[k] = int(wallet.get(k, 0)) + int(income.get(k, 0))

static func apply_income(wallet: Dictionary, rates: Dictionary, delta_seconds: float) -> Dictionary:
	# returns amount added this tick
	var added := empty_wallet()
	for k in rates.keys():
		var amt := int(floor(float(rates.get(k, 0)) * delta_seconds))
		added[k] = amt
		wallet[k] = int(wallet.get(k, 0)) + amt
	return added

static func population_cap(base: int, farms: int, farm_cap: int = 5) -> int:
	return base + farms * farm_cap

static func within_pop_cap(current: int, cap: int) -> bool:
	return current <= cap
