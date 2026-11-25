# tests/unit/test_building_visual.gd
extends GutTest

func test_every_registered_building_has_a_unique_sprite():
	var reg := UnitRegistry.new()
	reg.populate_defaults()
	var seen: Dictionary = {}
	for bid in reg.buildings.keys():
		var img := BuildingVisual.build_building_frame_image(bid, Faction.color_of(0), 48)
		assert_eq(img.get_width(), 48)
		assert_eq(img.get_height(), 48)
		var data := img.get_data()
		assert_false(seen.has(data), "duplicate building sprite for %s" % bid)
		seen[data] = bid

func test_faction_thumbnails_exist_for_every_building():
	var reg := UnitRegistry.new()
	reg.populate_defaults()
	for bid in reg.buildings.keys():
		for f in range(4):
			var path := "res://docs/thumbnails/buildings/%s_f%d.png" % [bid, f]
			assert_true(FileAccess.file_exists(path), "missing %s" % path)

func test_texture_cache_and_unknown_ids():
	BuildingVisual.clear_cache()
	var t1 := BuildingVisual.get_cached_building_texture("hq", Faction.color_of(0))
	var t2 := BuildingVisual.get_cached_building_texture("hq", Faction.color_of(0))
	assert_eq(t1, t2)
	assert_eq(BuildingVisual.shared_cache_size(), 1)
	var unknown := BuildingVisual.build_building_frame_image("unknown_structure", Faction.color_of(1), 32)
	assert_eq(unknown.get_width(), 32)
	var scaled := BuildingVisual.build_building_frame_image("hq", Faction.color_of(1), 64)
	assert_eq(scaled.get_height(), 64)
