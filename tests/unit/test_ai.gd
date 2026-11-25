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

func test_faction_doctrines_and_tech_priorities():
	var grave := AI.doctrine(Faction.Id.GRAVEBOUND)
	var lumen := AI.doctrine(Faction.Id.LUMEN)
	var vesper := AI.doctrine(Faction.Id.VESPER)
	assert_lt(float(grave["retreat_hp"]), float(lumen["retreat_hp"]))
	assert_lt(float(grave["commit_ratio"]), float(lumen["commit_ratio"]))
	assert_true(bool(vesper["prefer_clouds"]))
	assert_eq(AI.choose_tech_node(["reactive_armor", "railgun_cal"], Faction.Id.VANGUARD), "railgun_cal")
	assert_eq(AI.choose_tech_node(["reactive_armor", "railgun_cal"], Faction.Id.FERROCORE), "reactive_armor")
	assert_eq(AI.choose_tech_node(["cloak_caps", "super_heavy"], Faction.Id.LUMEN), "cloak_caps")
	assert_eq(AI.choose_tech_node(["reactive_armor", "railgun_cal"], Faction.Id.FERROCORE, {"vehicle": 4}), "railgun_cal")

func test_unit_roles_and_target_scoring():
	assert_eq(AI.unit_role("sapperbot", 0, 100.0, false), "worker")
	assert_eq(AI.unit_role("scout_drone", 3, 190.0, false), "scout")
	assert_eq(AI.unit_role("corvette", 2, 320.0, false), "naval")
	assert_eq(AI.unit_role("aa_vehicle", 1, 300.0, false), "anti_air")
	assert_eq(AI.unit_role("artillery", 1, 420.0, false), "standoff")
	assert_eq(AI.unit_role("stealthbot", 0, 170.0, true), "raider")
	assert_eq(AI.unit_role("mbt", 1, 250.0, false), "vanguard")

	# Anti-air prefers enemy bomber over a closer riflebot.
	var aa_atk := {
		"id": "aa_vehicle", "role": "anti_air",
		"damage_type": Damage.DamageType.KINETIC, "range_px": 300.0, "pos": Vector2(0, 0),
	}
	var near_inf := {
		"id": "riflebot", "pos": Vector2(120, 0), "hp": 100.0, "max_hp": 100.0,
		"armor_class": Damage.ArmorClass.UNARMORED, "unit_class": 0, "is_building": false, "threat": 15.0,
	}
	var far_air := {
		"id": "bomber_drone", "pos": Vector2(220, 0), "hp": 290.0, "max_hp": 290.0,
		"armor_class": Damage.ArmorClass.AIR, "unit_class": 3, "is_building": false, "threat": 60.0,
	}
	var sub_target := {
		"id": "attack_sub", "pos": Vector2(100, 0), "hp": 320.0, "max_hp": 320.0,
		"armor_class": Damage.ArmorClass.SUBMERGED, "unit_class": 2, "is_building": false, "threat": 50.0,
	}
	assert_eq(AI.choose_best_target(aa_atk, [near_inf, far_air])["id"], "bomber_drone")
	assert_almost_eq(AI.score_target(aa_atk, sub_target), 0.0, 0.001)

	# Focus-fire prefers damaged enemy over identical full-HP twin.
	var full_tank := {
		"id": "mbt_full", "pos": Vector2(150, 0), "hp": 420.0, "max_hp": 420.0,
		"armor_class": Damage.ArmorClass.HEAVY, "unit_class": 1, "is_building": false, "threat": 45.0,
	}
	var hurt_tank := {
		"id": "mbt_hurt", "pos": Vector2(160, 0), "hp": 80.0, "max_hp": 420.0,
		"armor_class": Damage.ArmorClass.HEAVY, "unit_class": 1, "is_building": false, "threat": 45.0,
	}
	var rocket_atk := {
		"id": "rocketbot", "role": "vanguard",
		"damage_type": Damage.DamageType.EXPLOSIVE, "range_px": 230.0, "pos": Vector2(0, 0),
	}
	assert_eq(AI.choose_best_target(rocket_atk, [full_tank, hurt_tank])["id"], "mbt_hurt")

	# Raider prioritizes exposed economy structure over a defense turret.
	var raider_atk := {
		"id": "stealthbot", "role": "raider",
		"damage_type": Damage.DamageType.ENERGY, "range_px": 170.0, "pos": Vector2(0, 0),
	}
	var econ_bld := {
		"id": "extractor", "pos": Vector2(140, 0), "hp": 450.0, "max_hp": 450.0,
		"armor_class": Damage.ArmorClass.STRUCTURE, "unit_class": 0, "is_building": true,
		"is_economy": true, "is_defense": false, "threat": 25.0,
	}
	var def_bld := {
		"id": "turret", "pos": Vector2(140, 0), "hp": 520.0, "max_hp": 520.0,
		"armor_class": Damage.ArmorClass.STRUCTURE, "unit_class": 0, "is_building": true,
		"is_economy": false, "is_defense": true, "threat": 40.0,
	}
	assert_eq(AI.choose_best_target(raider_atk, [def_bld, econ_bld])["id"], "extractor")

func test_power_threat_and_producer_aware_macro():
	# Power deficit triggers power_plant immediately.
	assert_eq(AI.select_next_building({"barracks": 1}, 5, 20, -1, -5.0), "power_plant")
	assert_eq(AI.select_next_building({"barracks": 1}, 5, 20, -1, 0.0), "power_plant")
	# Observed stealth triggers radar; Gravebound builds radar after 2 extractors.
	assert_eq(AI.select_next_building({"barracks": 1}, 5, 20, -1, 20.0, {"stealth": 1}), "radar")
	assert_eq(AI.select_next_building({"barracks": 1, "extractor": 2}, 5, 20, Faction.Id.GRAVEBOUND, 20.0), "radar")
	# Thalassa gracefully skips shipyard on dry maps (has_water = false).
	assert_eq(AI.select_next_building({}, 5, 20, Faction.Id.THALASSA, 20.0, {}, false), "barracks")

	# Producer-filtered counter-production avoids unbuildable units and replaces missing workers.
	var rich := {Economy.Res.OIL: 400, Economy.Res.IRON: 600, Economy.Res.GEOTHERMAL: 250, Economy.Res.FOOD: 100}
	assert_eq(AI.choose_production_unit(rich, {"air": 3}, 1, -1, {"worker": 1}, ["barracks"]), "stealthbot")
	assert_eq(AI.choose_production_unit(rich, {}, 1, -1, {"worker": 0, "total": 4}, ["barracks"]), "sapperbot")
	assert_eq(AI.choose_production_unit(rich, {"submerged": 1}, 1, -1, {"naval": 0}, ["shipyard"]), "corvette")
	assert_eq(AI.choose_production_unit(rich, {"stealth": 2}, 1, -1, {"scout": 0}, ["airfield"]), "awacs")

func test_force_ratio_and_geometric_tactical_helpers():
	# Outgunned squad regroups/harasses instead of suiciding; superior force attacks.
	assert_eq(AI.choose_tactical_state(6, 0, 5, 200.0, 600.0, Faction.Id.LUMEN, AI.Difficulty.NORMAL), "harass")
	assert_eq(AI.choose_tactical_state(3, 0, 5, 100.0, 500.0, Faction.Id.LUMEN, AI.Difficulty.NORMAL), "regroup")
	assert_eq(AI.choose_tactical_state(4, 0, 5, 600.0, 300.0, Faction.Id.FERROCORE, AI.Difficulty.NORMAL), "attack")
	assert_eq(AI.choose_tactical_state(6, 0, 5, 320.0, 600.0, Faction.Id.GRAVEBOUND, AI.Difficulty.NORMAL), "attack")

	var world := Vector2(2048, 2048)
	var wps := AI.scout_waypoints(Vector2(160, 160), world, [Vector2(1000, 1000)], Vector2(1500, 1500))
	assert_gte(wps.size(), 4)
	assert_eq(wps[0], Vector2(1000, 1000))

	var flank := AI.flank_waypoint(Vector2(200, 200), Vector2(1000, 200), world, 1, 240.0)
	assert_gt(absf(flank.y - 200.0), 150.0)

	# Standoff pushes artillery back when enemy is inside close range.
	var standoff := AI.standoff_position(Vector2(500, 500), Vector2(560, 500), 400.0, world)
	assert_lt(standoff.x, 400.0)

	# Tactical rally favors Forest cover over Plains/Swamp for infantry.
	var m := MapData.new(32, 32)
	for y in range(32):
		for x in range(32):
			m.set_terrain(x, y, MapData.Terrain.SWAMP)
	m.set_terrain(16, 10, MapData.Terrain.FOREST)
	var rally := AI.choose_tactical_rally(m, Vector2(64, 160), Vector2(450, 160), 0, Vector2(512, 512))
	assert_almost_eq(rally.x, 16.0 * 16.0 + 8.0, 24.0)

	# Ground retreats toward friendly sapper; air retreats into nearby cloud.
	var g_ret := AI.choose_retreat_point(Vector2(500, 500), Vector2(160, 160), 0, [Vector2(300, 300)], [], world)
	assert_eq(g_ret, Vector2(300, 300))
	var a_ret := AI.choose_retreat_point(Vector2(600, 600), Vector2(160, 160), 3, [], [{"pos": Vector2(420, 420), "radius": 90.0}], world)
	assert_eq(a_ret, Vector2(420, 420))

	# Strategic strike picks dense cluster and ignores sparse targets below threshold.
	var cluster := [
		{"pos": Vector2(800, 800), "value": 300.0},
		{"pos": Vector2(840, 810), "value": 250.0},
		{"pos": Vector2(200, 200), "value": 100.0},
	]
	assert_eq(AI.choose_strategic_strike_target(cluster, 95.0, 400.0), Vector2(800, 800))
	assert_eq(AI.choose_strategic_strike_target([{"pos": Vector2(200, 200), "value": 60.0}], 95.0, 240.0), Vector2.INF)

	# Sonar buoy decision drops buoy when none covers the sector, skips if already covered.
	var buoy_pos := AI.should_deploy_sonar(Vector2(400, 400), Vector2(800, 400), [], 1, {"submerged": 1})
	assert_ne(buoy_pos, Vector2.INF)
	var covered := AI.should_deploy_sonar(Vector2(400, 400), Vector2(800, 400), [{"owner_team": 1, "pos": buoy_pos}], 1, {"submerged": 1})
	assert_eq(covered, Vector2.INF)
