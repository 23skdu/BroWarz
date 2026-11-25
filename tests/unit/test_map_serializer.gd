# tests/unit/test_map_serializer.gd
extends GutTest

func test_roundtrip():
	var m = MapData.new(4, 4)
	m.name = "Test"
	m.set_terrain(1, 1, MapData.Terrain.SWAMP)
	var d = MapSerializer.to_dict(m)
	var m2 = MapSerializer.from_dict(d)
	assert_eq(m2.name, "Test")
	assert_eq(m2.get_terrain(1, 1), MapData.Terrain.SWAMP)
	assert_eq(m2.width, 4)

func test_validate_ok():
	var m = MapData.new(2, 2)
	var d = MapSerializer.to_dict(m)
	assert_true(MapSerializer.validate(d))

func test_validate_bad_size():
	var d = {"width": 2, "height": 2, "tiles": [0,0,0]}
	assert_false(MapSerializer.validate(d))

func test_validate_bad_dims():
	assert_false(MapSerializer.validate({"width": 0, "height": 2, "tiles": []}))

func test_share_code_and_file_roundtrip():
	var m := MapData.new(16, 16)
	m.name = "Oasis Basin"
	m.author = "Alice"
	m.set_terrain(3, 4, MapData.Terrain.SEA)
	m.set_terrain(5, 6, MapData.Terrain.DESERT)
	m.set_terrain(7, 8, MapData.Terrain.HILLS)
	m.set_terrain(9, 10, MapData.Terrain.FOREST)
	var code := MapSerializer.to_share_code(m)
	assert_true(code.begins_with("BWM1:"))
	var m2 := MapSerializer.from_share_code(code)
	assert_not_null(m2)
	assert_eq(m2.name, "Oasis Basin")
	assert_eq(m2.author, "Alice")
	assert_eq(m2.get_terrain(3, 4), MapData.Terrain.SEA)
	assert_eq(m2.get_terrain(5, 6), MapData.Terrain.DESERT)
	assert_eq(m2.get_terrain(7, 8), MapData.Terrain.HILLS)
	assert_eq(m2.get_terrain(9, 10), MapData.Terrain.FOREST)
	assert_null(MapSerializer.from_share_code("INVALID"))

func test_metadata_roundtrip_dict_and_share_code():
	var m := MapData.new(16, 16)
	m.set_hq_spawn(0, 2, 2)
	m.set_hq_spawn(1, 13, 13)
	m.add_deposit(Economy.Res.OIL, 3, 2, 800, 12.0)
	m.add_deposit(Economy.Res.FOOD, 12, 13)
	var d := MapSerializer.to_dict(m)
	var from_dict := MapSerializer.from_dict(d)
	assert_eq(from_dict.hq_spawns.size(), 2)
	assert_eq(from_dict.get_hq_spawn(1), Vector2i(13, 13))
	assert_eq(from_dict.deposits.size(), 2)
	assert_eq(int(from_dict.deposits[0].get("amount", 0)), 800)
	var from_code := MapSerializer.from_share_code(MapSerializer.to_share_code(m))
	assert_not_null(from_code)
	assert_eq(from_code.get_hq_spawn(0), Vector2i(2, 2))
	assert_eq(int(from_code.deposits[0].get("type", -1)), Economy.Res.OIL)

func test_legacy_metadata_defaults():
	var legacy := {"width": 16, "height": 16, "tiles": MapData.new(16, 16).tiles}
	var m := MapSerializer.from_dict(legacy)
	assert_true(m.hq_spawns.is_empty())
	assert_true(m.deposits.is_empty())

func test_validate_detailed_reports_specific_causes():
	var bad_tiles := MapSerializer.validate_detailed({"width": 2, "height": 2, "tiles": [0, 0, 0]})
	assert_false(bool(bad_tiles.get("ok", true)))
	assert_true(String(bad_tiles.get("reason", "")).contains("Expected 4 tiles"))
	var bad_tile := MapSerializer.validate_detailed({"width": 1, "height": 1, "tiles": [99]})
	assert_false(bool(bad_tile.get("ok", true)))
	assert_true(String(bad_tile.get("reason", "")).contains("unknown terrain id"))
	var good := MapSerializer.validate_detailed(MapSerializer.to_dict(MapData.new(2, 2)))
	assert_true(bool(good.get("ok", false)))

func test_share_code_errors_are_actionable():
	assert_true(String(MapSerializer.from_share_code_detailed("").get("reason", "")).contains("Paste a share code"))
	assert_true(String(MapSerializer.from_share_code_detailed("INVALID").get("reason", "")).contains("BWM1:"))
	assert_true(String(MapSerializer.from_share_code_detailed("BWM1:broken").get("reason", "")).contains("payload length"))
	var bad_base64 := MapSerializer.from_share_code_detailed("BWM1:10:x")
	assert_engine_error_count(1, "expected one engine error for invalid Base64")
	assert_true(String(bad_base64.get("reason", "")).contains("Base64"))

func test_save_and_load_results_report_paths_and_errors():
	var path := "user://maps/test_detailed_result.bwm"
	var m := MapData.new(16, 16)
	m.name = "Detailed Result"
	var saved := MapSerializer.save_with_result(m, path)
	assert_true(bool(saved.get("ok", false)))
	assert_eq(String(saved.get("path", "")), path)
	var loaded := MapSerializer.load_with_result(path)
	assert_true(bool(loaded.get("ok", false)))
	assert_true(String(loaded.get("reason", "")).contains("Detailed Result"))
	assert_false(bool(MapSerializer.load_with_result("user://maps/does_not_exist.bwm").get("ok", true)))
	assert_false(bool(MapSerializer.save_with_result(null, path).get("ok", true)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

