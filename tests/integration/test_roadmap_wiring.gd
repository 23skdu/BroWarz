# tests/integration/test_roadmap_wiring.gd
extends GutTest

## Regression coverage for checked roadmap features that must be wired into
## the live game/UI, not merely implemented in pure core modules.

func _new_game() -> Node2D:
	GameManager.start_single_player(AI.Difficulty.NORMAL, null, 0, 1, 2)
	var game: Node2D = preload("res://scenes/game.tscn").instantiate()
	add_child_autofree(game)
	NetworkManager.attach_game(null)
	return game

func _count_buildings(game: Node2D, id: String, team: int = -1) -> int:
	var count := 0
	for b in get_tree().get_nodes_in_group("buildings"):
		if is_instance_valid(b) and b.stats != null and b.stats.id == id:
			if team < 0 or int(b.team) == team:
				count += 1
	return count

func test_minimap_is_wired_to_live_game_state():
	var game := _new_game()
	assert_not_null(game.minimap)
	assert_eq(game.minimap.game, game)
	game._on_minimap_camera(Vector2(900, 700))
	assert_ne(game.camera.position, Vector2.ZERO)

func test_colorblind_change_refreshes_live_units():
	var game := _new_game()
	var unit = game._get_team_units(0)[0]
	unit._frame_cache["probe"] = null
	SettingsManager.set_setting("colorblind", "deuteranopia")
	assert_eq(SettingsManager.colorblind_palette(), "deuteranopia")
	assert_false(unit._frame_cache.has("probe"))
	SettingsManager.set_setting("colorblind", "none")

func test_control_groups_and_double_click_center_camera():
	var game := _new_game()
	var units: Array = game._get_team_units(0)
	game.selected_units = [units[0], units[1]]
	game._set_control_group(8)
	game.selected_units.clear()
	game.camera.position = Vector2(20, 20)
	game._recall_control_group(8)
	assert_eq(game.selected_units.size(), 2)
	assert_ne(game.camera.position, Vector2(20, 20))

	var clicked = units[0]
	game.camera.position = Vector2(20, 20)
	game._complete_selection(clicked.global_position, clicked.global_position, false, true)
	assert_eq(game.camera.position, game._clamp_camera(clicked.global_position))

func test_research_requires_lab_and_boosts_existing_units():
	var game := _new_game()
	assert_false(game._team_has_research_lab(0))
	assert_false(game.apply_command({"type": "tech", "team": 0, "id": "reactive_armor"}))
	var hq: Node2D = game._find_team_hq(0)
	var lab: Node2D = game._spawn_building_by_id("research_lab", hq.global_position + Vector2(96, 96), 0)
	assert_not_null(lab)
	assert_true(game._team_has_research_lab(0))
	var wallet := ResourceManager.get_wallet(0)
	wallet[Economy.Res.OIL] = 1000
	wallet[Economy.Res.IRON] = 1000
	var unit = game._get_team_units(0)[0]
	var hp_before: int = int(unit.effective_max_hp())
	assert_true(game.apply_command({"type": "tech", "team": 0, "id": "reactive_armor"}))
	assert_true(game.team_has_tech(0, "reactive_armor"))
	assert_gt(unit.effective_max_hp(), hp_before)

func test_fortification_command_requires_worker_and_registers_block():
	var game := _new_game()
	var hq: Node2D = game._find_team_hq(0)
	var target: Vector2 = hq.global_position + Vector2(128, 128)
	assert_false(game.apply_command({
		"type": "fortify", "team": 0, "id": "wall",
		"target_x": target.x, "target_y": target.y,
	}))
	game._spawn_unit_by_id("sapperbot", target + Vector2(16, 0), 0)
	var before := _count_buildings(game, "wall", 0)
	assert_true(game.apply_command({
		"type": "fortify", "team": 0, "id": "wall",
		"target_x": target.x, "target_y": target.y,
	}))
	assert_eq(_count_buildings(game, "wall", 0), before + 1)
	assert_gt(GameManager.fort_blocks.size(), 0)

func test_deposit_harvest_credits_nearby_extractor():
	var game := _new_game()
	assert_gt(game.resource_deposits.size(), 0)
	var rd: Dictionary = game.resource_deposits[0]
	var dep: ResourceDeposit = rd["deposit"]
	var pos: Vector2 = rd["pos"]
	game._spawn_building_by_id("extractor", pos, 1)
	var amount_before := dep.amount
	var wallet_before := int(ResourceManager.get_wallet(1).get(dep.type, 0))
	game._harvest_deposits(1.0)
	assert_lt(dep.amount, amount_before)
	assert_gt(int(ResourceManager.get_wallet(1).get(dep.type, 0)), wallet_before)

func test_quicksave_restores_match_state_buildings_tech_and_deposits():
	var path := "user://saves/test_roadmap_save.bws"
	var game := _new_game()
	game.elapsed_time = 12.5
	game.team_unlocked_tech[0] = ["reactive_armor"]
	var extra: Node2D = game._spawn_unit_by_id("rocketbot", Vector2(410, 330), 0)
	extra.hp = 7
	var extra_building: Node2D = game._spawn_building_by_id("research_lab", Vector2(470, 330), 0)
	extra_building.hp = 33
	ResourceManager.get_wallet(0)[Economy.Res.OIL] = 777
	var dep: ResourceDeposit = game.resource_deposits[0]["deposit"]
	dep.amount = 123
	assert_eq(game.quicksave_match(path), OK)

	game.team_unlocked_tech[0] = []
	extra.hp = 99
	extra_building.hp = 500
	ResourceManager.get_wallet(0)[Economy.Res.OIL] = 0
	dep.amount = 999
	assert_true(game.quickload_match(path))
	assert_almost_eq(game.elapsed_time, 12.5, 0.01)
	assert_true(game.team_has_tech(0, "reactive_armor"))
	assert_eq(int(ResourceManager.get_wallet(0).get(Economy.Res.OIL, 0)), 777)
	assert_eq(int((game.resource_deposits[0]["deposit"] as ResourceDeposit).amount), 123)
	var restored_unit := false
	for u in game._get_team_units(0):
		if u.stats != null and u.stats.id == "rocketbot" and u.hp == 7:
			restored_unit = true
	assert_true(restored_unit)
	var restored_building := false
	for b in get_tree().get_nodes_in_group("buildings"):
		if is_instance_valid(b) and b.stats != null and b.stats.id == "research_lab" and b.hp == 33:
			restored_building = true
	assert_true(restored_building)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func test_victory_panel_opens_on_production_elimination():
	var game := _new_game()
	game.elapsed_time = 42.0
	assert_false(game.victory_panel.visible)
	for b in get_tree().get_nodes_in_group("buildings"):
		if is_instance_valid(b) and int(b.team) == 1 and b.stats != null and UnitRegistry.is_production_building(b.stats.id):
			b.free()
	game._check_win()
	assert_true(game.match_over)
	assert_true(game.victory_panel.visible)
	var result: Label = game.victory_panel.get_node("VBoxContainer/ResultLabel") as Label
	assert_not_null(result)
	assert_true(String(result.text).contains("VICTORY"))
	assert_gt(game.match_duration, 0.0)

func test_alliance_sides_determine_victory_together():
	var game := _new_game()
	GameManager.teams = [0, 1, 2, 3]
	GameManager.alliances = {0: [0, 2], 1: [1, 3]}
	assert_eq(game._alliance_side_key(2), "0,2")
	assert_true(GameManager.is_allied(2, 0))
	game._spawn_building_by_id("barracks", Vector2(700, 300), 2)
	for b in get_tree().get_nodes_in_group("buildings"):
		if is_instance_valid(b) and (int(b.team) == 1 or int(b.team) == 3) and b.stats != null and UnitRegistry.is_production_building(b.stats.id):
			b.free()
	game._check_win()
	assert_true(game.match_over)
	var result: Label = game.victory_panel.get_node("VBoxContainer/ResultLabel") as Label
	assert_true(String(result.text).contains("VICTORY"))

func test_replay_records_and_loads_accepted_commands():
	var game := _new_game()
	assert_true(game.apply_command({"type": "train", "team": 0, "id": "riflebot"}))
	assert_gt(game.replay_log.command_count(), 0)
	assert_eq(game.save_replay(), OK)
	var path := "user://replays/match.json"
	assert_true(FileAccess.file_exists(path))
	var viewer := ReplayViewer.new()
	add_child_autofree(viewer)
	assert_true(viewer.load_replay(path))
	assert_eq(viewer.replay.command_count(), game.replay_log.command_count())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func test_map_editor_reports_load_failure_instead_of_generic_status():
	GameManager.match_mode = GameManager.Mode.MAP_EDITOR
	var editor = preload("res://scenes/map_editor.tscn").instantiate()
	add_child_autofree(editor)
	editor.map_path_edit.text = "user://maps/this_map_does_not_exist.bwm"
	editor._load_map()
	assert_true(String(editor.status_label.text).contains("Load failed"))
	assert_true(String(editor.status_label.text).contains("this_map_does_not_exist.bwm"))
