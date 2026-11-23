# tests/unit/test_pathfinding.gd
extends GutTest

func test_straight_path():
	var m = MapData.new(5, 5)
	var path = Pathfinding.find_path(m, Vector2i(0,0), Vector2i(3,0), 0)
	assert_eq(path.size(), 3)
	assert_eq(path[2], Vector2i(3,0))

func test_no_path():
	var m = MapData.new(5, 5)
	# wall of mountains
	for y in range(5):
		m.set_terrain(2, y, MapData.Terrain.MOUNTAIN)
	var path = Pathfinding.find_path(m, Vector2i(0,0), Vector2i(4,0), 0)
	assert_eq(path.size(), 0)

func test_avoid_water_for_infantry():
	var m = MapData.new(5, 5)
	m.set_terrain(1, 0, MapData.Terrain.SEA)
	var path = Pathfinding.find_path(m, Vector2i(0,0), Vector2i(2,0), 0)
	# should go around
	assert_true(path.size() >= 3)

func test_same_start_goal():
	var m = MapData.new(5, 5)
	var path = Pathfinding.find_path(m, Vector2i(1,1), Vector2i(1,1), 0)
	assert_eq(path.size(), 0)
