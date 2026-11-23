# tests/unit/test_ai.gd
extends GutTest

func test_should_expand():
	assert_true(AI.should_expand(10.0))
	assert_false(AI.should_expand(1.0))

func test_choose_weakest():
	var t = [{"id":1,"strength":5.0},{"id":2,"strength":2.0}]
	assert_eq(AI.choose_weakest_target(t), 2)

func test_choose_empty():
	assert_eq(AI.choose_weakest_target([]), -1)

func test_composition_sums():
	var c = AI.desired_army_composition({"iron":10,"oil":5,"geo":1})
	var sum = c["infantry"]+c["vehicle"]+c["air"]
	assert_almost_eq(sum, 1.0, 0.001)

func test_retreat():
	assert_true(AI.retreat_threshold(0.2))
	assert_false(AI.retreat_threshold(0.5))
