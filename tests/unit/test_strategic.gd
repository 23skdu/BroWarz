# tests/unit/test_strategic.gd
extends GutTest

func test_nuke_radius():
	assert_eq(Strategic.nuke_fallout_radius(5, 2.0), 10)

func test_laser_damage():
	assert_almost_eq(Strategic.orbital_laser_damage(100.0, 500.0), 150.0, 0.001)

func test_fallout():
	assert_true(Strategic.creates_fallout("nuke"))
	assert_false(Strategic.creates_fallout("laser"))
