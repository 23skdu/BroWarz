# tests/regression/test_regression_smoke.gd
extends GutTest

func test_single_player_ai_skirmish_flow():
	GameManager.start_single_player(AI.Difficulty.HARD, MapData.new(32, 32), Faction.Id.AERODYNE, Faction.Id.FERROCORE)
	assert_true(GameManager.match_started)
	assert_eq(GameManager.match_mode, GameManager.Mode.SINGLE_PLAYER)
	assert_eq(GameManager.ai_difficulty, AI.Difficulty.HARD)
	var uid := AI.choose_production_unit({Economy.Res.OIL: 120, Economy.Res.IRON: 220}, {"air": 3}, 2)
	assert_eq(uid, "aa_vehicle")
	assert_true(GameManager.registry.has_unit(uid))
	GameManager.end_match(0)
	assert_false(GameManager.match_started)
