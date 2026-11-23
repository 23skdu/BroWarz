# tests/fuzz/test_vision_fuzz.gd
extends GutTest

func test_in_sight_monotonic_fuzz():
	for i in range(200):
		var sr = randf() * 200.0
		var d = randf() * 200.0
		var res = Vision.in_sight(sr, d)
		if d <= sr:
			assert_true(res)
		else:
			assert_false(res)

func test_fog_state_valid_fuzz():
	for i in range(100):
		var e = randi() % 2 == 0
		var v = randi() % 2 == 0
		var fs = Vision.fog_state(e, v)
		assert_true(fs >= 0 and fs <= 2)
