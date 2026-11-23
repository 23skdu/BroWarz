# tests/unit/test_emp.gd
extends GutTest

func test_disabled():
	assert_true(EMP.is_disabled(1.0))
	assert_false(EMP.is_disabled(0.0))

func test_tick():
	assert_almost_eq(EMP.tick(2.0, 1.0), 1.0, 0.001)
	assert_eq(EMP.tick(0.5, 1.0), 0.0)

func test_duration():
	assert_almost_eq(EMP.disable_duration(2.0, 0), 3.0, 0.001)
	assert_almost_eq(EMP.disable_duration(2.0, 3), 2.0, 0.001)
