# tests/unit/test_wildlife.gd
extends GutTest

const WildlifeRef := preload("res://scripts/core/wildlife.gd")

func test_kind_names_and_domains():
	assert_eq(WildlifeRef.kind_name(WildlifeRef.Kind.DEER), "Deer")
	assert_eq(WildlifeRef.kind_name(WildlifeRef.Kind.DOLPHIN), "Dolphin")
	assert_eq(WildlifeRef.kind_name(WildlifeRef.Kind.SQUID), "Squid")
	assert_eq(WildlifeRef.kind_name(WildlifeRef.Kind.BIRD), "Bird")
	assert_eq(WildlifeRef.domain_of(WildlifeRef.Kind.DEER), WildlifeRef.Domain.LAND)
	assert_eq(WildlifeRef.domain_of(WildlifeRef.Kind.DOLPHIN), WildlifeRef.Domain.SEA)
	assert_eq(WildlifeRef.domain_of(WildlifeRef.Kind.SQUID), WildlifeRef.Domain.SEA)
	assert_eq(WildlifeRef.domain_of(WildlifeRef.Kind.BIRD), WildlifeRef.Domain.AIR)

func test_valid_terrain_per_species():
	assert_true(WildlifeRef.is_valid_terrain(WildlifeRef.Kind.DOLPHIN, MapData.Terrain.SEA))
	assert_false(WildlifeRef.is_valid_terrain(WildlifeRef.Kind.DOLPHIN, MapData.Terrain.PLAINS))
	assert_true(WildlifeRef.is_valid_terrain(WildlifeRef.Kind.SQUID, MapData.Terrain.RIVER))
	assert_true(WildlifeRef.is_valid_terrain(WildlifeRef.Kind.DEER, MapData.Terrain.FOREST))
	assert_false(WildlifeRef.is_valid_terrain(WildlifeRef.Kind.DEER, MapData.Terrain.SEA))
	assert_true(WildlifeRef.is_valid_terrain(WildlifeRef.Kind.BIRD, MapData.Terrain.MOUNTAIN))

func test_spawn_ambient_herd_naval_and_forest():
	var island_map := TerrainGenerator.generate_islands(64, 64, 7)
	var herd_naval: Array[Dictionary] = WildlifeRef.spawn_ambient_herd(island_map, 7, 10)
	assert_true(herd_naval.size() > 0 and herd_naval.size() <= 10)
	var has_bird := false
	var has_marine := false
	for cr in herd_naval:
		if int(cr["kind"]) == WildlifeRef.Kind.BIRD:
			has_bird = true
		elif int(cr["kind"]) == WildlifeRef.Kind.DOLPHIN or int(cr["kind"]) == WildlifeRef.Kind.SQUID:
			has_marine = true
	assert_true(has_bird)
	assert_true(has_marine)

func test_flee_and_death_on_damage():
	var cr: Dictionary = WildlifeRef.create_critter(1, WildlifeRef.Kind.DEER, Vector2(200, 200), 42)
	var flee_v: Vector2 = WildlifeRef.compute_flee_vector(cr["pos"], [Vector2(180, 200)], 115.0)
	assert_true(flee_v.x > 0.5)

	# Non-lethal shot causes panic flee
	var died_first: bool = WildlifeRef.apply_damage(cr, 8.0, Vector2(180, 200))
	assert_false(died_first)
	assert_true(bool(cr["alive"]))
	assert_true(float(cr["flee_timer"]) > 0.0)
	assert_almost_eq(Vector2(cr["vel"]).length(), WildlifeRef.flee_speed(WildlifeRef.Kind.DEER), 0.1)

	# Lethal shot kills critter
	var died_second: bool = WildlifeRef.apply_damage(cr, 50.0, Vector2(180, 200))
	assert_true(died_second)
	assert_false(bool(cr["alive"]))
	assert_eq(int(cr["hp"]), 0)
