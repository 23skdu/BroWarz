# scripts/core/map_data.gd
class_name MapData
extends Resource

enum Terrain { PLAINS, FOREST, SWAMP, RIVER, SEA, MOUNTAIN, URBAN, ROAD, BRIDGE, WASTELAND, DESERT, HILLS }

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

static func terrain_name(t: int) -> String:
	match t:
		Terrain.PLAINS: return "Plains"
		Terrain.FOREST: return "Forest"
		Terrain.SWAMP: return "Swamp"
		Terrain.RIVER: return "Water (River)"
		Terrain.SEA: return "Water (Sea)"
		Terrain.MOUNTAIN: return "Mountain"
		Terrain.URBAN: return "Urban"
		Terrain.ROAD: return "Road"
		Terrain.BRIDGE: return "Bridge"
		Terrain.WASTELAND: return "Wasteland"
		Terrain.DESERT: return "Desert"
		Terrain.HILLS: return "Hills"
		_: return "Unknown"

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

static func movement_cost(terrain: int, unit_class: int, heavy: bool = false) -> float:
	# unit_class: 0 infantry, 1 vehicle, 2 naval, 3 air, 4 hovercraft, 5 amphibious (frogmen)
	# heavy: heavy infantry or large mechs that can cross mountains
	match unit_class:
		3: # air
			return 1.0
		2: # naval
			if terrain == Terrain.SEA or terrain == Terrain.RIVER:
				return 1.0
			return INF
		1, 7: # vehicle (1) or heavy mech (7)
			match terrain:
				Terrain.PLAINS, Terrain.ROAD, Terrain.BRIDGE: return 1.0
				Terrain.DESERT: return 1.15
				Terrain.HILLS: return 1.45
				Terrain.URBAN: return 1.3
				Terrain.FOREST: return 1.6
				Terrain.SWAMP: return INF
				Terrain.RIVER, Terrain.SEA, Terrain.WASTELAND: return INF
				Terrain.MOUNTAIN:
					if heavy or unit_class == 7:
						return 2.2
					return INF
				_: return 1.2
		4: # hovercraft (land + sea)
			match terrain:
				Terrain.MOUNTAIN, Terrain.WASTELAND: return INF
				Terrain.HILLS: return 1.4
				Terrain.DESERT: return 1.0
				Terrain.SWAMP: return 1.3
				Terrain.FOREST: return 1.3
				Terrain.RIVER, Terrain.SEA: return 1.1
				_: return 1.0
		5: # amphibious (frogbots): land + water, slower on land
			match terrain:
				Terrain.MOUNTAIN, Terrain.WASTELAND: return INF
				Terrain.PLAINS, Terrain.ROAD, Terrain.BRIDGE, Terrain.DESERT: return 1.2
				Terrain.HILLS: return 1.35
				Terrain.URBAN: return 1.1
				Terrain.FOREST: return 1.4
				Terrain.SWAMP: return 1.5
				Terrain.RIVER, Terrain.SEA: return 1.0
				_: return 1.3
		_: # infantry (0) or heavy infantry (6)
			match terrain:
				Terrain.PLAINS, Terrain.ROAD, Terrain.BRIDGE: return 1.0
				Terrain.DESERT: return 1.15
				Terrain.HILLS: return 1.3
				Terrain.URBAN: return 0.9
				Terrain.FOREST: return 1.2
				Terrain.SWAMP: return 1.6
				Terrain.RIVER, Terrain.SEA: return INF
				Terrain.MOUNTAIN:
					if heavy or unit_class == 6:
						return 2.0
					return INF
				Terrain.WASTELAND: return 1.4
				_: return 1.1

static func is_passable(terrain: int, unit_class: int, heavy: bool = false) -> bool:
	return movement_cost(terrain, unit_class, heavy) < INF
