# tests/unit/test_ai.gd
extends GutTest

func test_should_expand():
	assert_true(AI.should_expand(10.0))
	assert_false(AI.should_expand(1.0))

func test_choose_weakest():
	var t = [{"id":1,"strength":5.0},{"id":2,"strength":2.0}]
	assert_eq(AI.choose_weakest_target(t), 2)

func test_choose_empty():
	assert_eq(AI.choose_weakest_target([]), -1)

func test_composition_sums():
	var c = AI.desired_army_composition({"iron":10,"oil":5,"geo":1})
	var sum = c["infantry"]+c["vehicle"]+c["air"]
	assert_almost_eq(sum, 1.0, 0.001)

func test_retreat():
	assert_true(AI.retreat_threshold(0.2))
	assert_false(AI.retreat_threshold(0.5))

func test_difficulty_helpers():
	assert_eq(AI.difficulty_name(AI.Difficulty.EASY), "Easy")
	assert_eq(AI.difficulty_name(AI.Difficulty.NORMAL), "Normal")
	assert_eq(AI.difficulty_name(AI.Difficulty.HARD), "Hard")
	assert_true(AI.income_multiplier(AI.Difficulty.HARD) > AI.income_multiplier(AI.Difficulty.EASY))
	assert_true(AI.decision_interval(AI.Difficulty.HARD) < AI.decision_interval(AI.Difficulty.EASY))
	assert_true(AI.attack_wave_threshold(AI.Difficulty.HARD, 0.0) < AI.attack_wave_threshold(AI.Difficulty.EASY, 0.0))
	assert_true(AI.rally_grace(AI.Difficulty.HARD) < AI.rally_grace(AI.Difficulty.NORMAL))
	assert_true(AI.rally_grace(AI.Difficulty.NORMAL) < AI.rally_grace(AI.Difficulty.EASY))
	assert_true(AI.build_interval(AI.Difficulty.HARD) < AI.build_interval(AI.Difficulty.EASY))
	assert_true(AI.train_interval(AI.Difficulty.HARD) < AI.train_interval(AI.Difficulty.EASY))
	assert_true(AI.order_interval(AI.Difficulty.HARD) < AI.order_interval(AI.Difficulty.EASY))

func test_spectator_aggression_and_scout_route():
	assert_true(AI.attack_wave_threshold(AI.Difficulty.NORMAL, 0.0, true) \
		< AI.attack_wave_threshold(AI.Difficulty.NORMAL, 0.0))
	assert_true(AI.rally_grace(AI.Difficulty.NORMAL, true) < AI.rally_grace(AI.Difficulty.NORMAL))
	var route: Array = AI.scout_route(Vector2(100, 100), Vector2(2048, 2048))
	assert_eq(route.size(), 2)
	assert_gt(route[0].x, 100.0)
	assert_gt(route[0].y, 100.0)
	assert_eq(route[1], Vector2(100, 100))

func test_counter_production_and_tactics():
	var w = {Economy.Res.OIL: 200, Economy.Res.IRON: 350, Economy.Res.GEOTHERMAL: 150}
	assert_eq(AI.choose_production_unit(w, {"air": 3}, 1), "aa_vehicle")
	assert_eq(AI.choose_production_unit(w, {"vehicle": 4}, 2), "bomber_drone")
	assert_eq(AI.choose_production_unit(w, {}, 3), "heavy_mech")
	assert_eq(AI.select_next_building({}, 19, 20), "farm")
	assert_eq(AI.select_next_building({}, 5, 20), "barracks")
	assert_eq(AI.select_next_building({"barracks": 1}, 5, 20), "extractor")
	assert_eq(AI.select_next_building({"extractor": 2, "barracks": 1}, 5, 20), "factory")
	assert_eq(AI.choose_tactical_state(2, 1, 5), "defend")
	assert_eq(AI.choose_tactical_state(6, 0, 5), "attack")
	assert_eq(AI.choose_tactical_state(3, 0, 5), "harass")
	assert_eq(AI.choose_tactical_state(1, 0, 5), "rally")

func test_npc_faction_build_and_production_preferences():
	var rich := {
		Economy.Res.OIL: 400, Economy.Res.IRON: 600,
		Economy.Res.GEOTHERMAL: 250, Economy.Res.FOOD: 100,
	}
	assert_eq(AI.select_next_building({}, 5, 20, Faction.Id.VESPER), "airfield")
	assert_eq(AI.choose_production_unit(rich, {}, 2, Faction.Id.VESPER), "ufo_nova")
	assert_eq(AI.choose_production_unit(rich, {}, 1, Faction.Id.VESPER), "ufo_talon")
	assert_eq(AI.select_next_building({}, 5, 20, Faction.Id.THALASSA), "shipyard")
	assert_eq(AI.choose_production_unit(rich, {}, 3, Faction.Id.THALASSA), "leviathan_carrier")
	assert_eq(AI.choose_production_unit(rich, {}, 2, Faction.Id.THALASSA), "abyssal_trireme")
	assert_eq(AI.choose_production_unit(rich, {}, 3, Faction.Id.GRAVEBOUND), "lichen_colossus")
	assert_eq(AI.choose_production_unit(rich, {}, 1, Faction.Id.GRAVEBOUND), "ghoul_stalker")
	assert_eq(AI.select_next_building({"barracks": 1, "extractor": 2}, 5, 20, Faction.Id.LUMEN), "research_lab")
	assert_eq(AI.choose_production_unit(rich, {}, 2, Faction.Id.LUMEN), "lumen_enforcer")
	assert_eq(AI.choose_production_unit(rich, {}, 1, Faction.Id.LUMEN), "lumen_oracle")
