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
	# compound an already-scaled rate down to zero.
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
