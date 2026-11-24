# scripts/core/map_data.gd
class_name MapData
extends Resource

enum Terrain { PLAINS, FOREST, SWAMP, RIVER, SEA, MOUNTAIN, URBAN, ROAD, BRIDGE, WASTELAND, DESERT, HILLS }

@export var width: int = 128
@export var height: int = 128
@export var tiles: PackedByteArray = PackedByteArray()
@export var name: String = "Untitled"
@export var author: String = "Unknown"
# Map-editor metadata: HQ spawn points (one per team) and resource deposits.
# Stored as plain dictionaries so they round-trip through JSON share codes.
@export var hq_spawns: Array = []  # [{team:int, x:int, y:int}, ...]
@export var deposits: Array = []   # [{type:int, x:int, y:int, amount:int, rate:float}, ...]

const MAX_TEAMS: int = 4
const SPAWN_BALANCE_RADIUS: int = 20
const SPAWN_BALANCE_TOLERANCE: int = 2

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

## Place (or move) a team's HQ spawn point on a tile.
func set_hq_spawn(team: int, x: int, y: int) -> bool:
	if team < 0 or team >= MAX_TEAMS or not in_bounds(x, y):
		return false
	for s in hq_spawns:
		if int(s.get("team", -1)) == team:
			s["x"] = x
			s["y"] = y
			return true
	hq_spawns.append({"team": team, "x": x, "y": y})
	return true

func get_hq_spawn(team: int) -> Vector2i:
	for s in hq_spawns:
		if int(s.get("team", -1)) == team:
			return Vector2i(int(s.get("x", -1)), int(s.get("y", -1)))
	return Vector2i(-1, -1)

func remove_hq_spawn(team: int) -> bool:
	for i in range(hq_spawns.size() - 1, -1, -1):
		if int(hq_spawns[i].get("team", -1)) == team:
			hq_spawns.remove_at(i)
			return true
	return false

## Add a resource deposit (Economy.Res type) to a tile, replacing any marker
## already occupying that tile so markers stay one-per-hex.
func add_deposit(type: int, x: int, y: int, amount: int = 1000, rate: float = 10.0) -> bool:
	if type < 0 or type > 3 or not in_bounds(x, y):
		return false
	clear_deposits_at(x, y)
	deposits.append({"type": type, "x": x, "y": y, "amount": amount, "rate": rate})
	return true

func clear_deposits_at(x: int, y: int) -> bool:
	var removed := false
	for i in range(deposits.size() - 1, -1, -1):
		var d: Dictionary = deposits[i]
		if int(d.get("x", -1)) == x and int(d.get("y", -1)) == y:
			deposits.remove_at(i)
			removed = true
	return removed

## Hex distance (axial coordinates) between two tiles.
static func hex_distance(a: Vector2i, b: Vector2i) -> int:
	return int((absi(a.x - b.x) + absi(a.x + a.y - b.x - b.y) + absi(a.y - b.y)) * 0.5)

static func deposits_near(map: MapData, pos: Vector2i, type: int, radius: int) -> int:
	var count := 0
	for d in map.deposits:
		if int(d.get("type", -1)) != type:
			continue
		var p := Vector2i(int(d.get("x", -1)), int(d.get("y", -1)))
		if hex_distance(pos, p) <= radius:
			count += 1
	return count

## Breadth-first path check over passable land hexes between two spawns.
static func hex_connected(map: MapData, a: Vector2i, b: Vector2i) -> bool:
	if a == b:
		return true
	if not map.in_bounds(a.x, a.y) or not map.in_bounds(b.x, b.y):
		return false
	if not is_passable(map.get_terrain(a.x, a.y), 0) or not is_passable(map.get_terrain(b.x, b.y), 0):
		return false
	var grid := HexGrid.new(16.0)
	var visited := {}
	var queue: Array[Vector2i] = [a]
	visited[a] = true
	var head := 0
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		for nb in grid.neighbors(cur):
			if visited.has(nb) or not map.in_bounds(nb.x, nb.y):
				continue
			if not is_passable(map.get_terrain(nb.x, nb.y), 0):
				continue
			if nb == b:
				return true
			visited[nb] = true
			queue.append(nb)
	return false

static func validate_map(map: MapData) -> Dictionary:
	if map == null or map.width < 16 or map.height < 16:
		return {"ok": false, "land_tiles": 0, "water_tiles": 0, "reason": "Map too small", "spawns": 0, "deposits": 0, "connected": false, "balanced": false}
	var land := 0
	var water := 0
	for y in range(map.height):
		for x in range(map.width):
			var t := map.get_terrain(x, y)
			if t == Terrain.SEA or t == Terrain.RIVER:
				water += 1
			elif t != Terrain.MOUNTAIN and t != Terrain.WASTELAND:
				land += 1
	if land < 64:
		return {"ok": false, "land_tiles": land, "water_tiles": water, "reason": "Needs at least 64 passable land tiles", "spawns": 0, "deposits": map.deposits.size(), "connected": false, "balanced": false}
	var result := {
		"ok": true,
		"land_tiles": land,
		"water_tiles": water,
		"reason": "Valid playable map",
		"spawns": map.hq_spawns.size(),
		"deposits": map.deposits.size(),
		"connected": true,
		"balanced": true,
	}
	# Legacy maps without editor metadata remain valid (terrain-only check above).
	if map.hq_spawns.is_empty():
		return result
	if map.hq_spawns.size() < 2:
		result["ok"] = false
		result["connected"] = false
		result["reason"] = "Place at least two HQ spawn points (Team 0 and Team 1)"
		return result
	# Every spawn must sit on passable land, and all spawns must be connected
	# by a hex path that infantry can traverse.
	for s in map.hq_spawns:
		var pos := Vector2i(int(s.get("x", -1)), int(s.get("y", -1)))
		if not map.in_bounds(pos.x, pos.y):
			result["ok"] = false
			result["connected"] = false
			result["reason"] = "HQ spawn is outside the map bounds"
			return result
		if not is_passable(map.get_terrain(pos.x, pos.y), 0):
			result["ok"] = false
			result["connected"] = false
			result["reason"] = "HQ spawn for Team %d is on impassable terrain" % int(s.get("team", -1))
			return result
	for i in range(1, map.hq_spawns.size()):
		var a: Vector2i = map.get_hq_spawn(int(map.hq_spawns[0].get("team", -1)))
		var b: Vector2i = map.get_hq_spawn(int(map.hq_spawns[i].get("team", -1)))
		if not hex_connected(map, a, b):
			result["ok"] = false
			result["connected"] = false
			result["reason"] = "HQ spawns are not connected by a passable hex path"
			return result
	# Starting resources must be balanced: each team needs each resource type
	# near its HQ, with comparable counts across teams.
	var minimums := [INF, INF, INF, INF]
	var maximums := [0.0, 0.0, 0.0, 0.0]
	for s in map.hq_spawns:
		var pos := Vector2i(int(s.get("x", -1)), int(s.get("y", -1)))
		for type in range(4):
			var count := float(deposits_near(map, pos, type, SPAWN_BALANCE_RADIUS))
			minimums[type] = minf(minimums[type], count)
			maximums[type] = maxf(maximums[type], count)
	for type in range(4):
		if minimums[type] < 1.0 or maximums[type] - minimums[type] > float(SPAWN_BALANCE_TOLERANCE):
			result["ok"] = false
			result["balanced"] = false
			result["reason"] = "Starting %s deposits are missing or unbalanced between teams" % ["Oil", "Iron", "Geothermal", "Food"][type]
			return result
	return result
