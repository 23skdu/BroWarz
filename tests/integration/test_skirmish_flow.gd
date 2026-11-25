# tests/integration/test_skirmish_flow.gd
extends GutTest

## The main menu must expose a logo and wire the skirmish button to the
## single-player handler that starts the AI match.
func test_main_menu_skirmish_button_is_wired():
	var menu := preload("res://scenes/main_menu.tscn").instantiate()
	add_child_autofree(menu)
	var button: Button = menu.get_node("MenuPanel/Margin/VBox/Columns/PlayColumn/SkirmishButton")
	assert_true(button.is_connected("pressed", Callable(menu, "_on_skirmish")))
	var spectator: Button = menu.get_node("MenuPanel/Margin/VBox/Columns/PlayColumn/SpectatorButton")
	assert_true(spectator.is_connected("pressed", Callable(menu, "_on_spectator")))
	var spectator_faction: Button = menu.get_node("MenuPanel/Margin/VBox/Columns/OptionsColumn/SpectatorFactionButton")
	assert_true(spectator_faction.is_connected("pressed", Callable(menu, "_on_cycle_spectator_faction")))
	var soundtrack: Button = menu.get_node("MenuPanel/Margin/VBox/Columns/OptionsColumn/SoundtrackButton")
	assert_true(soundtrack.is_connected("pressed", Callable(menu, "_on_cycle_soundtrack")))
	assert_true(soundtrack.text.contains(AudioManager.soundtrack_label(AudioManager.soundtrack)))
	var logo: TextureRect = menu.get_node("Logo")
	assert_not_null(logo.texture)
	var backdrop: TextureRect = menu.get_node("CamoBackground")
	assert_not_null(backdrop.texture)
	var logo_backdrop: TextureRect = menu.get_node("LogoBackground")
	assert_not_null(logo_backdrop.texture)
	assert_eq(AudioManager.current_music, "menu")

func test_main_menu_camo_covers_the_full_viewport():
	var menu := preload("res://scenes/main_menu.tscn").instantiate()
	add_child_autofree(menu)
	var backdrop: TextureRect = menu.get_node("CamoBackground")
	assert_eq(backdrop.anchor_right, 1.0)
	assert_eq(backdrop.anchor_bottom, 1.0)
	assert_eq(backdrop.offset_left, 0.0)
	assert_eq(backdrop.offset_top, 0.0)
	assert_eq(backdrop.offset_right, 0.0)
	assert_eq(backdrop.offset_bottom, 0.0)
	assert_eq(backdrop.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_COVERED)

func test_main_menu_match_options_are_grouped_together():
	var menu := preload("res://scenes/main_menu.tscn").instantiate()
	add_child_autofree(menu)
	var options: VBoxContainer = menu.get_node("MenuPanel/Margin/VBox/Columns/OptionsColumn")
	for node_name in ["DifficultyButton", "FactionButton", "SpectatorFactionButton", "MapButton", "SoundtrackButton", "SettingsButton", "ReplayButton"]:
		assert_not_null(options.get_node_or_null(node_name))

func test_main_menu_spectator_faction_selectors_change_both_ai_sides():
	var menu := preload("res://scenes/main_menu.tscn").instantiate()
	add_child_autofree(menu)
	var human: int = int(menu.selected_faction)
	var side_a: int = int(menu.selected_spectator_side_a)
	var side_b: int = int(menu.selected_spectator_faction)
	menu._on_cycle_faction()
	menu._on_cycle_spectator_side_a_faction()
	menu._on_cycle_spectator_faction()
	assert_eq(menu.selected_faction, (human + 1) % 4)
	assert_eq(menu.selected_spectator_side_a, (side_a + 1) % 8)
	assert_eq(menu.selected_spectator_faction, (side_b + 1) % 8)
	# Cycling human faction 8 times must never enter NPC faction IDs 4-7.
	for i in range(8):
		menu._on_cycle_faction()
		assert_false(Faction.is_npc(int(menu.selected_faction)))
	# Cycling AI selectors 8 times reaches all NPC factions 4-7.
	var seen_npc := {}
	for i in range(8):
		menu._on_cycle_spectator_faction()
		if Faction.is_npc(int(menu.selected_spectator_faction)):
			seen_npc[int(menu.selected_spectator_faction)] = true
	assert_eq(seen_npc.size(), 4)
	assert_true(String(menu.faction_btn.text).contains(Faction.name_of(menu.selected_faction)))
	assert_true(String(menu.spectator_side_a_btn.text).contains(Faction.name_of(menu.selected_spectator_side_a)))
	assert_true(String(menu.spectator_faction_btn.text).contains(Faction.name_of(menu.selected_spectator_faction)))

func test_menu_music_is_a_looping_ambient_bed():
	AudioManager.set_music("menu")
	var stream: AudioStreamWAV = AudioManager._music_player.stream
	assert_not_null(stream)
	assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD)
	assert_gt(stream.get_length(), 8.0)

func _queued_units(team: int) -> int:
	var total := 0
	for b in get_tree().get_nodes_in_group("buildings"):
		if is_instance_valid(b) and b.team == team:
			total += int(b.production_queue.size())
	return total

func _building_count(team: int) -> int:
	var total := 0
	for b in get_tree().get_nodes_in_group("buildings"):
		if is_instance_valid(b) and b.team == team:
			total += 1
	return total

func test_each_team_starts_with_only_an_hq():
	GameManager.start_single_player(AI.Difficulty.NORMAL, MapData.new(128, 128), 0, 1)
	var game: Node2D = preload("res://scenes/game.tscn").instantiate()
	add_child_autofree(game)
	NetworkManager.attach_game(null)
	for team in GameManager.teams:
		var ids: Array = []
		for b in get_tree().get_nodes_in_group("buildings"):
			if is_instance_valid(b) and b.team == team and b.stats != null:
				ids.append(String(b.stats.id))
		assert_eq(ids, ["hq"], "team %d must start with only an HQ" % team)
	game._check_win()
	assert_false(game.match_over, "an HQ-only opening must not end as a draw")

func test_corvette_deploys_sonar_buoy_that_reveals_only_owner_submarine_contacts():
	GameManager.start_single_player(AI.Difficulty.NORMAL, MapData.new(128, 128), 0, 1)
	var game: Node2D = preload("res://scenes/game.tscn").instantiate()
	add_child_autofree(game)
	NetworkManager.attach_game(null)
	var corvette = game._spawn_unit_by_id("corvette", Vector2(500, 500), 0)
	var sub = game._spawn_unit_by_id("attack_sub", Vector2(680, 500), 1)
	assert_false(game.sonar_reveals(0, sub.global_position))
	assert_false(game.apply_command({
		"type": "sonar_buoy", "team": 0, "unit_ids": [-1],
		"target_x": 680.0, "target_y": 500.0,
	}, true))
	assert_true(game.apply_command({
		"type": "sonar_buoy", "team": 0, "unit_ids": [int(corvette.net_id)],
		"target_x": 680.0, "target_y": 500.0,
	}, true))
	assert_true(game.sonar_reveals(0, sub.global_position))
	assert_false(game.sonar_reveals(1, sub.global_position))
	game.elapsed_time += SonarBuoy.LIFETIME_SEC + 1.0
	game._cleanup_sonar_buoys()
	assert_false(game.sonar_reveals(0, sub.global_position))

func test_powered_radar_reveals_cloaked_contacts():
	GameManager.start_single_player(AI.Difficulty.NORMAL, MapData.new(128, 128), 0, 1)
	var game: Node2D = preload("res://scenes/game.tscn").instantiate()
	add_child_autofree(game)
	NetworkManager.attach_game(null)
	var hq = game._find_team_hq(0)
	var radar = game._spawn_building_by_id("radar", hq.global_position + Vector2(128, 0), 0)
	var contact = game._spawn_unit_by_id("stealthbot", radar.global_position + Vector2(220, 0), 1)
	assert_gt(game.radar_support_range(0, contact.global_position), 0.0)
	var tf = game._refresh_team_fog(0)
	assert_true(game._node_visible_to_team(0, contact, tf))

func test_single_player_ai_turn_is_playable():
	GameManager.start_single_player(AI.Difficulty.NORMAL, MapData.new(128, 128), 0, 1)
	var game: Node2D = preload("res://scenes/game.tscn").instantiate()
	add_child_autofree(game)
	NetworkManager.attach_game(null)

	var queue_before := _queued_units(1)
	var buildings_before := _building_count(1)
	var wallet: Dictionary = ResourceManager.get_wallet(1)
	wallet[Economy.Res.OIL] = 3000
	wallet[Economy.Res.IRON] = 3000
	wallet[Economy.Res.GEOTHERMAL] = 1200

	for i in range(8):
		game.elapsed_time += 2.0
		game._tick_power()
		game._run_skirmish_ai_turn()

	# AI production is enqueued on its buildings; the live building _process
	# loop turns those queues into spawned units.
	assert_gt(_queued_units(1), queue_before)
	assert_gt(_building_count(1), buildings_before)
	assert_gt(game._get_team_units(1).size(), 0)

	# Brownout efficiency must be idempotent: repeated economy ticks must not
	# compound an already-scaled rate down to zero. Let the power grid settle
	# first, since newly built extractors change its balance once.
	game._tick_power()
	var rate_before: int = int(ResourceManager.rates[1].get(Economy.Res.IRON, 0))
	for i in range(10):
		game._tick_power()
	assert_eq(int(ResourceManager.rates[1].get(Economy.Res.IRON, 0)), rate_before)
	assert_gt(rate_before, 0)

func test_world_mouse_position_respects_camera_zoom():
	GameManager.start_single_player(AI.Difficulty.NORMAL, MapData.new(128, 128), 0, 1)
	var game: Node2D = preload("res://scenes/game.tscn").instantiate()
	add_child_autofree(game)
	NetworkManager.attach_game(null)

	game.camera.position = Vector2(640, 480)
	game.camera.zoom = Vector2(0.5, 0.5)
	var center: Vector2 = game.get_viewport_rect().size * 0.5
	var world: Vector2 = game._world_mouse_pos(center)
	assert_almost_eq(world.x, 640.0, 0.01)
	assert_almost_eq(world.y, 480.0, 0.01)

	var offset_world: Vector2 = game._world_mouse_pos(center + Vector2(100, 50))
	assert_almost_eq(offset_world.x, 840.0, 0.01)
	assert_almost_eq(offset_world.y, 580.0, 0.01)

func test_camera_never_zooms_out_past_the_terrain():
	GameManager.start_single_player(AI.Difficulty.NORMAL, MapData.new(128, 128), 0, 1)
	var game: Node2D = preload("res://scenes/game.tscn").instantiate()
	add_child_autofree(game)
	NetworkManager.attach_game(null)

	var view := game.get_viewport_rect().size
	var world: Vector2 = game._map_world_size()
	var minimum := maxf(0.45, maxf(view.x / world.x, view.y / world.y))
	assert_almost_eq(game._min_cover_zoom(), minimum, 0.001)
	assert_true(game.camera.zoom.x >= minimum - 0.001)
	assert_true(game.camera.zoom.y >= minimum - 0.001)
	var zoomed_out: Vector2 = game._clamp_camera_zoom(Vector2(0.05, 0.05))
	assert_true(zoomed_out.x >= minimum - 0.001)
	assert_true(zoomed_out.y >= minimum - 0.001)
	var clamped: Vector2 = game._clamp_camera(Vector2(-9999.0, -9999.0))
	var half_view: Vector2 = view * 0.5 / game.camera.zoom.x
	assert_true(clamped.x >= half_view.x - 0.01)
	assert_true(clamped.y >= half_view.y - 0.01)
	# The spawn camera itself must start inside the map, otherwise the terrain
	# appears only in the bottom-right corner with empty space above and left.
	assert_true(game.camera.position.x >= half_view.x - 0.01)
	assert_true(game.camera.position.y >= half_view.y - 0.01)
	assert_eq(game.camera.limit_left, 0)
	assert_eq(game.camera.limit_top, 0)
	assert_eq(game.camera.limit_right, int(world.x))
	assert_eq(game.camera.limit_bottom, int(world.y))

func test_editor_state_does_not_leak_into_skirmish():
	var editor_map := MapData.new(32, 32)
	editor_map.name = "EditorMap"
	GameManager.match_mode = GameManager.Mode.MAP_EDITOR
	GameManager.map_type = 3
	GameManager.current_map = editor_map

	var menu := preload("res://scenes/main_menu.tscn").instantiate()
	add_child_autofree(menu)
	menu.selected_map_type = 2
	menu._on_cycle_map()
	# Browsing menu options must not mutate global match state.
	assert_eq(GameManager.map_type, 3)

	GameManager.start_single_player(AI.Difficulty.NORMAL, null, 0, 1, 2)
	assert_eq(GameManager.match_mode, GameManager.Mode.SINGLE_PLAYER)
	assert_eq(GameManager.map_type, 2)
	var game: Node2D = preload("res://scenes/game.tscn").instantiate()
	add_child_autofree(game)
	NetworkManager.attach_game(null)
	assert_ne(game.map_data, editor_map)
	assert_eq(game.map_data.name, "Forest")

func test_spawns_are_separated_and_passable():
	GameManager.start_single_player(AI.Difficulty.NORMAL, null, 0, 1, 2)
	var game: Node2D = preload("res://scenes/game.tscn").instantiate()
	add_child_autofree(game)
	NetworkManager.attach_game(null)

	var hq_tiles := {}
	for b in get_tree().get_nodes_in_group("buildings"):
		if is_instance_valid(b) and b.stats != null and b.stats.is_hq:
			hq_tiles[int(b.team)] = Vector2i(
				int(b.global_position.x / game.TILE_SIZE),
				int(b.global_position.y / game.TILE_SIZE),
			)
	assert_eq(hq_tiles.size(), 2)
	var p: Vector2i = hq_tiles[0]
	var e: Vector2i = hq_tiles[1]
	assert_true(maxi(absi(p.x - e.x), absi(p.y - e.y)) >= game.MIN_SPAWN_SEPARATION)
	assert_true(MapData.is_passable(game.map_data.get_terrain(p.x, p.y), 1))
	assert_true(MapData.is_passable(game.map_data.get_terrain(e.x, e.y), 1))

func test_ai_holds_rally_during_opening_grace():
	GameManager.start_single_player(AI.Difficulty.NORMAL, null, 0, 1, 2)
	var game: Node2D = preload("res://scenes/game.tscn").instantiate()
	add_child_autofree(game)
	NetworkManager.attach_game(null)

	game._run_skirmish_ai_turn()
	assert_eq(game.ai_tactical_state, "rally")
	game.elapsed_time = AI.rally_grace(AI.Difficulty.NORMAL) + 1.0
	game._run_skirmish_ai_turn()
	assert_ne(game.ai_tactical_state, "rally")

func test_fog_hides_unexplored_tiles_and_enemy_buildings():
	GameManager.start_single_player(AI.Difficulty.NORMAL, null, 0, 1, 2)
	var game: Node2D = preload("res://scenes/game.tscn").instantiate()
	add_child_autofree(game)
	NetworkManager.attach_game(null)
	game._update_fog()

	var ai_hq: Node2D = game._find_team_hq(1)
	assert_not_null(ai_hq)
	assert_false(ai_hq.visible)
	var tx := int(ai_hq.global_position.x / game.TILE_SIZE)
	var ty := int(ai_hq.global_position.y / game.TILE_SIZE)
	var px: Color = game.fog_image.get_pixel(tx, ty)
	assert_almost_eq(px.a, 1.0, 0.001)

func test_authored_deposits_are_used_in_match():
	var custom := MapData.new(32, 32)
	custom.add_deposit(2, 5, 5, 777, 4.0)
	GameManager.start_single_player(AI.Difficulty.NORMAL, custom, 0, 1, 3)
	var game: Node2D = preload("res://scenes/game.tscn").instantiate()
	add_child_autofree(game)
	NetworkManager.attach_game(null)

	assert_eq(game.resource_deposits.size(), 1)
	var dep: ResourceDeposit = game.resource_deposits[0]["deposit"]
	assert_eq(dep.amount, 777)
	assert_almost_eq(dep.harvest_rate, 4.0, 0.001)

func test_spectator_stages_two_ai_sides_with_chosen_factions():
	GameManager.start_spectator(
		AI.Difficulty.NORMAL, null, Faction.Id.PELAGIC, Faction.Id.VANGUARD, 2,
	)
	assert_eq(GameManager.match_mode, GameManager.Mode.SPECTATOR)
	assert_true(GameManager.is_spectator)
	assert_eq(GameManager.teams, [0, 1])
	assert_eq(GameManager.ai_teams, [0, 1])
	assert_eq(GameManager.local_team, -1)
	assert_false(GameManager.fog_enabled)
	assert_eq(GameManager.faction_for_team(0), Faction.Id.PELAGIC)
	assert_eq(GameManager.faction_for_team(1), Faction.Id.VANGUARD)
	var game: Node2D = preload("res://scenes/game.tscn").instantiate()
	add_child_autofree(game)
	NetworkManager.attach_game(null)
	var units_a: Array = game._get_team_units(0)
	var units_b: Array = game._get_team_units(1)
	assert_gt(units_a.size(), 0)
	assert_gt(units_b.size(), 0)
	assert_eq(units_a[0].faction, Faction.Id.PELAGIC)
	assert_eq(units_b[0].faction, Faction.Id.VANGUARD)
	var command_bar := game.ui.get_node_or_null("CommandBar") as CanvasItem
	assert_not_null(command_bar)
	assert_false(command_bar.visible)

func test_spectator_blocks_external_commands_but_allows_ai_internal_orders():
	GameManager.start_spectator(AI.Difficulty.NORMAL, null, 0, 1, 2)
	var game: Node2D = preload("res://scenes/game.tscn").instantiate()
	add_child_autofree(game)
	NetworkManager.attach_game(null)
	var cmd := {"type": "stop", "team": 0, "unit_ids": [999999]}
	assert_false(game.apply_command(cmd))
	assert_true(game.apply_command(cmd, true))

func test_spectator_runs_both_ai_teams():
	GameManager.start_spectator(AI.Difficulty.NORMAL, MapData.new(128, 128), 0, 1, 3)
	var game: Node2D = preload("res://scenes/game.tscn").instantiate()
	add_child_autofree(game)
	NetworkManager.attach_game(null)
	for team in [0, 1]:
		var wallet: Dictionary = ResourceManager.get_wallet(team)
		wallet[Economy.Res.OIL] = 3000
		wallet[Economy.Res.IRON] = 3000
		wallet[Economy.Res.GEOTHERMAL] = 1200
	var before_a := _queued_units(0)
	var before_b := _queued_units(1)
	for i in range(8):
		game.elapsed_time += 2.0
		game._tick_power()
		game._run_skirmish_ai_turn()
	assert_gt(_queued_units(0), before_a)
	assert_gt(_queued_units(1), before_b)
	assert_gt(game._get_team_units(0).size(), 0)
	assert_gt(game._get_team_units(1).size(), 0)

func test_spectator_ai_attacks_sooner_and_dispatches_scouts():
	GameManager.start_spectator(AI.Difficulty.NORMAL, MapData.new(128, 128), 0, 1)
	var game: Node2D = preload("res://scenes/game.tscn").instantiate()
	add_child_autofree(game)
	NetworkManager.attach_game(null)
	game.elapsed_time = 40.0
	game._run_skirmish_ai_turn()
	for team in [0, 1]:
		var state: Dictionary = game._ai_state(team)
		assert_ne(String(state["tactical_state"]), "rally")
		assert_gt(float(state["scout_order_until"]), game.elapsed_time)

func test_ai_ignores_enemies_hidden_by_fog():
	GameManager.start_single_player(AI.Difficulty.NORMAL, MapData.new(128, 128), 0, 1)
	var game: Node2D = preload("res://scenes/game.tscn").instantiate()
	add_child_autofree(game)
	NetworkManager.attach_game(null)
	game.elapsed_time = 80.0
	var intruder = game._spawn_unit_by_id("riflebot", Vector2(80, 80), 0)
	game._run_skirmish_ai_turn()
	assert_ne(String(game._ai_state(1)["tactical_state"]), "defend")
	var hq = game._find_team_hq(1)
	assert_not_null(hq)
	intruder.global_position = hq.global_position + Vector2(32, 0)
	game._run_skirmish_ai_turn()
	assert_eq(String(game._ai_state(1)["tactical_state"]), "defend")

func test_four_team_economies_are_initialized_and_saved():
	GameManager.start_single_player(AI.Difficulty.NORMAL, MapData.new(128, 128), 0, 1)
	GameManager.teams = [0, 1, 2, 3]
	GameManager.set_diplomacy_state({}, {}, GameManager.teams)
	var game: Node2D = preload("res://scenes/game.tscn").instantiate()
	add_child_autofree(game)
	NetworkManager.attach_game(null)
	for team in [0, 1, 2, 3]:
		assert_gt(int(ResourceManager.get_wallet(team).get(Economy.Res.IRON, 0)), 0)
		assert_gt(int(ResourceManager.rates.get(team, {}).get(Economy.Res.IRON, 0)), 0)
		assert_eq(int(ResourceManager.caps.get(team, 0)), 20)
	var path := "user://saves/four_team_roundtrip.bws"
	assert_eq(game.quicksave_match(path), OK)
	assert_true(game.quickload_match(path))
	for team in [0, 1, 2, 3]:
		assert_gt(int(ResourceManager.get_wallet(team).get(Economy.Res.IRON, 0)), 0)
		assert_gt(int(ResourceManager.rates.get(team, {}).get(Economy.Res.IRON, 0)), 0)
		assert_eq(int(ResourceManager.caps.get(team, 0)), 20)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func test_game_scene_detaches_from_network_manager_on_exit():
	GameManager.start_single_player(AI.Difficulty.NORMAL, MapData.new(16, 16), 0, 1, 2)
	var game: Node2D = preload("res://scenes/game.tscn").instantiate()
	add_child(game)
	assert_eq(NetworkManager.game_node, game)
	game.free()
	assert_null(NetworkManager.game_node)

func test_begin_net_session_clears_stale_team_economies():
	var saved := {
		"wallets": ResourceManager.wallets.duplicate(true),
		"base_rates": ResourceManager.base_rates.duplicate(true),
		"rates": ResourceManager.rates.duplicate(true),
		"caps": ResourceManager.caps.duplicate(true),
		"power_efficiency": ResourceManager.power_efficiency.duplicate(true),
	}
	ResourceManager.init_player(3, {Economy.Res.OIL: 999})
	assert_true(ResourceManager.wallets.has(3))
	GameManager.begin_net_session()
	assert_false(ResourceManager.wallets.has(3))
	assert_eq(ResourceManager.wallets.size(), 0)
	assert_eq(ResourceManager.rates.size(), 0)
	for key in saved.keys():
		ResourceManager.set(key, saved[key])

func test_player_commands_are_prepared_for_host_sanitizer():
	GameManager.start_single_player(AI.Difficulty.NORMAL, MapData.new(16, 16), 0, 1, 2)
	var game: Node2D = preload("res://scenes/game.tscn").instantiate()
	add_child_autofree(game)
	var original_team := GameManager.local_team
	GameManager.local_team = 2
	var prepared: Dictionary = game.call("_prepare_player_command", {
		"type": "build", "team": 0, "id": "extractor",
		"target_x": 64.0, "target_y": 80.0,
	})
	assert_eq(prepared["team"], 2)
	prepared["seq"] = 0
	var clean := NetSecurity.sanitize_command(prepared)
	assert_false(clean.is_empty())
	assert_eq(clean["team"], 2)
	assert_almost_eq(float(clean["x"]), 64.0, 0.001)
	assert_almost_eq(float(clean["y"]), 80.0, 0.001)
	GameManager.local_team = original_team

func test_player_commands_record_authoritative_local_team():
	GameManager.start_single_player(AI.Difficulty.NORMAL, MapData.new(16, 16), 0, 1, 2)
	var game: Node2D = preload("res://scenes/game.tscn").instantiate()
	add_child_autofree(game)
	var original_team := GameManager.local_team
	GameManager.local_team = 1
	assert_true(game.submit_player_command({"type": "hold", "team": 0, "unit_ids": []}))
	assert_eq(game.replay_log.commands.back()["player_id"], 1)
	GameManager.local_team = original_team

func test_npc_factions_are_ai_only_and_apply_live_combat_modifiers():
	# Human seat attempting to pick Vesper (4) is clamped back to 0..3; AI keeps Vesper (4).
	GameManager.start_single_player(AI.Difficulty.NORMAL, MapData.new(64, 64), Faction.Id.VESPER, Faction.Id.VESPER, 3)
	assert_false(Faction.is_npc(GameManager.faction_for_team(0)))
	assert_eq(GameManager.faction_for_team(1), Faction.Id.VESPER)
	var game: Node2D = preload("res://scenes/game.tscn").instantiate()
	add_child_autofree(game)
	NetworkManager.attach_game(null)

	# FullPalette must hide all 12 AI-only units from the human player.
	var palette: Node = game.ui.get_node_or_null("FullPaletteScroll/FullPalette")
	assert_not_null(palette)
	assert_null(palette.get_node_or_null("Train_ufo_wisp"))
	assert_null(palette.get_node_or_null("Train_lumen_enforcer"))
	assert_not_null(palette.get_node_or_null("Train_riflebot"))

	# Human cannot train an AI-only unit even with an airfield and resources.
	var hq0: Node2D = game._find_team_hq(0)
	game._spawn_building_by_id("airfield", hq0.global_position + Vector2(96, 0), 0)
	ResourceManager.get_wallet(0)[Economy.Res.OIL] = 1000
	ResourceManager.get_wallet(0)[Economy.Res.IRON] = 1000
	ResourceManager.get_wallet(0)[Economy.Res.GEOTHERMAL] = 1000
	assert_false(game.apply_command({"type": "train", "team": 0, "id": "ufo_talon"}))

	# Vesper AI CAN train its own UFO units, but NOT Thalassa's units.
	var hq1: Node2D = game._find_team_hq(1)
	game._spawn_building_by_id("airfield", hq1.global_position + Vector2(-96, 0), 1)
	game._spawn_building_by_id("shipyard", hq1.global_position + Vector2(-140, 0), 1)
	ResourceManager.get_wallet(1)[Economy.Res.OIL] = 1000
	ResourceManager.get_wallet(1)[Economy.Res.IRON] = 1000
	ResourceManager.get_wallet(1)[Economy.Res.GEOTHERMAL] = 1000
	assert_true(game.apply_command({"type": "train", "team": 1, "id": "ufo_talon"}, true))
	assert_false(game.apply_command({"type": "train", "team": 1, "id": "abyssal_trireme"}, true))

	# Verify live combat modifiers on spawned units (clear clouds for deterministic skies).
	GameManager.active_clouds.clear()
	var talon = game._spawn_unit_by_id("ufo_talon", Vector2(400, 400), 1)
	var target_air = game._spawn_unit_by_id("bomber_drone", Vector2(460, 400), 0)
	assert_almost_eq(talon.effective_speed(), talon.stats.speed * 1.3, 0.01)
	var hp_before: int = int(target_air.hp)
	talon._perform_attack(target_air)
	var vesper_dealt := hp_before - int(target_air.hp)
	# Compare against an identical attacker without Vesper's 1.2x air damage bonus.
	var target_air2 = game._spawn_unit_by_id("bomber_drone", Vector2(460, 460), 0)
	var neutral_talon = game._spawn_unit_by_id("ufo_talon", Vector2(400, 460), 1)
	neutral_talon.faction = Faction.Id.AERODYNE
	var hp_before2: int = int(target_air2.hp)
	neutral_talon._perform_attack(target_air2)
	var base_dealt := hp_before2 - int(target_air2.hp)
	assert_gt(vesper_dealt, base_dealt)

	# Verify sight multiplier (Lumen 1.25x vs Gravebound 0.85x).
	var op = game._spawn_unit_by_id("lumen_operative", Vector2(520, 400), 1)
	op.faction = Faction.Id.LUMEN
	assert_almost_eq(op.effective_sight(), op.stats.sight * 1.25, 0.01)
	var bone = game._spawn_unit_by_id("bone_legionary", Vector2(560, 400), 1)
	bone.faction = Faction.Id.GRAVEBOUND
	assert_almost_eq(bone.effective_sight(), bone.stats.sight * 0.85, 0.01)

func test_spectator_npc_vs_npc_persists_through_quicksave_and_trains_unique_units():
	GameManager.start_spectator(AI.Difficulty.NORMAL, MapData.new(64, 64), Faction.Id.VESPER, Faction.Id.GRAVEBOUND, 3)
	assert_eq(GameManager.faction_for_team(0), Faction.Id.VESPER)
	assert_eq(GameManager.faction_for_team(1), Faction.Id.GRAVEBOUND)
	var game: Node2D = preload("res://scenes/game.tscn").instantiate()
	add_child_autofree(game)
	NetworkManager.attach_game(null)

	for team in [0, 1]:
		var w := ResourceManager.get_wallet(team)
		w[Economy.Res.OIL] = 2000
		w[Economy.Res.IRON] = 2000
		w[Economy.Res.GEOTHERMAL] = 1000
	for i in range(6):
		game.elapsed_time += 15.0
		game._tick_power()
		game._run_skirmish_ai_turn()
	assert_gt(_building_count(0), 1)
	assert_gt(_building_count(1), 1)
	assert_gt(_queued_units(0), 0)
	assert_gt(_queued_units(1), 0)

	var path := "user://saves/test_npc_spectator.bws"
	assert_eq(game.quicksave_match(path), OK)
	GameManager.start_single_player(AI.Difficulty.NORMAL, null, 0, 1, 2)
	assert_true(game.quickload_match(path))
	assert_eq(GameManager.faction_for_team(0), Faction.Id.VESPER)
	assert_eq(GameManager.faction_for_team(1), Faction.Id.GRAVEBOUND)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func test_research_dialog_repopulate_does_not_leak_tree_nodes():
	var dialog := ResearchDialog.new()
	add_child_autofree(dialog)
	var wallet := {
		Economy.Res.OIL: 500, Economy.Res.IRON: 500,
		Economy.Res.GEOTHERMAL: 500, Economy.Res.FOOD: 500,
	}
	dialog.populate([], wallet, true)
	var initial_count := dialog.get_child_count()
	dialog.populate(["reactive_armor"], wallet, true)
	dialog.populate(["reactive_armor", "railgun_cal"], wallet, true)
	assert_eq(dialog.get_child_count(), initial_count)

func test_ai_retreat_is_isolated_to_wounded_units_and_does_not_pull_healthy_squad():
	GameManager.start_single_player(AI.Difficulty.NORMAL, MapData.new(64, 64), 0, 1, 3)
	var game: Node2D = preload("res://scenes/game.tscn").instantiate()
	add_child_autofree(game)
	NetworkManager.attach_game(null)
	game.elapsed_time = 90.0
	var hq1: Node2D = game._find_team_hq(1)
	assert_not_null(hq1)
	var enemy_pos := hq1.global_position + Vector2(-420, 0)
	# Give AI a visible enemy cluster + an attacking squad where only one unit is wounded.
	game._spawn_unit_by_id("riflebot", enemy_pos, 0)
	var wounded: Node2D = game._spawn_unit_by_id("mbt", enemy_pos + Vector2(120, 0), 1)
	wounded.hp = 10
	var healthy: Array = []
	for i in range(6):
		healthy.append(game._spawn_unit_by_id("mbt", enemy_pos + Vector2(140, float(i) * 20.0), 1))
	game._run_skirmish_ai_turn()
	assert_eq(String(game._ai_state(1)["tactical_state"]), "attack")
	# Wounded unit retreats without attack_move; healthy vanguard continues attack_moving forward.
	assert_false(bool(wounded.attack_move))
	assert_true(bool(healthy[0].attack_move))
	assert_lt(healthy[0].target_pos.distance_to(enemy_pos), wounded.target_pos.distance_to(enemy_pos))

func test_ai_builds_power_plant_extractors_on_deposits_and_executes_combined_arms_tactics():
	var custom := MapData.new(64, 64)
	custom.set_hq_spawn(0, 8, 8)
	custom.set_hq_spawn(1, 52, 52)
	for t in range(4):
		custom.add_deposit(t, 12 + t * 2, 10, 1500, 10.0)
		custom.add_deposit(t, 46 - t * 2, 50, 1500, 10.0)
	GameManager.start_single_player(AI.Difficulty.HARD, custom, 0, 1, 3)
	var game: Node2D = preload("res://scenes/game.tscn").instantiate()
	add_child_autofree(game)
	NetworkManager.attach_game(null)
	var wallet: Dictionary = ResourceManager.get_wallet(1)
	wallet[Economy.Res.OIL] = 4000
	wallet[Economy.Res.IRON] = 4000
	wallet[Economy.Res.GEOTHERMAL] = 2000
	wallet[Economy.Res.FOOD] = 1000
	var hq1: Node2D = game._find_team_hq(1)
	# Force brownout with factories, then verify AI builds a power_plant.
	game._spawn_building_by_id("barracks", hq1.global_position + Vector2(-80, 0), 1)
	game._spawn_building_by_id("factory", hq1.global_position + Vector2(-140, 0), 1)
	game._tick_power()
	game.elapsed_time = 20.0
	game._run_skirmish_ai_turn()
	assert_gt(game._count_team_buildings(1, "power_plant"), 0)

	# Next build (extractor) should land within harvest radius (112 px) of a deposit.
	game._tick_power()
	game.elapsed_time = 40.0
	game._run_skirmish_ai_turn()
	var extractor_near_deposit := false
	for b in get_tree().get_nodes_in_group("buildings"):
		if is_instance_valid(b) and int(b.team) == 1 and b.stats != null and b.stats.id == "extractor":
			if game._near_resource_deposit(b.global_position):
				extractor_near_deposit = true
				break
	assert_true(extractor_near_deposit, "AI extractor must be placed within deposit harvest radius")

	# Anti-air unit prefers aircraft in range over a closer riflebot.
	var aa: Node2D = game._spawn_unit_by_id("aa_vehicle", Vector2(500, 500), 1)
	var close_inf: Node2D = game._spawn_unit_by_id("riflebot", Vector2(580, 500), 0)
	var bomber: Node2D = game._spawn_unit_by_id("bomber_drone", Vector2(680, 500), 0)
	assert_eq(aa._nearest_enemy(), bomber)
	assert_ne(aa._nearest_enemy(), close_inf)

	# Hard AI with strategic_uplinks fires Orbital Laser at dense visible enemy cluster
	# without locking out the human player's laser_cooldown.
	game.team_unlocked_tech[1] = ["reactive_armor", "railgun_cal", "super_heavy", "strategic_uplinks"]
	var cluster_pos := hq1.global_position + Vector2(-180, -120)
	var target_hq_proxy: Node2D = game._spawn_building_by_id("factory", cluster_pos, 0)
	game._spawn_building_by_id("barracks", cluster_pos + Vector2(32, 0), 0)
	var hp_before_laser: int = int(target_hq_proxy.hp)
	game.laser_cooldown = 0.0
	game.elapsed_time = 95.0
	game._run_skirmish_ai_turn()
	assert_lt(int(target_hq_proxy.hp), hp_before_laser, "AI should fire strategic strike at dense visible cluster")
	assert_almost_eq(game.laser_cooldown, 0.0, 0.001, "AI laser must not put human player's laser on cooldown")

	# Corvette AI deploys a sonar buoy when enemy submarine is detected/present.
	var corvette: Node2D = game._spawn_unit_by_id("corvette", Vector2(300, 300), 1)
	game._spawn_unit_by_id("attack_sub", Vector2(400, 300), 0)
	var buoys_before: int = int(game.sonar_buoys.size())
	game.elapsed_time = 110.0
	game._run_skirmish_ai_turn()
	assert_gt(game.sonar_buoys.size(), buoys_before)
	assert_true(is_instance_valid(corvette))
