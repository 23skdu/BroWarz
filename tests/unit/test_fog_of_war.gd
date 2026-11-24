# tests/unit/test_fog_of_war.gd
extends GutTest

func test_mark_visible():
	var f = FogOfWar.new(8, 8)
	f.mark_visible(3, 3, 2)
	assert_true(f.is_visible(3, 3))
	assert_true(f.is_explored(3, 3))
	assert_true(f.is_visible(4, 3))

func test_reset():
	var f = FogOfWar.new(8, 8)
	f.mark_visible(3, 3, 2)
	f.reset_visibility()
	assert_false(f.is_visible(3, 3))
	assert_true(f.is_explored(3, 3))

func test_out_of_bounds():
	var f = FogOfWar.new(8, 8)
	assert_false(f.is_visible(10, 10))
