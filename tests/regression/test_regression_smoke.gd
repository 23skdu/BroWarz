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

func test_live_unit_combat_stealth_emp_repair_and_eel_mechanics():
	GameManager.registry.populate_defaults()
	var map := MapData.new(16, 16)
	GameManager.start_match(map)

	var unit_scene := preload("res://scenes/unit.tscn")
	# 1. FerroCore Tank HP bonus (+10%) & Sapper speed bonus (+25%)
	var mbt = unit_scene.instantiate()
	add_child_autofree(mbt)
	mbt.setup(GameManager.registry.get_unit("mbt"), 0, Faction.Id.FERROCORE)
	assert_eq(mbt.hp, 462)

	var sapper = unit_scene.instantiate()
	add_child_autofree(sapper)
	sapper.setup(GameManager.registry.get_unit("sapperbot"), 0, Faction.Id.FERROCORE)
	assert_almost_eq(sapper.effective_speed(), 135.0 * 1.25, 0.01)

	# 2. Stealth cloak & Vanguard duration bonus (+20%), breaking cloak on attack
	var stealth = unit_scene.instantiate()
	add_child_autofree(stealth)
	stealth.setup(GameManager.registry.get_unit("stealthbot"), 0, Faction.Id.VANGUARD)
	assert_true(stealth.is_cloaked())
	assert_almost_eq(stealth.cloak_timer, 12.0, 0.01)

	var enemy_rifle = unit_scene.instantiate()
	add_child_autofree(enemy_rifle)
	enemy_rifle.setup(GameManager.registry.get_unit("riflebot"), 1, Faction.Id.AERODYNE)
	enemy_rifle.global_position = Vector2(32, 32)
	stealth.global_position = Vector2(16, 32)
	var pre_hp: int = enemy_rifle.hp
	stealth._perform_attack(enemy_rifle)
	assert_false(stealth.is_cloaked())
	assert_true(enemy_rifle.hp < pre_hp)

	# 3. AWACS EMP weapon disables enemy unit (1.5x duration against unarmored/light)
	var awacs = unit_scene.instantiate()
	add_child_autofree(awacs)
	awacs.setup(GameManager.registry.get_unit("awacs"), 0, Faction.Id.AERODYNE)
	awacs._perform_attack(enemy_rifle)
	assert_true(EMP.is_disabled(enemy_rifle.emp_timer))
	assert_almost_eq(enemy_rifle.emp_timer, 3.75, 0.01)

	# 4. Medicbot auto-repairs damaged friendly unit within 100px
	mbt.global_position = Vector2(50, 50)
	mbt.take_damage(40.0)
	var damaged_hp: int = mbt.hp
	var medic = unit_scene.instantiate()
	add_child_autofree(medic)
	medic.setup(GameManager.registry.get_unit("medicbot"), 0, Faction.Id.FERROCORE)
	medic.global_position = Vector2(64, 50)
	medic._auto_repair_allies(1.0)
	assert_true(mbt.hp > damaged_hp)

	# 5. Hovercraft eel hazard disables hovercraft for 5 seconds
	var hover = unit_scene.instantiate()
	add_child_autofree(hover)
	hover.setup(GameManager.registry.get_unit("hovercraft"), 0, Faction.Id.PELAGIC)
	hover.trigger_eels()
	assert_almost_eq(hover.eel_timer, 5.0, 0.01)
