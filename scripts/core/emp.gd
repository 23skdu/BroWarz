# scripts/core/emp.gd
class_name EMP
extends RefCounted

static func disable_duration(base: float, armor_class: int) -> float:
	# robots (unarmored/light) suffer longer
	if armor_class <= 1:
		return base * 1.5
	return base

static func is_disabled(timer: float) -> bool:
	return timer > 0.0

static func tick(timer: float, delta: float) -> float:
	return maxf(timer - delta, 0.0)
