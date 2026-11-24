extends SceneTree

func _init():
	DirAccess.make_dir_recursive_absolute("res://docs/thumbnails")
	var reg := UnitRegistry.new()
	reg.populate_defaults()
	for uid in reg.units.keys():
		var s: UnitStats = reg.units[uid]
		for f in range(4):
			var col := Faction.color_of(f)
			var img := UnitVisual.build_unit_frame_image(s.unit_class, 0, 0, col, 32, uid)
			var path := "res://docs/thumbnails/%s_f%d.png" % [uid, f]
			img.save_png(path)
			print("saved ", path)
	quit()
