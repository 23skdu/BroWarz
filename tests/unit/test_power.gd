# tests/unit/test_power.gd
extends GutTest

func test_balance():
	assert_almost_eq(Power.balance(10.0, 4.0), 6.0, 0.001)

func test_powered():
	assert_true(Power.is_powered(0.0))
	assert_false(Power.is_powered(-1.0))

func test_efficiency():
	assert_eq(Power.efficiency(5.0), 1.0)
	assert_true(Power.efficiency(-50.0) < 1.0)
