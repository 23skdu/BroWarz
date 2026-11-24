# tests/unit/test_cover.gd
extends GutTest

func test_urban_cover():
	assert_true(Cover.provides_cover(MapData.Terrain.URBAN))
	assert_almost_eq(Cover.modifier(MapData.Terrain.URBAN), 0.7, 0.001)

func test_plains_no_cover():
	assert_false(Cover.provides_cover(MapData.Terrain.PLAINS))
	assert_eq(Cover.modifier(MapData.Terrain.PLAINS), 1.0)

func test_per_terrain_combat_modifiers_by_unit_class():
	# Every terrain has a defined defense and attack modifier per unit class
	assert_almost_eq(Cover.defense_modifier_for_unit(MapData.Terrain.URBAN, 0), 0.65, 0.001)
	assert_almost_eq(Cover.defense_modifier_for_unit(MapData.Terrain.URBAN, 1), 0.85, 0.001)
	assert_almost_eq(Cover.defense_modifier_for_unit(MapData.Terrain.FOREST, 0), 0.75, 0.001)
	assert_almost_eq(Cover.defense_modifier_for_unit(MapData.Terrain.FOREST, 1), 0.90, 0.001)
	assert_almost_eq(Cover.defense_modifier_for_unit(MapData.Terrain.HILLS, 0), 0.82, 0.001)
	assert_almost_eq(Cover.defense_modifier_for_unit(MapData.Terrain.MOUNTAIN, 6), 0.65, 0.001)
	assert_almost_eq(Cover.defense_modifier_for_unit(MapData.Terrain.SWAMP, 0), 1.12, 0.001)
	assert_almost_eq(Cover.defense_modifier_for_unit(MapData.Terrain.SWAMP, 5), 0.90, 0.001)
	assert_almost_eq(Cover.defense_modifier_for_unit(MapData.Terrain.RIVER, 5), 0.80, 0.001)
	assert_almost_eq(Cover.defense_modifier_for_unit(MapData.Terrain.SEA, 2), 0.95, 0.001)
	assert_almost_eq(Cover.defense_modifier_for_unit(MapData.Terrain.DESERT, 0), 1.10, 0.001)
	assert_almost_eq(Cover.defense_modifier_for_unit(MapData.Terrain.ROAD, 1), 1.08, 0.001)
	assert_almost_eq(Cover.defense_modifier_for_unit(MapData.Terrain.BRIDGE, 1), 0.92, 0.001)
	assert_almost_eq(Cover.defense_modifier_for_unit(MapData.Terrain.WASTELAND, 0), 1.15, 0.001)

	# Outgoing attack modifiers
	assert_almost_eq(Cover.attack_modifier_for_unit(MapData.Terrain.HILLS, 1), 1.12, 0.001)
	assert_almost_eq(Cover.attack_modifier_for_unit(MapData.Terrain.MOUNTAIN, 7), 1.18, 0.001)
	assert_almost_eq(Cover.attack_modifier_for_unit(MapData.Terrain.URBAN, 0), 1.08, 0.001)
	assert_almost_eq(Cover.attack_modifier_for_unit(MapData.Terrain.URBAN, 1), 0.92, 0.001)
	assert_almost_eq(Cover.attack_modifier_for_unit(MapData.Terrain.SEA, 2), 1.10, 0.001)
	assert_almost_eq(Cover.attack_modifier_for_unit(MapData.Terrain.WASTELAND, 0), 0.90, 0.001)

func test_clouds_exclusively_affect_aerial_units():
	# Ground terrain NEVER affects air units (unit_class == 3)
	for t in [MapData.Terrain.URBAN, MapData.Terrain.MOUNTAIN, MapData.Terrain.SWAMP, MapData.Terrain.WASTELAND, MapData.Terrain.DESERT]:
		assert_eq(Cover.defense_modifier_for_unit(t, 3, false), 1.0)
		assert_eq(Cover.attack_modifier_for_unit(t, 3, false), 1.0)
		assert_eq(MapData.speed_multiplier(t, 3, false, false), 1.0)

	# Clouds ONLY affect air units (speed 0.78x, defense 0.75x, attack 0.85x) and NEVER affect ground/naval units
	assert_almost_eq(Cover.defense_modifier_for_unit(MapData.Terrain.PLAINS, 3, true), 0.75, 0.001)
	assert_almost_eq(Cover.attack_modifier_for_unit(MapData.Terrain.PLAINS, 3, true), 0.85, 0.001)
	assert_almost_eq(MapData.speed_multiplier(MapData.Terrain.PLAINS, 3, false, true), 0.78, 0.001)
	assert_almost_eq(Cover.defense_modifier_for_unit(MapData.Terrain.PLAINS, 0, true), 1.0, 0.001)
	assert_almost_eq(MapData.speed_multiplier(MapData.Terrain.PLAINS, 1, false, true), 1.0, 0.001)

	# Cloud spawning, drifting, and point detection
	var clouds := Cover.spawn_clouds(1024.0, 1024.0, 42, 6)
	assert_eq(clouds.size(), 6)
	var c0_pos: Vector2 = clouds[0]["pos"]
	assert_true(Cover.is_point_in_cloud(clouds, c0_pos))
	Cover.step_clouds(clouds, 1024.0, 1024.0, 2.0)
	assert_ne(clouds[0]["pos"], c0_pos)
