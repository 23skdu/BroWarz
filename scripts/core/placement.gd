# scripts/core/placement.gd
class_name Placement
extends RefCounted

# Validate building placement on a map.
# occupied: Dictionary of Vector2i -> bool (tiles already occupied)
# Returns true if all footprint tiles are in bounds and free and terrain passable for building.

static func can_place(map: MapData, footprint: Vector2i, origin: Vector2i, occupied: Dictionary = {}) -> bool:
	if footprint.x <= 0 or footprint.y <= 0:
		return false
	for dy in range(footprint.y):
		for dx in range(footprint.x):
			var t = Vector2i(origin.x + dx, origin.y + dy)
			if not map.in_bounds(t.x, t.y):
				return false
			var terrain = map.get_terrain(t.x, t.y)
			# buildings cannot be placed on water/mountain/wasteland
			if terrain == MapData.Terrain.SEA or terrain == MapData.Terrain.RIVER or terrain == MapData.Terrain.MOUNTAIN or terrain == MapData.Terrain.WASTELAND:
				return false
			if occupied.get(t, false):
				return false
	return true

static func occupy(occupied: Dictionary, footprint: Vector2i, origin: Vector2i) -> void:
	for dy in range(footprint.y):
		for dx in range(footprint.x):
			occupied[Vector2i(origin.x + dx, origin.y + dy)] = true

static func free(occupied: Dictionary, footprint: Vector2i, origin: Vector2i) -> void:
	for dy in range(footprint.y):
		for dx in range(footprint.x):
			occupied.erase(Vector2i(origin.x + dx, origin.y + dy))
