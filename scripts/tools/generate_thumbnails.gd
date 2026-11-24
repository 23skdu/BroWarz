extends SceneTree

func _init():
	var classes := [0, 1, 2, 3, 4, 5, 6, 7]
	var class_names := {
		0: "infantry", 1: "vehicle", 2: "naval", 3: "air",
		4: "hovercraft", 5: "frogman", 6: "heavy_infantry", 7: "heavy_mech"
	}
	var factions := [0, 1, 2, 3]
	var faction_colors := {
		0: Faction.color_of(0),
		1: Faction.color_of(1),
		2: Faction.color_of(2),
		3: Faction.color_of(3),
	}
	DirAccess.make_dir_recursive_absolute("res://docs/thumbnails")
	for uc in classes:
		for f in factions:
			var col: Color = faction_colors[f]
			var img := UnitVisual.build_unit_frame_image(uc, 0, 0, col, 32)
			var path := "res://docs/thumbnails/%s_f%d.png" % [class_names[uc], f]
			img.save_png(path)
			print("saved ", path)
	quit()
