# tests/unit/test_placement.gd
extends GutTest

func test_can_place_basic():
	var m = MapData.new(8, 8)
	var occ = {}
	assert_true(Placement.can_place(m, Vector2i(2,2), Vector2i(0,0), occ))

func test_out_of_bounds():
	var m = MapData.new(8, 8)
	var occ = {}
	assert_false(Placement.can_place(m, Vector2i(2,2), Vector2i(7,7), occ))

func test_occupied():
	var m = MapData.new(8, 8)
	var occ = {}
	Placement.occupy(occ, Vector2i(2,2), Vector2i(0,0))
	assert_false(Placement.can_place(m, Vector2i(2,2), Vector2i(0,0), occ))
	assert_false(Placement.can_place(m, Vector2i(2,2), Vector2i(1,1), occ))

func test_terrain_blocked():
	var m = MapData.new(8, 8)
	m.set_terrain(1, 1, MapData.Terrain.SEA)
	var occ = {}
	assert_false(Placement.can_place(m, Vector2i(2,2), Vector2i(0,0), occ))

func test_free():
	var m = MapData.new(8, 8)
	var occ = {}
	Placement.occupy(occ, Vector2i(2,2), Vector2i(0,0))
	Placement.free_footprint(occ, Vector2i(2,2), Vector2i(0,0))
	assert_true(Placement.can_place(m, Vector2i(2,2), Vector2i(0,0), occ))
