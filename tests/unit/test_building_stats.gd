# tests/unit/test_building_stats.gd
extends GutTest

func test_cost_dict():
	var s = BuildingStats.new()
	s.cost_oil = 10
	s.cost_iron = 5
	var c = s.cost_dict()
	assert_eq(c["oil"], 10)
	assert_eq(c["iron"], 5)

func test_defaults():
	var s = BuildingStats.new()
	assert_eq(s.hp, 500)
	assert_false(s.is_hq)
