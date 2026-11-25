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

func test_malformed_commands_are_filtered():
	var d := {
		"seed": 7, "map_name": "M", "ticks": 9,
		"commands": [
			{"type": 999, "tick": 1},
			{"type": Command.Type.MOVE, "tick": 2},
			{"type": Command.Type.DEMOLISH, "tick": 3},
			"not-a-dictionary",
		],
	}
	var r := Replay.from_dict(d)
	assert_eq(r.command_count(), 2)
	assert_eq(r.invalid_commands, 2)
	assert_eq(Command.from_dict(r.commands[1]).type, Command.Type.DEMOLISH)

func test_non_array_commands_do_not_crash():
	var r := Replay.from_dict({"commands": "broken"})
	assert_eq(r.command_count(), 0)
