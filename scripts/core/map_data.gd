# scripts/core/map_data.gd
class_name MapData
extends Resource

enum Terrain { PLAINS, FOREST, SWAMP, RIVER, SEA, MOUNTAIN, URBAN, ROAD, BRIDGE, WASTELAND }

@export var width: int = 128
@export var height: int = 128
@export var tiles: PackedByteArray = PackedByteArray()
@export var name: String = "Untitled"
@export var author: String = "Unknown"

func _init(w: int = 128, h: int = 128) -> void:
	width = w
	height = h
	tiles.resize(w * h)
	for i in range(tiles.size()):
		tiles[i] = Terrain.PLAINS

func index(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= width or y >= height:
		return -1
	return y * width + x

func get_terrain(x: int, y: int) -> int:
	var i := index(x, y)
	if i < 0:
		return -1
	return tiles[i]

func set_terrain(x: int, y: int, t: int) -> bool:
	var i := index(x, y)
	if i < 0:
		return false
	tiles[i] = t
	return true

func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < width and y < height

func tile_count() -> int:
	return width * height

static func movement_cost(terrain: int, unit_class: int) -> float:
	# unit_class: 0 infantry, 1 vehicle, 2 naval, 3 air
	match unit_class:
		3: # air
			return 1.0
		2: # naval
			if terrain == Terrain.SEA or terrain == Terrain.RIVER:
				return 1.0
			return INF
		1: # vehicle
			match terrain:
				Terrain.PLAINS, Terrain.ROAD: return 1.0
				Terrain.URBAN: return 1.3
				Terrain.FOREST: return 1.6
				Terrain.SWAMP: return INF
				Terrain.RIVER, Terrain.SEA, Terrain.MOUNTAIN, Terrain.WASTELAND: return INF
				_: return 1.2
		_: # infantry
			match terrain:
				Terrain.PLAINS, Terrain.ROAD: return 1.0
				Terrain.URBAN: return 0.9
				Terrain.FOREST: return 1.2
				Terrain.SWAMP: return 1.6
				Terrain.RIVER, Terrain.SEA, Terrain.MOUNTAIN: return INF
				Terrain.WASTELAND: return 1.4
				_: return 1.1
	return 1.0

static func is_passable(terrain: int, unit_class: int) -> bool:
	return movement_cost(terrain, unit_class) < INF
