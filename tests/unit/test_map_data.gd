# tests/unit/test_map_data.gd
extends GutTest

func test_default_size():
	var m = MapData.new()
	assert_eq(m.width, 128)
	assert_eq(m.height, 128)
	assert_eq(m.tile_count(), 16384)

func test_set_get_terrain():
	var m = MapData.new(4, 4)
	assert_true(m.set_terrain(1, 2, MapData.Terrain.SWAMP))
	assert_eq(m.get_terrain(1, 2), MapData.Terrain.SWAMP)

func test_out_of_bounds():
	var m = MapData.new(4, 4)
	assert_false(m.in_bounds(4, 0))
	assert_eq(m.get_terrain(4, 0), -1)
	assert_false(m.set_terrain(4, 0, MapData.Terrain.SEA))

func test_movement_cost_infantry_swamp():
	var c = MapData.movement_cost(MapData.Terrain.SWAMP, 0)
	assert_true(c > 1.0)

func test_vehicle_swamp_impassable():
	assert_false(MapData.is_passable(MapData.Terrain.SWAMP, 1))

func test_naval_sea_passable():
	assert_true(MapData.is_passable(MapData.Terrain.SEA, 2))

func test_air_always_passable():
	assert_true(MapData.is_passable(MapData.Terrain.MOUNTAIN, 3))

func test_index_roundtrip():
	var m = MapData.new(8, 8)
	assert_eq(m.index(3, 4), 4*8+3)

func test_desert_and_hills_terrains():
	assert_eq(MapData.terrain_name(MapData.Terrain.DESERT), "Desert")
	assert_eq(MapData.terrain_name(MapData.Terrain.HILLS), "Hills")
	assert_true(MapData.is_passable(MapData.Terrain.DESERT, 0))
	assert_true(MapData.is_passable(MapData.Terrain.HILLS, 1))
	assert_true(MapData.movement_cost(MapData.Terrain.HILLS, 1) > MapData.movement_cost(MapData.Terrain.PLAINS, 1))
	assert_true(Cover.provides_cover(MapData.Terrain.HILLS))

func test_hq_spawn_placement_and_lookup():
	var m = MapData.new(20, 20)
	assert_true(m.set_hq_spawn(0, 2, 2))
	assert_true(m.set_hq_spawn(1, 17, 17))
	assert_eq(m.get_hq_spawn(0), Vector2i(2, 2))
	assert_eq(m.get_hq_spawn(1), Vector2i(17, 17))
	assert_eq(m.get_hq_spawn(3), Vector2i(-1, -1))
	assert_false(m.set_hq_spawn(4, 1, 1))
	assert_false(m.set_hq_spawn(0, 99, 99))
	# Re-placing a team moves its spawn instead of duplicating it.
	assert_true(m.set_hq_spawn(0, 3, 3))
	assert_eq(m.hq_spawns.size(), 2)
	assert_eq(m.get_hq_spawn(0), Vector2i(3, 3))
	assert_true(m.remove_hq_spawn(0))
	assert_eq(m.hq_spawns.size(), 1)

func test_deposit_placement_and_markers():
	var m = MapData.new(20, 20)
	assert_true(m.add_deposit(Economy.Res.OIL, 4, 4))
	assert_true(m.add_deposit(Economy.Res.IRON, 4, 5))
	assert_eq(m.deposits.size(), 2)
	assert_false(m.add_deposit(9, 1, 1))
	assert_false(m.add_deposit(Economy.Res.FOOD, 40, 40))
	# One marker per tile: replacing an old deposit clears it.
	assert_true(m.add_deposit(Economy.Res.FOOD, 4, 4))
	assert_eq(m.deposits.size(), 2)
	assert_eq(int(m.deposits[1].get("type", -1)), Economy.Res.FOOD)
	assert_eq(MapData.deposits_near(m, Vector2i(4, 4), Economy.Res.FOOD, 2), 1)
	assert_true(m.clear_deposits_at(4, 4))
	assert_eq(m.deposits.size(), 1)

func test_hex_helpers_and_validation():
	var m = MapData.new(20, 20)
	assert_eq(MapData.hex_distance(Vector2i(2, 2), Vector2i(4, 2)), 2)
	assert_true(MapData.hex_connected(m, Vector2i(2, 2), Vector2i(17, 17)))
	for team in [0, 1]:
		var pos: Vector2i = Vector2i(2, 2) if team == 0 else Vector2i(17, 17)
		for type in range(4):
			var dx: int = type if team == 0 else -type
			assert_true(m.add_deposit(type, pos.x + dx, pos.y))
	m.set_hq_spawn(0, 2, 2)
	m.set_hq_spawn(1, 17, 17)
	var res = MapData.validate_map(m)
	assert_true(bool(res["ok"]), str(res["reason"]))
	assert_true(bool(res["connected"]))
	assert_true(bool(res["balanced"]))
	assert_eq(int(res["spawns"]), 2)
	assert_eq(int(res["deposits"]), 8)

func test_validation_rejects_unbalanced_and_disconnected():
	var m = MapData.new(20, 20)
	m.set_hq_spawn(0, 2, 2)
	m.set_hq_spawn(1, 17, 17)
	assert_false(bool(MapData.validate_map(m)["balanced"]))
	assert_true(bool(MapData.validate_map(m)["connected"]))
	for team in [0, 1]:
		var pos: Vector2i = Vector2i(2, 2) if team == 0 else Vector2i(17, 17)
		for type in range(4):
			var dx: int = type if team == 0 else -type
			m.add_deposit(type, pos.x + dx, pos.y)
	assert_true(bool(MapData.validate_map(m)["balanced"]))
	m.add_deposit(Economy.Res.OIL, 17, 3)
	m.add_deposit(Economy.Res.IRON, 17, 4)
	m.add_deposit(Economy.Res.GEOTHERMAL, 17, 5)
	m.add_deposit(Economy.Res.FOOD, 17, 6)
	assert_true(bool(MapData.validate_map(m)["ok"]))
	# A mountain wall severs the infantry hex path between the two HQs.
	for y in range(20):
		m.set_terrain(10, y, MapData.Terrain.MOUNTAIN)
	var broken = MapData.validate_map(m)
	assert_false(bool(broken["connected"]))
	assert_false(bool(broken["ok"]))

func test_all_unit_class_terrain_mechanics():
	# Class 6 (Heavybot) and Class 7 (Heavy/Siege Mech) cross mountains
	assert_false(MapData.is_passable(MapData.Terrain.MOUNTAIN, 0, false))
	assert_true(MapData.is_passable(MapData.Terrain.MOUNTAIN, 6, true))
	assert_false(MapData.is_passable(MapData.Terrain.MOUNTAIN, 1, false))
	assert_true(MapData.is_passable(MapData.Terrain.MOUNTAIN, 7, true))
	# Class 4 (Hovercraft) and Class 5 (Frogbot) traverse both land and sea
	assert_true(MapData.is_passable(MapData.Terrain.PLAINS, 4))
	assert_true(MapData.is_passable(MapData.Terrain.SEA, 4))
	assert_false(MapData.is_passable(MapData.Terrain.MOUNTAIN, 4))
	assert_true(MapData.is_passable(MapData.Terrain.DESERT, 5))
	assert_true(MapData.is_passable(MapData.Terrain.SEA, 5))
	assert_true(MapData.movement_cost(MapData.Terrain.SEA, 5) < MapData.movement_cost(MapData.Terrain.PLAINS, 5))

