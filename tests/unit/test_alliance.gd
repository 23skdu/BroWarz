# tests/unit/test_alliance.gd
extends GutTest

func test_allied():
	var a = Alliance.new()
	a.add_team(1)
	assert_true(a.is_allied(1))
	assert_false(a.is_allied(2))
	assert_eq(a.size(), 1)

func test_remove():
	var a = Alliance.new()
	a.add_team(1)
	a.remove_team(1)
	assert_false(a.is_allied(1))
