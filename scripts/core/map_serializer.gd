# scripts/core/map_serializer.gd
class_name MapSerializer
extends RefCounted

const SHARE_PREFIX := "BWM1:"
const MAPS_DIR := "user://maps"

static func to_dict(map: MapData) -> Dictionary:
	return {
		"name": map.name,
		"author": map.author,
		"width": map.width,
		"height": map.height,
		"tiles": Array(map.tiles),
		"spawns": _spawns_to_array(map),
		"deposits": _deposits_to_array(map),
	}

static func from_dict(d: Dictionary) -> MapData:
	var m := MapData.new(int(d.get("width", 128)), int(d.get("height", 128)))
	m.name = String(d.get("name", "Untitled"))
	m.author = String(d.get("author", "Unknown"))
	var t: Array = d.get("tiles", [])
	if t.size() == m.tile_count():
		for i in range(t.size()):
			m.tiles[i] = int(t[i])
	apply_metadata(m, d)
	return m

static func _spawns_to_array(map: MapData) -> Array:
	var out: Array = []
	for s in map.hq_spawns:
		out.append({
			"team": int(s.get("team", 0)),
			"x": int(s.get("x", 0)),
			"y": int(s.get("y", 0)),
		})
	return out

static func _deposits_to_array(map: MapData) -> Array:
	var out: Array = []
	for d in map.deposits:
		out.append({
			"type": int(d.get("type", 0)),
			"x": int(d.get("x", 0)),
			"y": int(d.get("y", 0)),
			"amount": int(d.get("amount", 1000)),
			"rate": float(d.get("rate", 10.0)),
		})
	return out

## Restore HQ spawns and resource deposits from a serialized dictionary.
## Missing or malformed metadata is ignored so older maps still load.
static func apply_metadata(map: MapData, d: Dictionary) -> void:
	map.hq_spawns.clear()
	map.deposits.clear()
	for s in d.get("spawns", []):
		if not (s is Dictionary):
			continue
		var team := int(s.get("team", -1))
		var x := int(s.get("x", -1))
		var y := int(s.get("y", -1))
		if team >= 0 and team < MapData.MAX_TEAMS and map.in_bounds(x, y):
			map.hq_spawns.append({"team": team, "x": x, "y": y})
	for dep in d.get("deposits", []):
		if not (dep is Dictionary):
			continue
		var type := int(dep.get("type", -1))
		var x := int(dep.get("x", -1))
		var y := int(dep.get("y", -1))
		if type >= 0 and type < 4 and map.in_bounds(x, y):
			map.deposits.append({
				"type": type,
				"x": x,
				"y": y,
				"amount": int(dep.get("amount", 1000)),
				"rate": float(dep.get("rate", 10.0)),
			})

static func validate(d: Dictionary) -> bool:
	if not d.has("width") or not d.has("height"):
		return false
	var w := int(d.get("width", 0))
	var h := int(d.get("height", 0))
	if w <= 0 or h <= 0 or w > 512 or h > 512:
		return false
	var t: Array = d.get("tiles", [])
	if t.size() != w * h:
		return false
	return true

static func to_share_code(map: MapData) -> String:
	# Compresses the map dictionary withDEFLATE and encodes as a portable Base64 share string.
	var payload := {
		"name": map.name,
		"author": map.author,
		"width": map.width,
		"height": map.height,
		"tiles_b64": Marshalls.raw_to_base64(map.tiles),
		"spawns": _spawns_to_array(map),
		"deposits": _deposits_to_array(map),
	}
	var raw := JSON.stringify(payload).to_utf8_buffer()
	var compressed := raw.compress(FileAccess.COMPRESSION_DEFLATE)
	return "%s%d:%s" % [SHARE_PREFIX, raw.size(), Marshalls.raw_to_base64(compressed)]

static func from_share_code(code: String) -> MapData:
	var clean := code.strip_edges()
	if not clean.begins_with(SHARE_PREFIX):
		return null
	var rest := clean.substr(SHARE_PREFIX.length())
	var sep := rest.find(":")
	if sep <= 0:
		return null
	var raw_len := int(rest.substr(0, sep))
	if raw_len <= 0 or raw_len > 2097152:
		return null
	var b64 := rest.substr(sep + 1)
	var compressed := Marshalls.base64_to_raw(b64)
	if compressed.is_empty():
		return null
	var raw := compressed.decompress(raw_len, FileAccess.COMPRESSION_DEFLATE)
	if raw.is_empty():
		return null
	var parsed = JSON.parse_string(raw.get_string_from_utf8())
	if not (parsed is Dictionary):
		return null
	var d: Dictionary = parsed
	var w := int(d.get("width", 0))
	var h := int(d.get("height", 0))
	if w <= 0 or h <= 0 or w > 512 or h > 512:
		return null
	var tb64 := String(d.get("tiles_b64", ""))
	var tbytes := Marshalls.base64_to_raw(tb64)
	if tbytes.size() != w * h:
		return null
	var m := MapData.new(w, h)
	m.name = String(d.get("name", "Shared Map"))
	m.author = String(d.get("author", "Commander"))
	m.tiles = tbytes
	apply_metadata(m, d)
	return m

static func sanitize_filename(raw_name: String) -> String:
	var out := ""
	for i in range(raw_name.length()):
		var ch := raw_name.substr(i, 1).to_lower()
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") or ch == "_" or ch == "-":
			out += ch
		elif ch == " ":
			out += "_"
	if out.is_empty():
		out = "custom_map"
	return out.substr(0, 40)

static func save_to_file(map: MapData, path: String = "") -> Error:
	DirAccess.make_dir_recursive_absolute(MAPS_DIR)
	var target := path
	if target.is_empty():
		target = "%s/%s.bwm" % [MAPS_DIR, sanitize_filename(map.name)]
	var f := FileAccess.open(target, FileAccess.WRITE)
	if f == null:
		return ERR_CANT_OPEN
	var content := JSON.stringify(to_dict(map))
	f.store_string(content)
	f.close()
	# Also keep user://custom_map.bwm in sync as the quick-load default
	var f_def := FileAccess.open("user://custom_map.bwm", FileAccess.WRITE)
	if f_def != null:
		f_def.store_string(content)
		f_def.close()
	return OK

static func load_from_file(path: String) -> MapData:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary and validate(parsed):
		return from_dict(parsed)
	return null

static func list_saved_maps() -> Array[String]:
	var files: Array[String] = []
	if not DirAccess.dir_exists_absolute(MAPS_DIR):
		return files
	var dir := DirAccess.open(MAPS_DIR)
	if dir == null:
		return files
	dir.list_dir_begin()
	var fn := dir.get_next()
	while fn != "":
		if not dir.current_is_dir() and fn.ends_with(".bwm"):
			files.append("%s/%s" % [MAPS_DIR, fn])
		fn = dir.get_next()
	dir.list_dir_end()
	files.sort()
	return files
