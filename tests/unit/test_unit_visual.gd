# tests/unit/test_unit_visual.gd
extends GutTest

func test_select_state_priority():
	assert_eq(UnitVisual.select_state(true, 0.2, 0.1, 100.0), UnitVisual.AnimState.EXPLODE)
	assert_eq(UnitVisual.select_state(false, 0.2, 0.1, 100.0), UnitVisual.AnimState.FIRE)
	assert_eq(UnitVisual.select_state(false, 0.0, 0.1, 100.0), UnitVisual.AnimState.HIT)
	assert_eq(UnitVisual.select_state(false, 0.0, 0.0, 100.0), UnitVisual.AnimState.MOVE)
	assert_eq(UnitVisual.select_state(false, 0.0, 0.0, 0.0), UnitVisual.AnimState.IDLE)

func test_state_names_and_frames():
	assert_eq(UnitVisual.state_name(UnitVisual.AnimState.MOVE), "move")
	assert_eq(UnitVisual.state_name(UnitVisual.AnimState.FIRE), "fire")
	assert_eq(UnitVisual.state_name(UnitVisual.AnimState.EXPLODE), "explode")
	assert_eq(UnitVisual.frame_count(UnitVisual.AnimState.MOVE), 6)
	assert_eq(UnitVisual.frame_count(UnitVisual.AnimState.EXPLODE), 8)
	assert_true(UnitVisual.frame_index(UnitVisual.AnimState.MOVE, 0.35, true) >= 0)
	assert_eq(UnitVisual.frame_index(UnitVisual.AnimState.EXPLODE, 10.0, false), 7)

func test_kinematics_and_debris():
	var k_move := UnitVisual.compute_kinematics(UnitVisual.AnimState.MOVE, 0.2, 0)
	assert_true(float(k_move["bob"]) >= 0.0)
	var k_fire := UnitVisual.compute_kinematics(UnitVisual.AnimState.FIRE, 0.02, 1)
	assert_true(float(k_fire["recoil"]) > 0.0)
	assert_true(float(k_fire["muzzle_alpha"]) > 0.0)
	var k_exp := UnitVisual.compute_kinematics(UnitVisual.AnimState.EXPLODE, UnitVisual.explosion_duration() * 0.5, 1)
	assert_almost_eq(float(k_exp["explosion_progress"]), 0.5, 0.05)

	var debris := UnitVisual.generate_explosion_debris(42, 10)
	assert_eq(debris.size(), 10)
	assert_true(float(debris[0]["speed"]) >= 28.0)

func test_build_unit_frame_image_all_domains():
	for uclass in range(4):
		var img_move := UnitVisual.build_unit_frame_image(uclass, UnitVisual.AnimState.MOVE, 1, Color.BLUE, 32)
		assert_eq(img_move.get_width(), 32)
		assert_eq(img_move.get_height(), 32)
		var img_fire := UnitVisual.build_unit_frame_image(uclass, UnitVisual.AnimState.FIRE, 0, Color.RED, 32)
		assert_eq(img_fire.get_width(), 32)
	var img_exp := UnitVisual.build_unit_frame_image(1, UnitVisual.AnimState.EXPLODE, 3, Color.RED, 32)
	assert_eq(img_exp.get_width(), 32)

func test_high_res_terrain_and_specific_unit_ids():
	var m := TerrainGenerator.generate_forest(16, 16, 5)
	var t_img := UnitVisual.build_terrain_map_image(m, 4)
	assert_eq(t_img.get_width(), 64)
	assert_eq(t_img.get_height(), 64)
	for uid in ["riflebot", "heavybot", "stealthbot", "sniperbot", "rocketbot", "medicbot", "mbt", "heavy_mech", "attack_sub", "fighter_drone"]:
		var u_img := UnitVisual.build_unit_frame_image(0, UnitVisual.AnimState.IDLE, 0, Faction.color_of(0), 48, uid)
		assert_eq(u_img.get_width(), 48)
		var u_img_f1 := UnitVisual.build_unit_frame_image(0, UnitVisual.AnimState.IDLE, 0, Faction.color_of(1), 48, uid)
		assert_eq(u_img_f1.get_width(), 48)
		# Verify pixel-perfect structural uniformity across factions (identical opaque silhouette mask)
		for y in range(48):
			for x in range(48):
				assert_eq(u_img.get_pixel(x, y).a > 0.0, u_img_f1.get_pixel(x, y).a > 0.0)

func test_500_unit_lod_cache_and_spatial_hash():
	UnitVisual.clear_shared_cache()
	assert_eq(UnitVisual.lod_sprite_size(1.0, 120), 48)
	assert_eq(UnitVisual.lod_sprite_size(0.5, 120), 24)
	assert_eq(UnitVisual.lod_sprite_size(1.0, 520), 24)
	var t1 := UnitVisual.get_cached_unit_texture(0, UnitVisual.AnimState.IDLE, 0, Faction.color_of(0), 48, "riflebot")
	var t2 := UnitVisual.get_cached_unit_texture(0, UnitVisual.AnimState.IDLE, 0, Faction.color_of(0), 48, "riflebot")
	assert_eq(t1, t2)
	assert_eq(UnitVisual.shared_cache_size(), 1)

	var positions: Array = []
	for i in range(520):
		positions.append(Vector2(float((i % 26) * 32), float((i / 26.0) * 32)))
	var grid := UnitVisual.build_spatial_grid(positions, 128.0)
	var nearby := UnitVisual.query_spatial_radius(grid, positions, Vector2(64, 64), 80.0, 128.0)
	assert_true(nearby.size() > 0 and nearby.size() < 40)

func test_npc_unique_unit_sprites_render_distinctly():
	var reg := UnitRegistry.new()
	reg.populate_defaults()
	var hashes: Dictionary = {}
	for fac_id in Faction.npc_ids():
		var col := Faction.color_of(fac_id)
		for uid in reg.units_for_faction(fac_id):
			var s := reg.get_unit(str(uid))
			var img := UnitVisual.build_unit_frame_image(s.unit_class, UnitVisual.AnimState.IDLE, 0, col, 48, str(uid))
			assert_eq(img.get_width(), 48)
			assert_eq(img.get_height(), 48)
			var opaque := 0
			for y in range(48):
				for x in range(48):
					if img.get_pixel(x, y).a > 0.0:
						opaque += 1
			assert_gt(opaque, 80, "%s should have substantial pixel geometry" % str(uid))
			var key := img.get_data().hex_encode()
			assert_false(hashes.has(key), "%s must have a unique sprite" % str(uid))
			hashes[key] = str(uid)
			assert_true(ResourceLoader.exists("res://docs/thumbnails/%s_f%d.png" % [str(uid), fac_id]))

func test_graphics_profiles_canopy_texture_fog_bytes_and_high_res_terrain():
	var low := UnitVisual.graphics_profile("low")
	var high := UnitVisual.graphics_profile("high")
	assert_lt(int(low["terrain_ppt"]), int(high["terrain_ppt"]))
	assert_false(bool(low["shadows"]))
	assert_true(bool(high["shadows"]))
	assert_lt(int(low["max_tracers"]), int(high["max_tracers"]))

	var view := UnitVisual.camera_world_rect(Vector2(500, 400), Vector2(800, 600), Vector2(1.0, 1.0), 100.0)
	assert_true(view.has_point(Vector2(500, 400)))
	assert_false(view.has_point(Vector2(1800, 1800)))

	assert_gt(UnitVisual.hp_bar_color(0.8).g, UnitVisual.hp_bar_color(0.2).g)
	assert_gt(UnitVisual.hp_bar_color(0.2).r, UnitVisual.hp_bar_color(0.8).r)

	UnitVisual.clear_shared_cache()
	var canopy1 := UnitVisual.get_canopy_texture(32)
	var canopy2 := UnitVisual.get_canopy_texture(32)
	assert_not_null(canopy1)
	assert_eq(canopy1, canopy2)
	var cimg := canopy1.get_image()
	assert_gt(cimg.get_pixel(16, 16).a, 0.8)
	assert_almost_eq(cimg.get_pixel(0, 0).a, 0.0, 0.01)

	# PackedByteArray fog and minimap compositors match visibility states exactly.
	var fog := FogOfWar.new(8, 8)
	fog.mark_visible(2, 2, 1)
	var buf := UnitVisual.fog_rgba_bytes(fog)
	assert_eq(buf.size(), 8 * 8 * 4)
	assert_eq(int(buf[(2 * 8 + 2) * 4 + 3]), 0)
	assert_eq(int(buf[(7 * 8 + 7) * 4 + 3]), 255)
	fog.reset_visibility()
	buf = UnitVisual.fog_rgba_bytes(fog, buf)
	assert_eq(int(buf[(2 * 8 + 2) * 4 + 3]), 140)

	# 8x sub-tile terrain builds shoreline foam where SEA meets PLAINS and renders all biomes.
	var m := MapData.new(12, 12)
	for i in range(12):
		m.set_terrain(i, 0, i % 12)
	m.set_terrain(5, 5, MapData.Terrain.SEA)
	m.set_terrain(6, 5, MapData.Terrain.PLAINS)
	var img8 := UnitVisual.build_terrain_map_image(m, 8)
	assert_eq(img8.get_width(), 96)
	assert_eq(img8.get_height(), 96)
	# Eastern edge pixel of the SEA tile bordering PLAINS has bright coastal foam.
	var foam := img8.get_pixel(5 * 8 + 7, 5 * 8 + 4)
	assert_gt(foam.b, 0.85)
	assert_gt(foam.g, 0.80)

	var mm_bytes := UnitVisual.minimap_rgba_bytes(m, fog, true)
	assert_eq(mm_bytes.size(), 12 * 12 * 4)

func test_unit_lod_texture_water_shader_and_500_unit_benchmark():
	assert_false(UnitVisual.should_batch_unit_lod(1.0, 120))
	assert_true(UnitVisual.should_batch_unit_lod(0.5, 50))
	assert_true(UnitVisual.should_batch_unit_lod(1.0, 350))

	UnitVisual.clear_shared_cache()
	var lod1 := UnitVisual.get_unit_lod_texture(24)
	var lod2 := UnitVisual.get_unit_lod_texture(24)
	assert_not_null(lod1)
	assert_eq(lod1, lod2)
	assert_gt(lod1.get_image().get_pixel(12, 12).a, 0.8)

	var shader_src := UnitVisual.water_shimmer_shader_code()
	assert_true(shader_src.contains("u_shimmer_strength"))
	assert_true(shader_src.contains("u_weather_tint"))

	# 500-unit performance regression benchmark: spatial hash + 128x128 fog + 64x64 terrain.
	var t0 := Time.get_ticks_msec()
	var positions: Array = []
	for i in range(500):
		positions.append(Vector2(float((i % 25) * 40 + 32), float(int(float(i) / 25.0) * 40 + 32)))
	var grid := UnitVisual.build_spatial_grid(positions, 128.0)
	var total_hits := 0
	for q in range(50):
		total_hits += UnitVisual.query_spatial_radius(grid, positions, positions[q * 10], 110.0, 128.0).size()
	var big_fog := FogOfWar.new(128, 128)
	big_fog.mark_visible(64, 64, 10)
	var fog_buf := UnitVisual.fog_rgba_bytes(big_fog)
	var bench_map := TerrainGenerator.generate_islands(64, 64, 77)
	var terrain_img := UnitVisual.build_terrain_map_image(bench_map, 4)
	var elapsed_ms := Time.get_ticks_msec() - t0
	assert_gt(total_hits, 50)
	assert_eq(fog_buf.size(), 128 * 128 * 4)
	assert_eq(terrain_img.get_width(), 256)
	assert_lt(elapsed_ms, 3000, "500-unit visual/spatial/fog/terrain benchmark should complete well under 3s (took %dms)" % elapsed_ms)
	UnitVisual.clear_shared_cache()

