# tests/unit/test_vision.gd
extends GutTest

func test_in_sight():
	assert_true(Vision.in_sight(100.0, 50.0))
	assert_false(Vision.in_sight(100.0, 150.0))

func test_stealth_not_detected_far():
	assert_false(Vision.stealth_detected(100.0, 80.0, true, false))

func test_stealth_detected_close():
	assert_true(Vision.stealth_detected(100.0, 20.0, true, false))

func test_stealth_detected_radar():
	assert_true(Vision.stealth_detected(100.0, 90.0, true, true))

func test_nonstealth_detected():
	assert_true(Vision.stealth_detected(100.0, 90.0, false, false))

func test_fog_state():
	assert_eq(Vision.fog_state(false, false), Vision.FogState.UNEXPLORED)
	assert_eq(Vision.fog_state(true, false), Vision.FogState.EXPLORED)
	assert_eq(Vision.fog_state(true, true), Vision.FogState.VISIBLE)

func test_shared_vision():
	var tv = {0: [1]}
	assert_true(Vision.shared_vision(tv, 0, 1))
	assert_false(Vision.shared_vision(tv, 1, 2))
