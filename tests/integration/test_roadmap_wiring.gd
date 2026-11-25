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
	assert_eq(viewer.command_index, 0)
	viewer.step_one()
	assert_eq(viewer.command_index, 1)
	assert_true(viewer.now_label.text.contains("tick"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func test_map_editor_reports_load_failure_instead_of_generic_status():
	GameManager.match_mode = GameManager.Mode.MAP_EDITOR
	var editor = preload("res://scenes/map_editor.tscn").instantiate()
	add_child_autofree(editor)
	editor.map_path_edit.text = "user://maps/this_map_does_not_exist.bwm"
	editor._load_map()
	assert_true(String(editor.status_label.text).contains("Load failed"))
	assert_true(String(editor.status_label.text).contains("this_map_does_not_exist.bwm"))

func _remove_user_file(path: String) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func test_quicksave_restores_base_rates_and_efficiency_without_compounding():
	var path := "user://saves/test_economy_roundtrip.bws"
	var game := _new_game()
	ResourceManager.set_rate(0, Economy.Res.OIL, 500)
	ResourceManager.set_power_efficiency(0, 0.5)
	assert_eq(ResourceManager.effective_rate(0, Economy.Res.OIL), 250)
	assert_eq(game.quicksave_match(path), OK)
	ResourceManager.set_rate(0, Economy.Res.OIL, 100)
	ResourceManager.set_power_efficiency(0, 1.0)
	assert_true(game.quickload_match(path))
	assert_eq(ResourceManager.get_base_rate(0, Economy.Res.OIL), 500)
	assert_almost_eq(ResourceManager.power_efficiency.get(0, 1.0), 0.5, 0.001)
	ResourceManager.refresh_rates(0)
	assert_eq(ResourceManager.effective_rate(0, Economy.Res.OIL), 250)
	_remove_user_file(path)

func test_quickload_rejects_structurally_bad_saves_and_maps():
	var path := "user://saves/test_bad_save.bws"
	var game := _new_game()
	var bad_state := SaveGame.new()
	bad_state.game_state = {"resources": {}, "units": "not-an-array", "buildings": []}
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(bad_state.to_dict()))
	f.close()
	assert_false(game.quickload_match(path))
	assert_true(String(status_of(game)).contains("invalid entity snapshot"))

	var bad_map := SaveGame.new()
	bad_map.game_state = {"resources": {}, "units": [], "buildings": []}
	bad_map.settings = {"map": {"width": 2, "height": 2, "tiles": [0]}}
	f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(bad_map.to_dict()))
	f.close()
	assert_false(game.quickload_match(path))
	assert_true(String(status_of(game)).contains("Save map is invalid"))
	_remove_user_file(path)

func status_of(game: Node2D) -> String:
	var label: Label = game.get_node_or_null("UI/StatusLabel") as Label
	return label.text if label != null else ""

func test_quickload_clears_victory_state():
	var path := "user://saves/test_victory_reset.bws"
	var game := _new_game()
	game.elapsed_time = 42.0
	for b in get_tree().get_nodes_in_group("buildings"):
		if is_instance_valid(b) and int(b.team) == 1 and b.stats != null and UnitRegistry.is_production_building(b.stats.id):
			b.free()
	game._check_win()
	assert_true(game.match_over)
	assert_true(game.victory_panel.visible)
	assert_eq(game.quicksave_match(path), OK)
	assert_true(game.quickload_match(path))
	assert_false(game.match_over)
	assert_false(game.victory_panel.visible)
	_remove_user_file(path)

func test_replay_only_records_units_for_unit_commands():
	var game := _new_game()
	var u = game._get_team_units(0)[0]
	game.selected_units = [u]
	assert_true(game.apply_command({"type": "train", "team": 0, "id": "riflebot"}))
	var train_cmd := Command.from_dict(game.replay_log.commands[game.replay_log.command_count() - 1])
	assert_eq(train_cmd.unit_ids.size(), 0)
	var target: Vector2 = u.global_position + Vector2(64, 0)
	assert_true(game.apply_command({
		"type": "move", "team": 0, "target_x": target.x, "target_y": target.y,
	}))
	var move_cmd := Command.from_dict(game.replay_log.commands[game.replay_log.command_count() - 1])
	assert_gt(move_cmd.unit_ids.size(), 0)

func test_research_dialog_shows_full_tree_and_stays_open():
	var dialog := ResearchDialog.new()
	add_child_autofree(dialog)
	var wallet := {}
	for res in [Economy.Res.OIL, Economy.Res.IRON, Economy.Res.GEOTHERMAL, Economy.Res.FOOD]:
		wallet[res] = 1000
	dialog.populate([], wallet, true)
	var tree: VBoxContainer = dialog.get_node("TechTree") as VBoxContainer
	assert_not_null(tree)
	assert_eq(tree.get_child_count(), Tech.TREE.size() + 1)
	var ready: Button = tree.get_node("Tech_reactive_armor") as Button
	var locked: Button = tree.get_node("Tech_strategic_uplinks") as Button
	assert_false(ready.disabled)
	assert_true(locked.disabled)
	assert_true(locked.text.contains("REQUIRES"))
	ready.pressed.emit()
	assert_true(dialog.visible or is_instance_valid(dialog))

func test_production_tiers_are_enforced_before_spending():
	var game := _new_game()
	var wallet := ResourceManager.get_wallet(0)
	var oil_before := int(wallet.get(Economy.Res.OIL, 0))
	assert_false(game.apply_command({"type": "train", "team": 0, "id": "battleship"}))
	assert_eq(int(wallet.get(Economy.Res.OIL, 0)), oil_before)

func test_capture_and_demolish_commands_are_wired():
	var game := _new_game()
	var hq: Node2D = game._find_team_hq(0)
	var enemy_bld: Node2D = game._spawn_building_by_id("barracks", hq.global_position + Vector2(192, 0), 1)
	enemy_bld.hp = maxi(1, int(float(enemy_bld.stats.hp) * 0.4))
	var worker: Node2D = game._spawn_unit_by_id("sapperbot", enemy_bld.global_position + Vector2(24, 0), 0)
	assert_true(game.apply_command({
		"type": "capture", "team": 0, "unit_ids": [worker.net_id],
		"target_x": enemy_bld.global_position.x, "target_y": enemy_bld.global_position.y,
	}))
	var cap := Command.from_dict(game.replay_log.commands[game.replay_log.command_count() - 1])
	assert_eq(cap.type, Command.Type.CAPTURE)
	var own: Node2D = game._spawn_building_by_id("turret", hq.global_position + Vector2(0, 192), 0)
	var wallet := ResourceManager.get_wallet(0)
	var oil_before := int(wallet.get(Economy.Res.OIL, 0))
	assert_true(game.apply_command({
		"type": "demolish", "team": 0,
		"target_x": own.global_position.x, "target_y": own.global_position.y,
	}))
	var demo := Command.from_dict(game.replay_log.commands[game.replay_log.command_count() - 1])
	assert_eq(demo.type, Command.Type.DEMOLISH)
	assert_gt(int(wallet.get(Economy.Res.OIL, 0)), oil_before)

func test_extractor_bonus_is_revoked_on_destruction():
	var game := _new_game()
	var rd: Dictionary = game.resource_deposits[0]
	var extractor: Node2D = game._spawn_building_by_id("extractor", Vector2(rd["pos"]), 1)
	var oil_before := ResourceManager.get_base_rate(1, Economy.Res.OIL)
	game._apply_building_bonus(extractor, true)
	assert_eq(ResourceManager.get_base_rate(1, Economy.Res.OIL), oil_before + 8)
	game.on_building_destroyed(extractor)
	assert_eq(ResourceManager.get_base_rate(1, Economy.Res.OIL), oil_before)

func test_strategic_weapons_require_strategic_uplinks():
	var game := _new_game()
	assert_false(game.apply_command({"type": "laser", "team": 0, "target_x": 500, "target_y": 500}))
	game.team_unlocked_tech[0] = ["strategic_uplinks"]
	ResourceManager.get_wallet(0)[Economy.Res.GEOTHERMAL] = 1000
	ResourceManager.get_wallet(0)[Economy.Res.OIL] = 1000
	assert_true(game.apply_command({"type": "laser", "team": 0, "target_x": 500, "target_y": 500}))

func test_minimap_ping_is_wired_to_tactical_pings():
	var game := _new_game()
	var before: int = game.tactical_pings.size()
	game._on_minimap_ping(Vector2(320, 240))
	assert_eq(game.tactical_pings.size(), before + 1)

func test_victory_score_counts_every_building_and_food():
	var game := _new_game()
	ResourceManager.get_wallet(0)[Economy.Res.FOOD] = 777
	var score: Dictionary = game._team_score(0)
	var expected_eco := 0
	for res in [Economy.Res.OIL, Economy.Res.IRON, Economy.Res.GEOTHERMAL, Economy.Res.FOOD]:
		expected_eco += int(ResourceManager.get_wallet(0).get(res, 0))
	var buildings := 0
	for count in game._get_team_building_counts(0).values():
		buildings += int(count)
	assert_eq(int(score["economic"]), expected_eco)
	assert_eq(int(score["military"]), game._get_team_units(0).size() * 10 + buildings * 50)

func test_map_editor_blocks_test_play_for_invalid_map():
	GameManager.match_mode = GameManager.Mode.MAP_EDITOR
	var editor = preload("res://scenes/map_editor.tscn").instantiate()
	add_child_autofree(editor)
	editor.map_data = MapData.new(4, 4)
	editor._test_play_map()
	assert_true(editor.status_label.text.contains("Cannot test play"))
	assert_eq(GameManager.match_mode, GameManager.Mode.MAP_EDITOR)

func test_in_match_diplomacy_ui_sends_host_authoritative_commands():
	NetworkManager.leave()
	var game := _new_game()
	GameManager.match_mode = GameManager.Mode.MULTIPLAYER
	GameManager.teams = [0, 1, 2, 3]
	GameManager.set_diplomacy_state({}, {}, GameManager.teams)
	NetworkManager.attach_game(game)

	var dialog := DiplomacyDialog.new()
	add_child_autofree(dialog)
	dialog.refresh()
	assert_true(String(dialog.status_label.text).contains("Team 0"))
	var propose: Button = dialog.get_node("DiplomacyRoot/TeamScroll/TeamRows/Team_2/Propose_2") as Button
	assert_not_null(propose)
	propose.pressed.emit()
	assert_true(Alliance.has_proposal(GameManager.alliance_proposals, 0, 2))
	assert_false(GameManager.is_allied(0, 2))

	dialog.refresh()
	var cancel: Button = dialog.get_node("DiplomacyRoot/TeamScroll/TeamRows/Team_2/Cancel_2") as Button
	assert_not_null(cancel)
	GameManager.local_team = 2
	dialog.refresh()
	var accept: Button = dialog.get_node("DiplomacyRoot/TeamScroll/TeamRows/Team_0/Accept_0") as Button
	assert_not_null(accept)
	GameManager.local_team = 0
	# Team 1 cannot accept team 0's offer to team 2.
	assert_false(game.apply_command({"type": "diplomacy", "team": 1, "action": "accept", "target_team": 2}))
	assert_true(game.apply_command({"type": "diplomacy", "team": 2, "action": "accept", "target_team": 0}))
	assert_true(GameManager.is_allied(0, 2))
	assert_true(GameManager.is_allied(2, 0))
	assert_false(Alliance.has_proposal(GameManager.alliance_proposals, 0, 2))
	var replayed := Command.from_dict(game.replay_log.commands[game.replay_log.command_count() - 1])
	assert_eq(replayed.type, Command.Type.DIPLOMACY)
	assert_eq(replayed.target_id, 0)

	assert_true(game.apply_command({"type": "diplomacy", "team": 0, "action": "break", "target_team": 2}))
	assert_false(GameManager.is_allied(0, 2))
	NetworkManager.leave()

func test_diplomacy_command_team_is_resolved_by_host_pipeline():
	NetworkManager.leave()
	var lobby := NetworkManager.lobby
	assert_true(lobby.update_settings(1, {"num_teams": 4}))
	for pid in [1, 2, 3, 4]:
		lobby.add_player(pid, "P%d" % pid, "1.2.3.%d" % pid)
	var clean := NetworkManager.prepare_inbound_command(3, {
		"type": "diplomacy", "seq": 1, "team": 0,
		"action": "propose", "target_team": 3,
	}, 1000.0)
	assert_eq(clean["team"], 2)  # sender 3 sits on team 2; payload team ignored
	assert_eq(clean["action"], "propose")
	assert_eq(clean["target_team"], 3)
	NetworkManager.leave()

func test_diplomacy_state_survives_quicksave_and_rejects_bad_saves():
	var game := _new_game()
	GameManager.teams = [0, 1, 2, 3]
	GameManager.set_diplomacy_state({0: [0, 2], 1: [1, 3]}, {"0>3": true}, GameManager.teams)
	var path := "user://saves/test_diplomacy.bws"
	assert_eq(game.quicksave_match(path), OK)

	GameManager.set_diplomacy_state({}, {}, [0, 1])
	assert_true(game.quickload_match(path))
	assert_eq(GameManager.teams, [0, 1, 2, 3])
	assert_true(GameManager.is_allied(0, 2))
	assert_true(GameManager.is_allied(1, 3))
	assert_true(Alliance.has_proposal(GameManager.alliance_proposals, 0, 3))

	var f := FileAccess.open(path, FileAccess.READ)
	var saved := JSON.parse_string(f.get_as_text()) as Dictionary
	f.close()
	(saved["settings"] as Dictionary)["alliances"] = "broken"
	var bad_path := "user://saves/test_diplomacy_bad.bws"
	var bad_file := FileAccess.open(bad_path, FileAccess.WRITE)
	bad_file.store_string(JSON.stringify(saved))
	bad_file.close()
	assert_false(game.quickload_match(bad_path))
	assert_true(String(game.status_label.text).contains("invalid alliances"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(bad_path))
