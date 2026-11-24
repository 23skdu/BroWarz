# tests/unit/test_map_data.gd
extends GutTest

func test_default_size():
	var m = MapData.new()
	assert_eq(m.width, 128)
	assert_eq(m.height, 128)
	assert_eq(m.tile_count(), 16384)

func test_set_get_terrain():
	var m = MapData.new(4, 4)
	assert_true(m.set_terrain(1, 2, MapData.Terrain.SWAMP))
	assert_eq(m.get_terrain(1, 2), MapData.Terrain.SWAMP)

func test_out_of_bounds():
	var m = MapData.new(4, 4)
	assert_false(m.in_bounds(4, 0))
	assert_eq(m.get_terrain(4, 0), -1)
	assert_false(m.set_terrain(4, 0, MapData.Terrain.SEA))

func test_movement_cost_infantry_swamp():
	var c = MapData.movement_cost(MapData.Terrain.SWAMP, 0)
	assert_true(c > 1.0)

func test_vehicle_swamp_impassable():
	assert_false(MapData.is_passable(MapData.Terrain.SWAMP, 1))

func test_naval_sea_passable():
	assert_true(MapData.is_passable(MapData.Terrain.SEA, 2))

func test_air_always_passable():
	assert_true(MapData.is_passable(MapData.Terrain.MOUNTAIN, 3))

func test_index_roundtrip():
	var m = MapData.new(8, 8)
	assert_eq(m.index(3, 4), 4*8+3)

func test_desert_and_hills_terrains():
	assert_eq(MapData.terrain_name(MapData.Terrain.DESERT), "Desert")
	assert_eq(MapData.terrain_name(MapData.Terrain.HILLS), "Hills")
	assert_true(MapData.is_passable(MapData.Terrain.DESERT, 0))
	assert_true(MapData.is_passable(MapData.Terrain.HILLS, 1))
	assert_true(MapData.movement_cost(MapData.Terrain.HILLS, 1) > MapData.movement_cost(MapData.Terrain.PLAINS, 1))
	assert_true(Cover.provides_cover(MapData.Terrain.HILLS))

