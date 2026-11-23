# tests/unit/test_stealth.gd
extends GutTest

func test_break_on_attack():
	assert_true(Stealth.break_on_action(true, false, false))

func test_break_on_move():
	assert_true(Stealth.break_on_action(false, true, true))
	assert_false(Stealth.break_on_action(false, true, false))

func test_duration():
	assert_almost_eq(Stealth.cloak_duration(10.0, 1.2), 12.0, 0.001)

func test_is_cloaked():
	assert_true(Stealth.is_cloaked(1.0))
	assert_false(Stealth.is_cloaked(0.0))
