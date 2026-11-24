# scripts/core/cover.gd
class_name Cover
extends RefCounted

static func modifier(terrain: int) -> float:
	match terrain:
		MapData.Terrain.URBAN: return 0.7
		MapData.Terrain.FOREST: return 0.8
		MapData.Terrain.HILLS: return 0.85
		_: return 1.0

static func provides_cover(terrain: int) -> bool:
	return terrain == MapData.Terrain.URBAN or terrain == MapData.Terrain.FOREST or terrain == MapData.Terrain.HILLS
