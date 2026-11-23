# tests/fuzz/test_damage_fuzz.gd
extends GutTest

func test_compute_nonnegative_fuzz():
	for i in range(200):
		var base = randf() * 100.0
		var dt = randi() % 6
		var ac = randi() % 8
		var ar = randf()
		var cov = randf() * 2.0
		var d = Damage.compute(base, dt, ac, ar, cov)
		assert_true(d >= 0.0)

func test_multiplier_range_fuzz():
	for i in range(200):
		var dt = randi() % 6
		var ac = randi() % 8
		var m = Damage.multiplier(dt, ac)
		assert_true(m >= 0.0 and m <= 2.0)
