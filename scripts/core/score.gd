# scripts/core/score.gd
class_name Score
extends RefCounted

static func military_score(units: int, buildings: int) -> int:
	return units * 10 + buildings * 50

static func economic_score(resources: int) -> int:
	return resources

static func total(mil: int, eco: int) -> int:
	return mil + eco
