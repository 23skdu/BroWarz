extends SceneTree

func _terrain_color(t: int) -> Color:
	match t:
		MapData.Terrain.PLAINS: return Color(0.35, 0.55, 0.25)
		MapData.Terrain.FOREST: return Color(0.18, 0.4, 0.18)
		MapData.Terrain.SWAMP: return Color(0.3, 0.35, 0.2)
		MapData.Terrain.RIVER: return Color(0.2, 0.4, 0.75)
		MapData.Terrain.SEA: return Color(0.1, 0.25, 0.55)
		MapData.Terrain.MOUNTAIN: return Color(0.5, 0.5, 0.5)
		MapData.Terrain.URBAN: return Color(0.45, 0.4, 0.35)
		MapData.Terrain.ROAD: return Color(0.6, 0.55, 0.4)
		MapData.Terrain.BRIDGE: return Color(0.6, 0.5, 0.3)
		MapData.Terrain.WASTELAND: return Color(0.35, 0.2, 0.15)
	return Color(0.3, 0.3, 0.3)

func _init():
	DirAccess.make_dir_recursive_absolute("res://docs/map_thumbnails")
	var maps := {
		"desert": TerrainGenerator.generate_desert(128, 128, 1),
		"islands": TerrainGenerator.generate_islands(128, 128, 2),
		"forest": TerrainGenerator.generate_forest(128, 128, 3),
	}
	for name in maps.keys():
		var m: MapData = maps[name]
		var img := Image.create(m.width, m.height, false, Image.FORMAT_RGBA8)
		for y in range(m.height):
			for x in range(m.width):
				img.set_pixel(x, y, _terrain_color(m.get_terrain(x, y)))
		img.save_png("res://docs/map_thumbnails/%s.png" % name)
		print("saved ", name)
	quit()
