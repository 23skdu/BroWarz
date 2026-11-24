# tests/unit/test_map_serializer.gd
extends GutTest

func test_roundtrip():
	var m = MapData.new(4, 4)
	m.name = "Test"
	m.set_terrain(1, 1, MapData.Terrain.SWAMP)
	var d = MapSerializer.to_dict(m)
	var m2 = MapSerializer.from_dict(d)
	assert_eq(m2.name, "Test")
	assert_eq(m2.get_terrain(1, 1), MapData.Terrain.SWAMP)
	assert_eq(m2.width, 4)

func test_validate_ok():
	var m = MapData.new(2, 2)
	var d = MapSerializer.to_dict(m)
	assert_true(MapSerializer.validate(d))

func test_validate_bad_size():
	var d = {"width": 2, "height": 2, "tiles": [0,0,0]}
	assert_false(MapSerializer.validate(d))

func test_validate_bad_dims():
	assert_false(MapSerializer.validate({"width": 0, "height": 2, "tiles": []}))

func test_share_code_and_file_roundtrip():
	var m := MapData.new(16, 16)
	m.name = "Oasis Basin"
	m.author = "Alice"
	m.set_terrain(3, 4, MapData.Terrain.SEA)
	m.set_terrain(5, 6, MapData.Terrain.DESERT)
	m.set_terrain(7, 8, MapData.Terrain.HILLS)
	m.set_terrain(9, 10, MapData.Terrain.FOREST)
	var code := MapSerializer.to_share_code(m)
	assert_true(code.begins_with("BWM1:"))
	var m2 := MapSerializer.from_share_code(code)
	assert_not_null(m2)
	assert_eq(m2.name, "Oasis Basin")
	assert_eq(m2.author, "Alice")
	assert_eq(m2.get_terrain(3, 4), MapData.Terrain.SEA)
	assert_eq(m2.get_terrain(5, 6), MapData.Terrain.DESERT)
	assert_eq(m2.get_terrain(7, 8), MapData.Terrain.HILLS)
	assert_eq(m2.get_terrain(9, 10), MapData.Terrain.FOREST)
	assert_null(MapSerializer.from_share_code("INVALID"))

