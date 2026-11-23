# scripts/core/unit_stats.gd
class_name UnitStats
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var hp: int = 100
@export var speed: float = 100.0
@export var armor_class: int = 0 # Damage.ArmorClass
@export var damage_type: int = 0 # Damage.DamageType
@export var base_damage: int = 10
@export var range_px: float = 200.0
@export var sight: float = 300.0
@export var cost_oil: int = 0
@export var cost_iron: int = 0
@export var cost_geo: int = 0
@export var cost_food: int = 0
@export var build_time: float = 5.0
@export var unit_class: int = 0 # 0 infantry 1 vehicle 2 naval 3 air
@export var stealth: bool = false
@export var can_build: bool = false

func cost_dict() -> Dictionary:
	return {"oil": cost_oil, "iron": cost_iron, "geo": cost_geo, "food": cost_food}
