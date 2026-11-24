# tests/unit/test_lobby_state.gd
extends GutTest

func _make_lobby() -> LobbyState:
	var l := LobbyState.new()
	l.add_player(1, "Host", "1.2.3.4")
	l.add_player(2, "Guest", "5.6.7.8")
	return l

func test_add_player_assigns_teams():
	var l := _make_lobby()
	assert_eq(l.team_of(1), 0)
	assert_eq(l.team_of(2), 1)

func test_ready_gating():
	var l := _make_lobby()
	assert_false(l.can_start(1)["ok"])
	l.set_ready(1, true)
	l.set_ready(2, true)
	assert_true(l.can_start(1)["ok"])

func test_host_only_settings():
	var l := _make_lobby()
	assert_false(l.update_settings(2, {"map_type": 1}))
	assert_true(l.update_settings(1, {"map_type": 1}))
	assert_eq(l.setting("map_type"), 1)

func test_grace_and_sweep():
	var l := _make_lobby()
	l.mark_disconnected(2, 1000.0)
	assert_true(l.in_grace(2, 1000.0 + 1000.0))
	var expired := l.sweep(1000.0 + 40000.0)
	assert_true(expired.has(2))
	assert_false(l.has_player(2))

func test_transfer_rejoin():
	var l := _make_lobby()
	l.mark_disconnected(2, 1000.0)
	var tok := str(l.players[2]["token"]) if l.has_player(2) else ""
	# token still present after mark_disconnected
	assert_false(tok.is_empty())
	var res := l.transfer(2, 9, tok, 2000.0)
	assert_true(res["ok"])
	assert_true(l.has_player(9))
	assert_false(l.has_player(2))

func test_snapshot_roundtrip():
	var l := _make_lobby()
	l.set_ready(1, true)
	var snap := l.snapshot()
	var l2 := LobbyState.new()
	l2.apply_snapshot(snap)
	assert_eq(l2.players.size(), 2)
	assert_true(l2.ready_of(1))

func test_next_host_id():
	var l := _make_lobby()
	assert_eq(l.next_host_id, 2)