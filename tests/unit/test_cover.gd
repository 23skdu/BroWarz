# tests/unit/test_cover.gd
extends GutTest

func test_urban_cover():
	assert_true(Cover.provides_cover(MapData.Terrain.URBAN))
	assert_almost_eq(Cover.modifier(MapData.Terrain.URBAN), 0.7, 0.001)

func test_plains_no_cover():
	assert_false(Cover.provides_cover(MapData.Terrain.PLAINS))
	assert_eq(Cover.modifier(MapData.Terrain.PLAINS), 1.0)
