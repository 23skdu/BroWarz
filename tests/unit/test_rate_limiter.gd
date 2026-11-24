# tests/unit/test_rate_limiter.gd
extends GutTest

func test_allows_within_capacity():
	var rl := RateLimiter.new(2.0, 4.0, 3)
	assert_true(rl.try_request(1, 0.0))
	assert_true(rl.try_request(1, 0.0))

func test_refills_over_time():
	var rl := RateLimiter.new(1.0, 1.0, 3)
	assert_true(rl.try_request(1, 0.0))
	assert_false(rl.try_request(1, 0.0))
	assert_true(rl.try_request(1, 1500.0))

func test_ban_after_strikes():
	var rl := RateLimiter.new(10.0, 10.0, 2)
	rl.record_violation(1)
	rl.record_violation(1)
	assert_true(rl.is_banned(1))

func test_clear_resets():
	var rl := RateLimiter.new(1.0, 1.0, 1)
	rl.record_violation(1)
	rl.clear()
	assert_false(rl.is_banned(1))