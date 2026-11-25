extends SceneTree

func _init():
	DirAccess.make_dir_recursive_absolute("res://docs/thumbnails")
	DirAccess.make_dir_recursive_absolute("res://docs/thumbnails/buildings")
	var reg := UnitRegistry.new()
	reg.populate_defaults()
	for uid in reg.units.keys():
		var s: UnitStats = reg.units[uid]
		var factions_to_render: Array = [s.native_faction] if (s.ai_only and s.native_faction >= 4) else [0, 1, 2, 3]
		for f in factions_to_render:
			var col := Faction.color_of(int(f))
			var img := UnitVisual.build_unit_frame_image(s.unit_class, 0, 0, col, 64, uid)
			var path := "res://docs/thumbnails/%s_f%d.png" % [uid, int(f)]
			img.save_png(path)
			print("saved ", path)
	for bid in reg.buildings.keys():
		for f in range(4):
			var col := Faction.color_of(f)
			var img := BuildingVisual.build_building_frame_image(bid, col, 64)
			var path := "res://docs/thumbnails/buildings/%s_f%d.png" % [bid, f]
			img.save_png(path)
			print("saved ", path)
	quit()
