# tests/unit/test_tech.gd
extends GutTest

func test_can_research_no_requires():
	assert_true(Tech.can_research([], []))

func test_can_research_missing():
	assert_false(Tech.can_research([], ["a"]))

func test_can_research_ok():
	assert_true(Tech.can_research(["a"], ["a"]))

func test_unlock():
	var u = []
	assert_true(Tech.unlock(u, "a"))
	assert_false(Tech.unlock(u, "a"))
	assert_true(u.has("a"))

func test_affordable():
	var w = Economy.empty_wallet()
	w[Economy.Res.OIL] = 10
	assert_true(Tech.research_cost_affordable(w, {Economy.Res.OIL: 5}))
	assert_false(Tech.research_cost_affordable(w, {Economy.Res.OIL: 20}))
