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
