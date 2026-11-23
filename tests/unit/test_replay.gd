# tests/unit/test_replay.gd
extends GutTest

func test_record_and_count():
	var r = Replay.new()
	var c = Command.new()
	c.tick = 3
	r.record(c)
	assert_eq(r.command_count(), 1)
	assert_eq(r.ticks, 3)

func test_roundtrip():
	var r = Replay.new()
	r.seed = 42
	r.map_name = "M"
	var c = Command.new()
	c.tick = 2
	r.record(c)
	var d = r.to_dict()
	var r2 = Replay.from_dict(d)
	assert_eq(r2.seed, 42)
	assert_eq(r2.map_name, "M")
	assert_eq(r2.command_count(), 1)
