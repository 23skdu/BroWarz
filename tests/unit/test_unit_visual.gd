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

