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
