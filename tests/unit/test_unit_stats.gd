extends GutTest

func test_defaults_and_cost_dict():
	var s := UnitStats.new()
	assert_eq(s.hp, 100)
	assert_eq(s.build_time, 5.0)
	assert_false(s.stealth)
	var cost := s.cost_dict()
	assert_eq(cost["oil"], 0)
	s.cost_oil = 12
	s.cost_food = 4
	cost = s.cost_dict()
	assert_eq(cost["oil"], 12)
	assert_eq(cost["food"], 4)
