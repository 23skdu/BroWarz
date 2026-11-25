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
	var side_a: int = int(menu.selected_faction)
	var side_b: int = int(menu.selected_spectator_faction)
	menu._on_cycle_faction()
	menu._on_cycle_spectator_faction()
	assert_eq(menu.selected_faction, (side_a + 1) % 4)
	assert_eq(menu.selected_spectator_faction, (side_b + 1) % 4)
	assert_true(String(menu.faction_btn.text).contains(Faction.name_of(menu.selected_faction)))
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
