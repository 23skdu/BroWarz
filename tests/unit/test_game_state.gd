# tests/unit/test_game_state.gd
extends GutTest

func test_snapshot_roundtrip():
	var gs = GameState.new()
	gs.tick = 5
	gs.resources[1] = Economy.empty_wallet()
	gs.resources[1][Economy.Res.OIL] = 10
	gs.units.append({"id":1,"team":0,"x":1,"y":2,"hp":100})
	var s = gs.snapshot()
	var gs2 = GameState.from_snapshot(s)
	assert_eq(gs2.tick, 5)
	assert_eq(gs2.resources[1][Economy.Res.OIL], 10)
	assert_eq(gs2.units.size(), 1)

func test_checksum_deterministic():
	var gs = GameState.new()
	gs.tick = 3
	gs.units.append({"id":1,"team":0,"x":0,"y":0,"hp":50})
	var c1 = gs.checksum()
	var c2 = gs.checksum()
	assert_eq(c1, c2)

func test_checksum_changes():
	var gs = GameState.new()
	gs.tick = 3
	var c1 = gs.checksum()
	gs.tick = 4
	var c2 = gs.checksum()
	assert_ne(c1, c2)
