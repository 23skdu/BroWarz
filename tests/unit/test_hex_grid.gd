extends GutTest

func test_world_hex_roundtrip():
	var grid := HexGrid.new(16.0)
	var cell := Vector2i(3, -2)
	var world: Vector2 = grid.hex_to_world(cell)
	assert_eq(grid.world_to_hex(world), cell)
	assert_eq(grid.neighbors(cell).size(), 6)

func test_distance_and_path():
	var grid := HexGrid.new(16.0)
	assert_eq(grid.distance(Vector2i(0, 0), Vector2i(2, 1)), 3)
	var passable := func(_h: Vector2i) -> bool:
		return true
	var blocked := func(_h: Vector2i) -> bool:
		return false
	var path: Array[Vector2i] = grid.hex_path(Vector2i(0, 0), Vector2i(2, 0), passable)
	assert_gt(path.size(), 0)
	assert_eq(path[path.size() - 1], Vector2i(2, 0))
	assert_eq(grid.hex_path(Vector2i(0, 0), Vector2i(2, 0), blocked).size(), 0)
