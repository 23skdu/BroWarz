# scripts/core/strategic.gd
class_name Strategic
extends RefCounted

static func nuke_fallout_radius(base_radius: int, yield_mult: float = 1.0) -> int:
	return int(round(base_radius * yield_mult))

static func orbital_laser_damage(base: float, geothermal: float) -> float:
	# more geothermal -> stronger beam
	return base * (1.0 + geothermal / 1000.0)

static func creates_fallout(weapon: String) -> bool:
	return weapon == "nuke"
