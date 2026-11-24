# tests/unit/test_terrain_generator.gd
extends GutTest

func test_desert_no_water():
	var m = TerrainGenerator.generate_desert(16, 16, 1)
	for y in range(16):
		for x in range(16):
			var t = m.get_terrain(x, y)
			assert_true(t != MapData.Terrain.SEA and t != MapData.Terrain.RIVER)

func test_islands_has_sea():
	var m = TerrainGenerator.generate_islands(32, 32, 2)
	var has_sea := false
	for y in range(32):
		for x in range(32):
			if m.get_terrain(x, y) == MapData.Terrain.SEA:
				has_sea = true
	assert_true(has_sea)

func test_forest_has_river_mountain_swamp():
	var m = TerrainGenerator.generate_forest(32, 32, 3)
	var has_river := false
	var has_mountain := false
	var has_swamp := false
	for y in range(32):
		for x in range(32):
			var t = m.get_terrain(x, y)
			if t == MapData.Terrain.RIVER: has_river = true
			if t == MapData.Terrain.MOUNTAIN: has_mountain = true
			if t == MapData.Terrain.SWAMP: has_swamp = true
	assert_true(has_river and has_mountain and has_swamp)

func test_deterministic():
	var a = TerrainGenerator.generate_desert(8, 8, 5)
	var b = TerrainGenerator.generate_desert(8, 8, 5)
	assert_eq(a.tiles, b.tiles)
