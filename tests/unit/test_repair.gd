# tests/unit/test_repair.gd
extends GutTest

func test_amount():
	assert_almost_eq(Repair.repair_amount(5.0, 2.0), 10.0, 0.001)

func test_cost():
	assert_eq(Repair.cost_for_amount(10.0, 0.5), 5)

func test_can_repair():
	assert_true(Repair.can_repair(50, 100))
	assert_false(Repair.can_repair(100, 100))
	assert_false(Repair.can_repair(0, 100))
