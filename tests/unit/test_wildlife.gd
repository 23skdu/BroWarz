# tests/unit/test_wildlife.gd
extends GutTest

func test_kind_names_and_domains():
	assert_eq(Wildlife.kind_name(Wildlife.Kind.DEER), "Deer")
	assert_eq(Wildlife.kind_name(Wildlife.Kind.DOLPHIN), "Dolphin")
	assert_eq(Wildlife.kind_name(Wildlife.Kind.SQUID), "Squid")
	assert_eq(Wildlife.kind_name(Wildlife.Kind.BIRD), "Bird")
	assert_eq(Wildlife.domain_of(Wildlife.Kind.DEER), Wildlife.Domain.LAND)
	assert_eq(Wildlife.domain_of(Wildlife.Kind.DOLPHIN), Wildlife.Domain.SEA)
	assert_eq(Wildlife.domain_of(Wildlife.Kind.SQUID), Wildlife.Domain.SEA)
	assert_eq(Wildlife.domain_of(Wildlife.Kind.BIRD), Wildlife.Domain.AIR)

func test_valid_terrain_per_species():
	assert_true(Wildlife.is_valid_terrain(Wildlife.Kind.DOLPHIN, MapData.Terrain.SEA))
	assert_false(Wildlife.is_valid_terrain(Wildlife.Kind.DOLPHIN, MapData.Terrain.PLAINS))
	assert_true(Wildlife.is_valid_terrain(Wildlife.Kind.SQUID, MapData.Terrain.RIVER))
	assert_true(Wildlife.is_valid_terrain(Wildlife.Kind.DEER, MapData.Terrain.FOREST))
	assert_false(Wildlife.is_valid_terrain(Wildlife.Kind.DEER, MapData.Terrain.SEA))
	assert_true(Wildlife.is_valid_terrain(Wildlife.Kind.BIRD, MapData.Terrain.MOUNTAIN))

func test_spawn_ambient_herd_naval_and_forest():
	var island_map := TerrainGenerator.generate_islands(64, 64, 7)
	var herd_naval := Wildlife.spawn_ambient_herd(island_map, 7, 10)
	assert_true(herd_naval.size() > 0 and herd_naval.size() <= 10)
	var has_bird := false
	var has_marine := false
	for cr in herd_naval:
		if int(cr["kind"]) == Wildlife.Kind.BIRD:
			has_bird = true
		elif int(cr["kind"]) == Wildlife.Kind.DOLPHIN or int(cr["kind"]) == Wildlife.Kind.SQUID:
			has_marine = true
	assert_true(has_bird)
	assert_true(has_marine)

func test_flee_and_death_on_damage():
	var cr := Wildlife.create_critter(1, Wildlife.Kind.DEER, Vector2(200, 200), 42)
	var flee_v := Wildlife.compute_flee_vector(cr["pos"], [Vector2(180, 200)], 115.0)
	assert_true(flee_v.x > 0.5)

	# Non-lethal shot causes panic flee
	var died_first := Wildlife.apply_damage(cr, 8.0, Vector2(180, 200))
	assert_false(died_first)
	assert_true(bool(cr["alive"]))
	assert_true(float(cr["flee_timer"]) > 0.0)
	assert_almost_eq(Vector2(cr["vel"]).length(), Wildlife.flee_speed(Wildlife.Kind.DEER), 0.1)

	# Lethal shot kills critter
	var died_second := Wildlife.apply_damage(cr, 50.0, Vector2(180, 200))
	assert_true(died_second)
	assert_false(bool(cr["alive"]))
	assert_eq(int(cr["hp"]), 0)
