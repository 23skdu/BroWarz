# scripts/core/stealth.gd
class_name Stealth
extends RefCounted

static func break_on_action(attacking: bool, moving: bool, unit_breaks_on_move: bool) -> bool:
	if attacking:
		return true
	if moving and unit_breaks_on_move:
		return true
	return false

static func cloak_duration(base: float, faction_mult: float = 1.0) -> float:
	return base * faction_mult

static func is_cloaked(timer: float) -> bool:
	return timer > 0.0
