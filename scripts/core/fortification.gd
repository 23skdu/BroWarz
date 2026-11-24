# scripts/core/fortification.gd
class_name Fortification
extends RefCounted

# Sapper-built defensive structures: movement-blocking rules and role tags.
# Kept pure so blocking behaviour is unit-testable without a scene tree.

const MISSILE_TOWER := "missile_tower"
const WALL := "wall"
const BARBED_WIRE := "barbed_wire"
const IDS: Array[String] = [MISSILE_TOWER, WALL, BARBED_WIRE]

# Block masks (bit flags stored per tile in GameManager.fort_blocks).
const BLOCK_INFANTRY: int = 1  # infantry (0) and heavy infantry (6)
const BLOCK_GROUND: int = 2  # all non-air, non-naval ground classes

static func is_fortification(id: String) -> bool:
	return id in IDS

## True when the structure participates in movement blocking at all.
static func blocks_movement(id: String) -> bool:
	return id == WALL or id == BARBED_WIRE

## Bit mask describing which unit classes a structure stops.
static func block_mask(id: String) -> int:
	match id:
		WALL:
			return BLOCK_INFANTRY | BLOCK_GROUND
		BARBED_WIRE:
			return BLOCK_INFANTRY
	return 0

## Can this structure stop a unit of `unit_class` on its tile?
## Air (3) and naval (2) units are never blocked by land fortifications.
static func blocks_unit(id: String, unit_class: int) -> bool:
	return mask_blocks_unit(block_mask(id), unit_class)

## Same check against an accumulated per-tile mask.
static func mask_blocks_unit(mask: int, unit_class: int) -> bool:
	if unit_class == 2 or unit_class == 3:
		return false
	return (mask & _class_bit(unit_class)) != 0

## Missile towers are the anti-air answer for static defense.
static func is_anti_air(id: String) -> bool:
	return id == MISSILE_TOWER

static func _class_bit(unit_class: int) -> int:
	if unit_class == 0 or unit_class == 6:
		return BLOCK_INFANTRY
	return BLOCK_GROUND
