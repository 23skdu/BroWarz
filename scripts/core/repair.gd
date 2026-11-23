# scripts/core/repair.gd
class_name Repair
extends RefCounted

static func repair_amount(rate: float, delta: float) -> float:
	return rate * delta

static func cost_for_amount(amount: float, cost_per_hp: float) -> int:
	return int(ceil(amount * cost_per_hp))

static func can_repair(current_hp: int, max_hp: int) -> bool:
	return current_hp < max_hp and current_hp > 0
