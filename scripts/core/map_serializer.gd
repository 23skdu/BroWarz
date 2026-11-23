# scripts/core/map_serializer.gd
class_name MapSerializer
extends RefCounted

static func to_dict(map: MapData) -> Dictionary:
	return {
		"name": map.name,
		"author": map.author,
		"width": map.width,
		"height": map.height,
		"tiles": Array(map.tiles),
	}

static func from_dict(d: Dictionary) -> MapData:
	var m = MapData.new(int(d.get("width", 128)), int(d.get("height", 128)))
	m.name = String(d.get("name", "Untitled"))
	m.author = String(d.get("author", "Unknown"))
	var t: Array = d.get("tiles", [])
	if t.size() == m.tile_count():
		for i in range(t.size()):
			m.tiles[i] = int(t[i])
	return m

static func validate(d: Dictionary) -> bool:
	if not d.has("width") or not d.has("height"):
		return false
	var w = int(d.get("width", 0))
	var h = int(d.get("height", 0))
	if w <= 0 or h <= 0 or w > 512 or h > 512:
		return false
	var t: Array = d.get("tiles", [])
	if t.size() != w * h:
		return false
	return true
