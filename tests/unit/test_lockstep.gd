# tests/unit/test_lockstep.gd
extends GutTest

func test_queue_and_pop():
	var ls = Lockstep.new()
	var c = Command.new()
	c.tick = 5
	ls.queue_command(c)
	assert_true(ls.has_commands(5))
	var cmds = ls.pop_tick(5)
	assert_eq(cmds.size(), 1)
	assert_false(ls.has_commands(5))

func test_target_tick():
	var ls = Lockstep.new()
	ls.tick = 10
	ls.input_delay = 3
	assert_eq(ls.target_tick_for_input(), 13)

func test_all_peers_ready():
	var ls = Lockstep.new()
	ls.peer_ready(1, 5)
	ls.peer_ready(2, 4)
	assert_false(ls.all_peers_ready([1,2], 5))
	ls.peer_ready(2, 5)
	assert_true(ls.all_peers_ready([1,2], 5))

func test_advance():
	var ls = Lockstep.new()
	assert_eq(ls.advance(), 1)
	assert_eq(ls.tick, 1)

func test_multi_peer_lockstep_soak_simulation():
	var res := Lockstep.run_soak_simulation(4, 150, 2030)
	assert_true(bool(res["ok"]))
	assert_eq(int(res["peers"]), 4)
	assert_eq(int(res["ticks"]), 150)
	assert_eq(int(res["desyncs"]), 0)
	assert_true(int(res["commands"]) > 100)
