# scripts/core/building_stats.gd
class_name BuildingStats
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var hp: int = 500
@export var cost_oil: int = 0
@export var cost_iron: int = 0
@export var cost_geo: int = 0
@export var cost_food: int = 0
@export var footprint: Vector2i = Vector2i(2, 2)
@export var produces: String = ""  # unit id
@export var build_time: float = 10.0
@export var is_hq: bool = false

func cost_dict() -> Dictionary:
	return {"oil": cost_oil, "iron": cost_iron, "geo": cost_geo, "food": cost_food}
