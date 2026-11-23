# scripts/core/damage.gd
class_name Damage
extends RefCounted

# Damage types
enum DamageType { KINETIC, EXPLOSIVE, ENERGY, EMP, THERMAL, TOXIC }

# Armor classes
enum ArmorClass { UNARMORED, LIGHT, MEDIUM, HEAVY, STRUCTURE, NAVAL, AIR, SUBMERGED }

# Multiplier matrix: damage_type -> armor_class -> float
const MULTIPLIERS := {
	DamageType.KINETIC: {
		ArmorClass.UNARMORED: 1.2, ArmorClass.LIGHT: 1.0, ArmorClass.MEDIUM: 0.8,
		ArmorClass.HEAVY: 0.5, ArmorClass.STRUCTURE: 0.6, ArmorClass.NAVAL: 0.7,
		ArmorClass.AIR: 0.3, ArmorClass.SUBMERGED: 0.0,
	},
	DamageType.EXPLOSIVE: {
		ArmorClass.UNARMORED: 1.5, ArmorClass.LIGHT: 1.2, ArmorClass.MEDIUM: 1.0,
		ArmorClass.HEAVY: 0.8, ArmorClass.STRUCTURE: 1.3, ArmorClass.NAVAL: 1.1,
		ArmorClass.AIR: 0.6, ArmorClass.SUBMERGED: 0.2,
	},
	DamageType.ENERGY: {
		ArmorClass.UNARMORED: 1.0, ArmorClass.LIGHT: 1.0, ArmorClass.MEDIUM: 1.0,
		ArmorClass.HEAVY: 1.0, ArmorClass.STRUCTURE: 1.2, ArmorClass.NAVAL: 1.0,
		ArmorClass.AIR: 1.0, ArmorClass.SUBMERGED: 0.5,
	},
	DamageType.EMP: {
		ArmorClass.UNARMORED: 1.5, ArmorClass.LIGHT: 1.2, ArmorClass.MEDIUM: 0.9,
		ArmorClass.HEAVY: 0.5, ArmorClass.STRUCTURE: 0.3, ArmorClass.NAVAL: 0.8,
		ArmorClass.AIR: 1.0, ArmorClass.SUBMERGED: 0.6,
	},
	DamageType.THERMAL: {
		ArmorClass.UNARMORED: 1.3, ArmorClass.LIGHT: 1.1, ArmorClass.MEDIUM: 0.9,
		ArmorClass.HEAVY: 0.7, ArmorClass.STRUCTURE: 1.0, ArmorClass.NAVAL: 1.0,
		ArmorClass.AIR: 0.8, ArmorClass.SUBMERGED: 0.4,
	},
	DamageType.TOXIC: {
		ArmorClass.UNARMORED: 1.4, ArmorClass.LIGHT: 1.0, ArmorClass.MEDIUM: 0.6,
		ArmorClass.HEAVY: 0.3, ArmorClass.STRUCTURE: 0.2, ArmorClass.NAVAL: 0.5,
		ArmorClass.AIR: 0.9, ArmorClass.SUBMERGED: 0.7,
	},
}

static func multiplier(damage_type: DamageType, armor_class: ArmorClass) -> float:
	var row: Dictionary = MULTIPLIERS.get(damage_type, {})
	return float(row.get(armor_class, 1.0))

static func compute(base_damage: float, damage_type: DamageType, armor_class: ArmorClass, armor_reduction: float = 0.0, cover_modifier: float = 1.0) -> float:
	var m := multiplier(damage_type, armor_class)
	var dmg := base_damage * m * (1.0 - clampf(armor_reduction, 0.0, 0.95)) * cover_modifier
	return maxf(dmg, 0.0)

static func is_effective(damage_type: DamageType, armor_class: ArmorClass) -> bool:
	return multiplier(damage_type, armor_class) >= 1.0
