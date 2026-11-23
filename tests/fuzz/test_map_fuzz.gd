# tests/fuzz/test_map_fuzz.gd
extends GutTest

func test_movement_cost_finite_or_inf_fuzz():
	for i in range(300):
		var t = randi() % 10
		var uc = randi() % 4
		var c = MapData.movement_cost(t, uc)
		assert_true(c > 0.0)

func test_in_bounds_fuzz():
	var m = MapData.new(8, 8)
	for i in range(200):
		var x = randi() % 16 - 4
		var y = randi() % 16 - 4
		var ib = m.in_bounds(x, y)
		assert_eq(ib, x>=0 and y>=0 and x<8 and y<8)
