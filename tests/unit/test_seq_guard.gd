# tests/unit/test_seq_guard.gd
extends GutTest

func test_accept_monotonic():
	var g := SeqGuard.new()
	assert_true(g.accept(1, 0))
	assert_true(g.accept(1, 1))
	assert_false(g.accept(1, 1))  # replay

func test_accept_rejects_lower():
	var g := SeqGuard.new()
	assert_true(g.accept(1, 5))
	assert_false(g.accept(1, 3))

func test_advance_increments():
	var g := SeqGuard.new()
	assert_eq(g.advance(1), 0)
	assert_eq(g.advance(1), 1)

func test_clear():
	var g := SeqGuard.new()
	g.accept(1, 10)
	g.clear()
	assert_true(g.accept(1, 0))