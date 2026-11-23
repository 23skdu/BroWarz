# tests/unit/test_formation.gd
extends GutTest

func test_count():
	var offs = Formation.grid_offsets(4, 10.0)
	assert_eq(offs.size(), 4)

func test_centered():
	var offs = Formation.grid_offsets(4, 10.0)
	var sum = Vector2.ZERO
	for o in offs:
		sum += o
	assert_true(sum.length() < 0.001)

func test_empty():
	var offs = Formation.grid_offsets(0, 10.0)
	assert_eq(offs.size(), 0)
