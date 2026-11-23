# tests/fuzz/test_production_fuzz.gd
extends GutTest

func test_progress_range_fuzz():
	for i in range(200):
		var q = Production.new_queue()
		var bt = randf() * 10.0 + 0.1
		Production.enqueue(q, "x", bt)
		var dt = randf() * bt
		Production.tick(q, dt)
		var p = Production.current_progress(q)
		assert_true(p >= 0.0 and p <= 1.0)

func test_queue_size_nonnegative_fuzz():
	for i in range(200):
		var q = Production.new_queue()
		var n = randi() % 5
		for j in range(n):
			Production.enqueue(q, "u", randf() + 0.1)
		# tick random
		for j in range(3):
			Production.tick(q, randf() * 2.0)
		assert_true(Production.queue_size(q) >= 0)
