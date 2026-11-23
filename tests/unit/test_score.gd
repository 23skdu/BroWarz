# tests/unit/test_score.gd
extends GutTest

func test_military():
	assert_eq(Score.military_score(2, 1), 70)

func test_total():
	assert_eq(Score.total(70, 30), 100)
