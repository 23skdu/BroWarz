# scripts/core/unit_registry.gd
class_name UnitRegistry
extends RefCounted

var units: Dictionary = {}  # id -> UnitStats
var buildings: Dictionary = {}  # id -> BuildingStats

func register_unit(s: UnitStats) -> void:
	units[s.id] = s

func register_building(s: BuildingStats) -> void:
	buildings[s.id] = s

func get_unit(id: String) -> UnitStats:
	return units.get(id, null)

func get_building(id: String) -> BuildingStats:
	return buildings.get(id, null)

func has_unit(id: String) -> bool:
	return units.has(id)

func has_building(id: String) -> bool:
	return buildings.has(id)
