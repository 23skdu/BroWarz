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
	# unit_class: 0 infantry, 1 vehicle, 2 naval, 3 air, 4 hovercraft, 5 amphibious (frogbots), 6 heavy infantry, 7 heavy/siege mech
	# Ground/sea terrain does NOT affect air units (class 3); only drifting clouds affect aerial units.
	match unit_class:
		3: # air (unaffected by ground terrain; only affected by clouds)
			return 1.0
		2: # naval
			match terrain:
				Terrain.SEA: return 0.95
				Terrain.RIVER: return 1.10
				Terrain.BRIDGE: return 1.15
				_: return INF
		1, 7: # vehicle (1) or heavy mech (7)
			match terrain:
				Terrain.ROAD, Terrain.BRIDGE: return 0.80
				Terrain.PLAINS: return 1.00
				Terrain.DESERT: return 1.15
				Terrain.URBAN: return 1.30
				Terrain.HILLS: return 1.45
				Terrain.FOREST: return 1.60
				Terrain.SWAMP:
					if heavy or unit_class == 7:
						return 1.85
					return INF
				Terrain.RIVER, Terrain.SEA: return INF
				Terrain.WASTELAND:
					if heavy or unit_class == 7:
						return 1.75
					return INF
				Terrain.MOUNTAIN:
					if heavy or unit_class == 7:
						return 2.20
					return INF
				_: return 1.20
		4: # hovercraft (land + sea)
			match terrain:
				Terrain.MOUNTAIN, Terrain.WASTELAND: return INF
				Terrain.ROAD, Terrain.BRIDGE: return 0.85
				Terrain.PLAINS, Terrain.DESERT: return 1.00
				Terrain.RIVER: return 1.05
				Terrain.SEA: return 1.10
				Terrain.URBAN: return 1.20
				Terrain.SWAMP, Terrain.FOREST: return 1.30
				Terrain.HILLS: return 1.40
				_: return 1.00
		5: # amphibious (frogbots): land + water, faster in water
			match terrain:
				Terrain.MOUNTAIN, Terrain.WASTELAND: return INF
				Terrain.SEA: return 0.90
				Terrain.RIVER: return 0.95
				Terrain.BRIDGE, Terrain.URBAN: return 1.10
				Terrain.ROAD: return 1.05
				Terrain.PLAINS, Terrain.DESERT: return 1.20
				Terrain.HILLS: return 1.35
				Terrain.FOREST: return 1.40
				Terrain.SWAMP: return 1.25
				_: return 1.25
		_: # infantry (0) or heavy infantry (6)
			match terrain:
				Terrain.ROAD, Terrain.BRIDGE: return 0.85
				Terrain.URBAN: return 0.90
				Terrain.PLAINS: return 1.00
				Terrain.DESERT: return 1.15
				Terrain.FOREST: return 1.20
				Terrain.HILLS: return 1.30
				Terrain.WASTELAND: return 1.40
				Terrain.SWAMP: return 1.60
				Terrain.RIVER, Terrain.SEA: return INF
				Terrain.MOUNTAIN:
					if heavy or unit_class == 6:
						return 2.00
					return INF
				_: return 1.10

static func speed_multiplier(terrain: int, unit_class: int, heavy: bool = false, in_cloud: bool = false) -> float:
	# Air units ignore ground terrain completely and are only affected by clouds.
	if unit_class == 3:
		return Cover.cloud_air_speed_multiplier(in_cloud)
	var cost := movement_cost(terrain, unit_class, heavy)
	if cost >= INF or cost <= 0.0:
		return 0.45
	return clampf(1.0 / cost, 0.40, 1.35)

static func is_passable(terrain: int, unit_class: int, heavy: bool = false) -> bool:
	return movement_cost(terrain, unit_class, heavy) < INF
