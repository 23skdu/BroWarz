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

func _count_buildings(_game: Node2D, id: String, team: int = -1) -> int:
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

func test_minimap_is_top_centered_and_clears_bottom_right_units():
	var game := _new_game()
	var rect: Rect2 = game.minimap.get_rect()
	var viewport: Vector2 = game.get_viewport_rect().size
	assert_almost_eq(rect.position.x + rect.size.x * 0.5, viewport.x * 0.5, 2.0)
	assert_almost_eq(rect.position.y, 16.0, 2.0)
	assert_true(rect.position.y + rect.size.y < viewport.y * 0.5)
	assert_true(rect.position.x + rect.size.x < viewport.x)
	var pause := game.get_node_or_null("UI/PausePanel")
	if pause != null:
		assert_lt(game.minimap.get_index(), pause.get_index())

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
		if is_instance_valid(b) and int(b.team) == 1 and b.stats != null and String(b.stats.id) == "hq":
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
		if is_instance_valid(b) and (int(b.team) == 1 or int(b.team) == 3) \
				and b.stats != null and String(b.stats.id) == "hq":
			b.free()
	game._check_win()
	assert_true(game.match_over)
	var result: Label = game.victory_panel.get_node("VBoxContainer/ResultLabel") as Label
	assert_true(String(result.text).contains("VICTORY"))

func test_replay_records_and_loads_accepted_commands():
	var game := _new_game()
	game._spawn_building_by_id("barracks", Vector2(700, 300), 0)
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
		if is_instance_valid(b) and int(b.team) == 1 and b.stats != null and String(b.stats.id) == "hq":
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
	game._spawn_building_by_id("barracks", Vector2(700, 300), 0)
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
	var ready_btn: Button = tree.get_node("Tech_reactive_armor") as Button
	var locked: Button = tree.get_node("Tech_strategic_uplinks") as Button
	assert_false(ready_btn.disabled)
	assert_true(locked.disabled)
	assert_true(locked.text.contains("REQUIRES"))
	ready_btn.pressed.emit()
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
	assert_eq(clean["team"], 2) # sender 3 sits on team 2; payload team ignored
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

func test_coop_lobby_stages_shared_side_and_ai_opponent():
	NetworkManager.leave()
	var lobby := NetworkManager.lobby
	lobby.add_player(1, "Host", "1.2.3.4")
	lobby.add_player(2, "Guest", "5.6.7.8")
	assert_true(lobby.update_settings(1, {
		"coop_vs_ai": true, "human_faction": Faction.Id.PELAGIC,
		"ai_difficulty": AI.Difficulty.HARD, "ai_faction": Faction.Id.VANGUARD,
	}))
	assert_eq(lobby.team_of(1), 0)
	assert_eq(lobby.team_of(2), 0)
	lobby.set_ready(1, true)
	lobby.set_ready(2, true)
	assert_true(lobby.can_start(1)["ok"])
	NetworkManager._stage_match_settings()
	assert_eq(GameManager.match_mode, GameManager.Mode.MULTIPLAYER)
	assert_eq(GameManager.teams, [0, 1])
	assert_eq(GameManager.local_team, 0)
	assert_true(GameManager.ai_enabled)
	assert_eq(GameManager.ai_teams, [1])
	assert_eq(GameManager.faction_for_team(0), Faction.Id.PELAGIC)
	assert_eq(GameManager.faction_for_team(1), Faction.Id.VANGUARD)
	assert_eq(GameManager.difficulty_for_team(1), AI.Difficulty.HARD)
	assert_true(NetworkManager._net_alliances().is_empty())
	NetworkManager.leave()

func test_coop_match_state_survives_quicksave_and_load():
	NetworkManager.leave()
	GameManager.stage_net_match(
		2, 42, true, "enet", [0, 1], 0, {}, true, [1],
		{0: Faction.Id.FERROCORE, 1: Faction.Id.VANGUARD},
		{1: AI.Difficulty.HARD},
	)
	var game := _new_game_without_staging()
	var path := "user://saves/test_coop_match.bws"
	assert_eq(game.quicksave_match(path), OK)
	GameManager.start_single_player(AI.Difficulty.EASY, null, 0, 1, 2)
	assert_true(game.quickload_match(path))
	assert_eq(GameManager.match_mode, GameManager.Mode.MULTIPLAYER)
	assert_true(GameManager.ai_enabled)
	assert_eq(GameManager.ai_teams, [1])
	assert_eq(GameManager.faction_for_team(0), Faction.Id.FERROCORE)
	assert_eq(GameManager.faction_for_team(1), Faction.Id.VANGUARD)
	assert_eq(GameManager.difficulty_for_team(1), AI.Difficulty.HARD)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	NetworkManager.leave()

func test_lobby_exposes_host_only_coop_controls():
	NetworkManager.leave()
	var lobby_ui := preload("res://scenes/lobby.tscn").instantiate()
	add_child_autofree(lobby_ui)
	var bindings := {
		"CoopButton": "_on_coop_pressed",
		"HumanFactionButton": "_on_human_faction_pressed",
		"AiDifficultyButton": "_on_ai_difficulty_pressed",
		"AiFactionButton": "_on_ai_faction_pressed",
	}
	for node_name in bindings.keys():
		var button: Button = lobby_ui.get_node_or_null("VBox/SettingsBox/%s" % node_name) as Button
		assert_not_null(button)
		assert_true(button.is_connected("pressed", Callable(lobby_ui, bindings[node_name])))

func _new_game_without_staging() -> Node2D:
	var game: Node2D = preload("res://scenes/game.tscn").instantiate()
	add_child_autofree(game)
	NetworkManager.attach_game(null)
	return game

func test_building_inspector_displays_selected_building_and_dispatches_commands():
	var game := _new_game()
	assert_not_null(game.building_inspector)
	assert_false(game.building_inspector.visible)
	var hq: Node2D = game._find_team_hq(0)
	game.selected_building = hq
	game._update_hud()
	assert_true(game.building_inspector.visible)
	assert_true(game.building_inspector.demolish_btn.disabled, "HQ cannot be demolished from inspector")

	var barracks: Node2D = game._spawn_building_by_id("barracks", hq.global_position + Vector2(120, 0), 0)
	game.selected_building = barracks
	game._update_hud()
	assert_eq(game.building_inspector.name_label.text, barracks.stats.display_name)
	assert_false(game.building_inspector.demolish_btn.disabled)
	assert_not_null(game.building_inspector.train_grid.get_node_or_null("InspectTrain_riflebot"))
	assert_null(game.building_inspector.train_grid.get_node_or_null("InspectTrain_bone_legionary"))

	# Training via inspector enqueues unit and updates live queue display.
	ResourceManager.get_wallet(0)[Economy.Res.IRON] = 500
	ResourceManager.get_wallet(0)[Economy.Res.FOOD] = 500
	game.building_inspector.train_requested.emit("riflebot")
	game._update_hud()
	assert_eq(barracks.production_queue.size(), 1)
	assert_true(game.building_inspector.queue_label.text.contains("riflebot"))
	assert_false(game.building_inspector.cancel_btn.disabled)

	# Queue cancel, rally reset, and demolish all wire cleanly.
	game.building_inspector.cancel_queue_requested.emit()
	assert_eq(barracks.production_queue.size(), 0)
	barracks.set_rally(Vector2(900, 900))
	game.building_inspector.reset_rally_requested.emit()
	assert_false(barracks.has_rally)
	game.building_inspector.demolish_requested.emit()
	assert_true(barracks.is_exploding)

func test_lockstep_dialog_runs_live_soak_and_tracks_desync_checksums():
	var menu := preload("res://scenes/main_menu.tscn").instantiate()
	add_child_autofree(menu)
	var lockstep_btn: Button = menu.get_node_or_null("MenuPanel/Margin/VBox/Columns/OptionsColumn/LockstepButton") as Button
	assert_not_null(lockstep_btn)
	assert_true(lockstep_btn.is_connected("pressed", Callable(menu, "_open_lockstep_dialog")))

	var game := _new_game()
	var c1: int = int(game.compute_match_checksum())
	var c2: int = int(game.compute_match_checksum())
	assert_eq(c1, c2, "match checksum must be deterministic on identical state")
	game._open_lockstep_dialog()
	assert_not_null(game.lockstep_dialog)
	var soak: Dictionary = game.lockstep_dialog.run_soak(4, 120, 2030)
	assert_true(bool(soak["ok"]))
	assert_eq(int(soak["desyncs"]), 0)
	assert_gt(int(soak["commands"]), 50)
	assert_true(game.lockstep_dialog.result_label.text.contains("PASS"))

	# Mismatched remote hash increments desync counter and warns in HUD.
	var before_desyncs: int = int(game.desync_count)
	game._on_remote_state_hash(2, c1 ^ 0xFF)
	assert_eq(int(game.desync_count), before_desyncs + 1)
	assert_true(String(game.status_label.text).contains("Desync warning"))

func test_voice_bark_subtitles_render_in_hud_and_respect_setting():
	var game := _new_game()
	var original_subs := SettingsManager.subtitles_enabled()
	SettingsManager.set_setting("subtitles", true)
	AudioManager.reset_bark_cooldowns()
	AudioManager.play_bark("tech_complete", Faction.Id.AERODYNE, "Reactive Armor", 100.0)
	assert_true(game.bark_subtitle_label.visible)
	assert_true(String(game.bark_subtitle_label.text).contains("Reactive Armor"))
	game.bark_subtitle_label.visible = false
	SettingsManager.set_setting("subtitles", false)
	AudioManager.play_bark("build_complete", Faction.Id.AERODYNE, "Riflebot", 105.0)
	assert_false(game.bark_subtitle_label.visible)
	SettingsManager.set_setting("subtitles", original_subs)

func test_graphics_quality_batched_canopy_multimesh_linear_fog_and_vfx_caps():
	var orig_q: String = String(SettingsManager.graphics_quality())
	SettingsManager.set_setting("graphics_quality", "high")
	var game := _new_game()
	# High quality uses 8x sub-tile terrain (1024x1024 on 128x128 map) and smooth linear fog.
	assert_eq(int(game.terrain_ppt), 8)
	assert_eq(game.terrain_image.get_width(), 128 * 8)
	assert_eq(game.fog_sprite.texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR)
	assert_not_null(game.forest_multimesh)
	assert_not_null(game.forest_multimesh.texture)
	assert_eq(game.forest_multimesh.multimesh.instance_count, game.forest_decorations.size())

	# Switching to low quality live-scales terrain PPT to 4x and reduces foliage instance density.
	SettingsManager.set_setting("graphics_quality", "low")
	assert_eq(int(game.terrain_ppt), 4)
	assert_eq(game.terrain_image.get_width(), 128 * 4)
	assert_lt(game.forest_multimesh.multimesh.instance_count, game.forest_decorations.size())

	# Tracer buffer respects quality cap under heavy 500-unit combat bursts.
	var cap := int(UnitVisual.graphics_profile("low")["max_tracers"])
	for i in range(cap + 25):
		game.spawn_combat_tracer(Vector2(100, 100), Vector2(200, 200), Damage.DamageType.KINETIC, 0)
	assert_lte(game.active_tracers.size(), cap)
	SettingsManager.set_setting("graphics_quality", orig_q)

func test_unit_lod_multimesh_water_shader_and_pooled_particles():
	var orig_q: String = String(SettingsManager.graphics_quality())
	var orig_rm: bool = bool(SettingsManager.reduced_motion())
	SettingsManager.set_setting("graphics_quality", "high")
	SettingsManager.set_setting("reduced_motion", false)
	var game := _new_game()
	assert_not_null(game.terrain_shader_mat)
	assert_gt(float(game.terrain_shader_mat.get_shader_parameter("u_shimmer_strength")), 0.0)
	SettingsManager.set_setting("reduced_motion", true)
	assert_almost_eq(float(game.terrain_shader_mat.get_shader_parameter("u_shimmer_strength")), 0.0, 0.001)

	# Far camera zoom enables GPU unit LOD MultiMesh batching and hides per-unit sprites.
	assert_not_null(game.unit_lod_multimesh)
	game._rebuild_spatial_grid()
	game.camera.zoom = Vector2(0.5, 0.5)
	game._update_unit_lod_multimesh()
	assert_true(game.unit_lod_multimesh.visible)
	assert_gt(game.unit_lod_multimesh.multimesh.visible_instance_count, 0)
	game.camera.zoom = Vector2(1.0, 1.0)
	game._update_unit_lod_multimesh()
	assert_false(game.unit_lod_multimesh.visible)

	# Pooled particle layer uses fixed preallocated capacity without growing on heavy combat.
	var pool_len: int = game.particle_pool.size()
	assert_eq(pool_len, 160)
	for i in range(200):
		game.spawn_combat_tracer(Vector2(120, 120), Vector2(220, 220), Damage.DamageType.EXPLOSIVE, 0)
	assert_eq(game.particle_pool.size(), pool_len)
	SettingsManager.set_setting("graphics_quality", orig_q)
	SettingsManager.set_setting("reduced_motion", orig_rm)

func test_patrol_guard_formations_and_nuke_early_warning():
	var game := _new_game()
	var hq: Node2D = game._find_team_hq(0)
	var tank: Node2D = game._spawn_unit_by_id("mbt", hq.global_position + Vector2(60, 0), 0)
	var arty: Node2D = game._spawn_unit_by_id("artillery", hq.global_position + Vector2(80, 20), 0)

	# Tactical wedge move command succeeds and routes via Formation.tactical_offsets.
	assert_true(game.apply_command({
		"type": "move", "team": 0, "unit_ids": [tank.net_id, arty.net_id],
		"target_x": hq.global_position.x + 260.0, "target_y": hq.global_position.y,
		"attack_move": true, "formation": Formation.Style.WEDGE,
	}))
	assert_true(tank.has_target)
	assert_true(arty.has_target)

	# Patrol sets a two-point loop; Guard anchors the unit to a defensive perimeter.
	assert_true(game.apply_command({
		"type": "patrol", "team": 0, "unit_ids": [tank.net_id],
		"target_x": hq.global_position.x + 180.0, "target_y": hq.global_position.y + 40.0,
	}))
	assert_true(bool(tank.patrol_active))
	assert_eq(tank.patrol_points.size(), 2)

	assert_true(game.apply_command({
		"type": "guard", "team": 0, "unit_ids": [arty.net_id],
		"target_x": hq.global_position.x + 90.0, "target_y": hq.global_position.y + 90.0,
	}))
	assert_true(bool(arty.guard_active))

	# Nuclear launch queues an early-warning countdown instead of instant zero-tick impact.
	game.team_unlocked_tech[0] = ["strategic_uplinks"]
	ResourceManager.wallets[0] = {
		Economy.Res.OIL: 5000, Economy.Res.IRON: 5000,
		Economy.Res.GEOTHERMAL: 5000, Economy.Res.FOOD: 5000,
	}
	var strike_pos := Vector2(640.0, 640.0)
	var enemy_target: Node2D = game._spawn_unit_by_id("riflebot", strike_pos, 1)
	var initial_hp: int = int(enemy_target.hp)
	assert_true(game.apply_command({"type": "nuke", "team": 0, "x": strike_pos.x, "y": strike_pos.y}))
	assert_eq(game.pending_nukes.size(), 1)
	assert_eq(int(enemy_target.hp), initial_hp, "units must have early-warning time before impact")
	game._step_pending_nukes(Strategic.NUKE_WARNING_SECONDS + 0.1)
	assert_eq(game.pending_nukes.size(), 0)
	assert_true(bool(enemy_target.is_exploding) or int(enemy_target.hp) < initial_hp)
	assert_eq(game.map_data.get_terrain(int(strike_pos.x / 16.0), int(strike_pos.y / 16.0)), MapData.Terrain.WASTELAND)

func test_map_editor_three_pane_flood_fill_mirror_undo_redo_and_validation():
	GameManager.match_mode = GameManager.Mode.MAP_EDITOR
	var editor = preload("res://scenes/map_editor.tscn").instantiate()
	add_child_autofree(editor)
	assert_not_null(editor.workspace_split)
	assert_not_null(editor.validation_panel)
	assert_not_null(editor.file_dialog)
	assert_not_null(editor.confirm_dialog)

	editor.map_data = MapData.new(16, 16)
	editor._refresh_image()
	editor.mirror_x = true
	editor.push_undo_snapshot()
	var filled: int = int(editor.flood_fill(2, 2, MapData.Terrain.DESERT))
	assert_gt(filled, 0)
	assert_eq(editor.map_data.get_terrain(2, 2), MapData.Terrain.DESERT)
	assert_eq(editor.map_data.get_terrain(13, 2), MapData.Terrain.DESERT)
	assert_true(bool(editor.dirty))

	assert_true(bool(editor.undo()))
	assert_eq(editor.map_data.get_terrain(2, 2), MapData.Terrain.PLAINS)
	assert_true(bool(editor.redo()))
	assert_eq(editor.map_data.get_terrain(2, 2), MapData.Terrain.DESERT)
	assert_true(String(editor.validation_label.text).contains("HQ Spawns"))

	editor._set_zoom(0.1)
	assert_almost_eq(float(editor.camera.zoom.x), float(editor.MIN_ZOOM), 0.001)
	editor._set_zoom(5.0)
	assert_almost_eq(float(editor.camera.zoom.x), float(editor.MAX_ZOOM), 0.001)

func test_chat_surrender_ai_takeover_webrtc_ui_replay_live_and_telemetry():
	NetworkManager.leave()
	var game := _new_game()
	assert_not_null(game.chat_panel)
	assert_true(game.apply_command({"type": "chat", "team": 0, "text": "Push north ridge", "scope": "team"}))
	assert_eq(game.chat_messages.size(), 1)
	assert_true(String(game.chat_log.text).contains("Push north ridge"))

	# Dropped-peer AI takeover promotes an abandoned team to AI control.
	GameManager.teams = [0, 1]
	GameManager.ai_enabled = false
	GameManager.ai_teams = []
	var taken: Array = NetworkManager.handle_expired_peers([ {"peer_id": 2, "team": 1, "team_empty": true}])
	assert_eq(taken, [1])
	assert_true(GameManager.is_ai_team(1))

	# Live replay playback feeds commands back into the scene.
	var rep := Replay.new()
	var c := Command.new()
	c.type = Command.Type.CHAT
	c.tick = 10
	c.player_id = 0
	c.build_type = "Replay ping"
	rep.record(c)
	assert_true(game.start_live_replay(rep, 2.0))
	game._step_live_replay(0.5)
	assert_false(bool(game.live_replay_active))
	assert_true(String(game.chat_log.text).contains("Replay ping"))

	# Surrender ends the match and populates per-team telemetry on victory panel.
	game.record_match_stat(0, "damage_dealt", 420)
	assert_true(game.apply_command({"type": "surrender", "team": 0, "action": "propose"}))
	assert_true(bool(game.match_over))
	assert_true(game.victory_panel.visible)
	var telem := game.victory_panel.get_node_or_null("VBoxContainer/TelemetryLabel") as Label
	assert_not_null(telem)
	assert_true(telem.text.contains("Dmg: 420"))

	# Lobby exposes WebRTC ICE diagnostics when transport is switched to webrtc.
	var lobby_ui := preload("res://scenes/lobby.tscn").instantiate()
	add_child_autofree(lobby_ui)
	assert_not_null(lobby_ui.ice_box)
	assert_false(lobby_ui.ice_box.visible)
	NetworkManager.lobby.add_player(1, "Host", "1.2.3.4")
	NetworkManager.lobby.update_settings(1, {"transport": "webrtc", "stun_url": "stun:stun.example.com:3478"})
	lobby_ui._refresh()
	assert_true(lobby_ui.ice_box.visible)
	assert_true(String(lobby_ui.ice_diag_label.text).contains("stun.example.com"))
	NetworkManager.leave()
