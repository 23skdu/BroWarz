# scripts/core/terrain_generator.gd
class_name TerrainGenerator
extends RefCounted

static func generate_desert(w: int, h: int, seed: int = 1) -> MapData:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var m := MapData.new(w, h)
	m.name = "Desert"
	for y in range(h):
		for x in range(w):
			var r := rng.randf()
			if r < 0.05:
				m.set_terrain(x, y, MapData.Terrain.MOUNTAIN)
			elif r < 0.15:
				m.set_terrain(x, y, MapData.Terrain.ROAD)
			else:
				m.set_terrain(x, y, MapData.Terrain.PLAINS)
	return m

static func generate_islands(w: int, h: int, seed: int = 2) -> MapData:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var m := MapData.new(w, h)
	m.name = "Island Chain"
	# base sea
	for y in range(h):
		for x in range(w):
			m.set_terrain(x, y, MapData.Terrain.SEA)
	# random islands
	var islands := 6 + rng.randi() % 5
	for i in range(islands):
		var cx := rng.randi_range(8, w - 9)
		var cy := rng.randi_range(8, h - 9)
		var r := rng.randi_range(4, 9)
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if dx * dx + dy * dy <= r * r:
					var x := cx + dx
					var y := cy + dy
					if m.in_bounds(x, y):
						m.set_terrain(x, y, MapData.Terrain.PLAINS)
	# mountains on larger islands
	for y in range(h):
		for x in range(w):
			if m.get_terrain(x, y) == MapData.Terrain.PLAINS and rng.randf() < 0.03:
				m.set_terrain(x, y, MapData.Terrain.MOUNTAIN)
	return m

static func generate_forest(w: int, h: int, seed: int = 3) -> MapData:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var m := MapData.new(w, h)
	m.name = "Forest"
	for y in range(h):
		for x in range(w):
			var r := rng.randf()
			if r < 0.12:
				m.set_terrain(x, y, MapData.Terrain.FOREST)
			elif r < 0.18:
				m.set_terrain(x, y, MapData.Terrain.SWAMP)
			elif r < 0.22:
				m.set_terrain(x, y, MapData.Terrain.MOUNTAIN)
			else:
				m.set_terrain(x, y, MapData.Terrain.PLAINS)
	# river
	var rx := w / 2
	for y in range(h):
		rx = clampi(rx + rng.randi_range(-1, 1), 5, w - 6)
		for dx in range(-1, 2):
			var x := rx + dx
			if m.in_bounds(x, y):
				m.set_terrain(x, y, MapData.Terrain.RIVER)
	return m
