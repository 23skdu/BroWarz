# tests/unit/test_production.gd
extends GutTest

func test_enqueue_and_size():
	var q = Production.new_queue()
	Production.enqueue(q, "riflebot", 5.0)
	assert_eq(Production.queue_size(q), 1)

func test_tick_partial_no_complete():
	var q = Production.new_queue()
	Production.enqueue(q, "riflebot", 5.0)
	var done = Production.tick(q, 2.0)
	assert_eq(done.size(), 0)
	assert_eq(Production.queue_size(q), 1)

func test_tick_complete():
	var q = Production.new_queue()
	Production.enqueue(q, "riflebot", 5.0)
	var done = Production.tick(q, 5.0)
	assert_eq(done.size(), 1)
	assert_eq(done[0], "riflebot")
	assert_eq(Production.queue_size(q), 0)

func test_multi_item_sequential():
	var q = Production.new_queue()
	Production.enqueue(q, "a", 2.0)
	Production.enqueue(q, "b", 2.0)
	var d1 = Production.tick(q, 2.0)
	assert_eq(d1, ["a"])
	var d2 = Production.tick(q, 2.0)
	assert_eq(d2, ["b"])
	assert_eq(Production.queue_size(q), 0)

func test_cancel():
	var q = Production.new_queue()
	Production.enqueue(q, "a", 2.0)
	Production.enqueue(q, "b", 2.0)
	var id = Production.cancel(q, 0)
	assert_eq(id, "a")
	assert_eq(Production.queue_size(q), 1)

func test_progress():
	var q = Production.new_queue()
	Production.enqueue(q, "a", 4.0)
	Production.tick(q, 2.0)
	assert_almost_eq(Production.current_progress(q), 0.5, 0.001)
