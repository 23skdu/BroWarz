# scripts/core/resource_deposit.gd
class_name ResourceDeposit
extends RefCounted

var type: int = 0  # Economy.Res
var amount: int = 1000
var harvest_rate: float = 10.0

func harvest(delta: float) -> int:
	var amt = int(harvest_rate * delta)
	if amt > amount:
		amt = amount
	amount -= amt
	if amount < 0:
		amount = 0
	return amt

func is_depleted() -> bool:
	return amount <= 0
