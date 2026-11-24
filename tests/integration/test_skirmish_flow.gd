# tests/integration/test_skirmish_flow.gd
extends GutTest

## The main menu must expose a logo and wire the skirmish button to the
## single-player handler that starts the AI match.
func test_main_menu_skirmish_button_is_wired():
	var menu := preload("res://scenes/main_menu.tscn").instantiate()
	add_child_autofree(menu)
	var button: Button = menu.get_node("VBox/SkirmishButton")
	assert_true(button.is_connected("pressed", Callable(menu, "_on_skirmish")))
	var logo: TextureRect = menu.get_node("Logo")
	assert_not_null(logo.texture)

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
