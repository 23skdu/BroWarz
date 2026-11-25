# tests/unit/test_alliance.gd
extends GutTest

func test_allied():
	var a = Alliance.new()
	a.add_team(1)
	assert_true(a.is_allied(1))
	assert_false(a.is_allied(2))
	assert_eq(a.size(), 1)

func test_remove():
	var a = Alliance.new()
	a.add_team(1)
	a.remove_team(1)
	assert_false(a.is_allied(1))

func test_normalize_makes_lobby_sides_symmetric_and_transitive():
	var graph := Alliance.normalize({0: [0, 2], 1: [1, 3]})
	assert_true(Alliance.are_allied_teams(graph, 0, 2))
	assert_true(Alliance.are_allied_teams(graph, 2, 0))
	assert_true(Alliance.are_allied_teams(graph, 1, 3))
	assert_false(Alliance.are_allied_teams(graph, 0, 1))
	assert_eq(graph[2].size(), 2)

func test_proposal_accept_merge_and_break():
	var graph: Dictionary = {}
	var proposals: Dictionary = {}
	assert_true(Alliance.set_proposal(proposals, 0, 2))
	assert_true(Alliance.has_proposal(proposals, 0, 2))
	assert_false(Alliance.set_proposal(proposals, 0, 2))
	assert_false(Alliance.has_proposal(proposals, 2, 0))
	assert_true(Alliance.form(graph, 2, 0))
	assert_true(Alliance.are_allied_teams(graph, 0, 2))
	Alliance.clear_proposals_between(proposals, Alliance.members(graph, 0), Alliance.members(graph, 2))
	assert_false(Alliance.has_proposal(proposals, 0, 2))
	assert_true(Alliance.split(graph, 0, 2))
	assert_false(Alliance.are_allied_teams(graph, 0, 2))

func test_break_on_one_side_dissolves_whole_side():
	var graph := Alliance.normalize({0: [1], 1: [2], 2: []})
	assert_true(Alliance.are_allied_teams(graph, 0, 2))
	assert_true(Alliance.split(graph, 0, 1))
	assert_false(Alliance.are_allied_teams(graph, 0, 1))
	assert_false(Alliance.are_allied_teams(graph, 1, 2))

func test_clean_proposals_rejects_malformed_keys():
	var raw := {"0>2": true, "2>99": true, "bad": true, "3>3": true}
	var clean := Alliance.clean_proposals(raw, [0, 1, 2, 3])
	assert_eq(clean.size(), 1)
	assert_true(Alliance.has_proposal(clean, 0, 2))
	clean = Alliance.clean_proposals(raw, [0, 1])
	assert_eq(clean.size(), 0)
