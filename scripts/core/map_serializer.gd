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

## Structured validation used by file/share-code loaders and the editor UI.
## Returns {ok: bool, reason: String} with a human-readable failure message.
static func validate_detailed(raw: Variant) -> Dictionary:
	if not (raw is Dictionary):
		return {"ok": false, "reason": "Map payload is not an object"}
	var d := raw as Dictionary
	if not d.has("width") or not d.has("height"):
		return {"ok": false, "reason": "Map is missing width or height"}
	var wv: Variant = d.get("width")
	var hv: Variant = d.get("height")
	if not ((wv is int) or (wv is float)) or not ((hv is int) or (hv is float)):
		return {"ok": false, "reason": "Map dimensions must be numbers"}
	var w := int(wv)
	var h := int(hv)
	if w <= 0 or h <= 0 or w > 512 or h > 512:
		return {"ok": false, "reason": "Map dimensions %dx%d are outside 1..512" % [w, h]}
	if not d.has("tiles") or not (d.get("tiles") is Array):
		return {"ok": false, "reason": "Map has no tile array"}
	var tiles: Array = d.get("tiles")
	if tiles.size() != w * h:
		return {"ok": false, "reason": "Expected %d tiles, found %d" % [w * h, tiles.size()]}
	for i in range(tiles.size()):
		var tile: Variant = tiles[i]
		if not ((tile is int) or (tile is float)):
			return {"ok": false, "reason": "Tile %d is not a number" % i}
		var tid := int(tile)
		if tid < 0 or tid > MapData.Terrain.HILLS:
			return {"ok": false, "reason": "Tile %d has unknown terrain id %d" % [i, tid]}
	for key in ["spawns", "deposits"]:
		if d.has(key) and not (d.get(key) is Array):
			return {"ok": false, "reason": "'%s' must be an array" % key}
	return {"ok": true, "reason": "OK"}

static func validate(d: Dictionary) -> bool:
	return bool(validate_detailed(d).get("ok", false))

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

## Share-code import with a reason instead of a silent null.
static func from_share_code_detailed(code: String) -> Dictionary:
	var clean := code.strip_edges()
	if clean.is_empty():
		return {"ok": false, "reason": "Paste a share code or choose Copy Share Code first"}
	if not clean.begins_with(SHARE_PREFIX):
		return {"ok": false, "reason": "Share code must start with '%s'" % SHARE_PREFIX}
	var rest := clean.substr(SHARE_PREFIX.length())
	var sep := rest.find(":")
	if sep <= 0:
		return {"ok": false, "reason": "Share code is missing the payload length separator"}
	var raw_len := int(rest.substr(0, sep))
	if raw_len <= 0 or raw_len > 2097152:
		return {"ok": false, "reason": "Share code payload length is invalid"}
	var b64 := rest.substr(sep + 1)
	if b64.is_empty():
		return {"ok": false, "reason": "Share code payload is empty"}
	var compressed := Marshalls.base64_to_raw(b64)
	if compressed.is_empty():
		return {"ok": false, "reason": "Share code is not valid Base64"}
	var raw := compressed.decompress(raw_len, FileAccess.COMPRESSION_DEFLATE)
	if raw.is_empty():
		return {"ok": false, "reason": "Share code decompression failed or payload length mismatch"}
	var parsed = JSON.parse_string(raw.get_string_from_utf8())
	if not (parsed is Dictionary):
		return {"ok": false, "reason": "Share code payload is not valid JSON"}
	var d := parsed as Dictionary
	var tb64 := String(d.get("tiles_b64", ""))
	var tbytes := Marshalls.base64_to_raw(tb64)
	if tbytes.size() != int(d.get("width", 0)) * int(d.get("height", 0)):
		return {"ok": false, "reason": "Share code tile data is truncated or corrupt"}
	var check := validate_detailed({
		"width": d.get("width"), "height": d.get("height"),
		"tiles": Array(tbytes), "spawns": d.get("spawns", []),
		"deposits": d.get("deposits", []),
	})
	if not bool(check.get("ok", false)):
		return {"ok": false, "reason": "Invalid shared map: %s" % str(check.get("reason", "unknown"))}
	var m := MapData.new(int(d.get("width")), int(d.get("height")))
	m.name = String(d.get("name", "Shared Map"))
	m.author = String(d.get("author", "Commander"))
	m.tiles = tbytes
	apply_metadata(m, d)
	return {"ok": true, "map": m, "reason": "OK"}

static func from_share_code(code: String) -> MapData:
	var result := from_share_code_detailed(code)
	return result.get("map", null) as MapData

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

## Save with a structured result the editor can show verbatim.
static func save_with_result(map: MapData, path: String = "", update_default: bool = true) -> Dictionary:
	if map == null:
		return {"ok": false, "reason": "No map is open"}
	if map.width <= 0 or map.height <= 0 or map.tiles.size() != map.width * map.height:
		return {"ok": false, "reason": "Map dimensions and tile data do not match"}
	var dir_err := DirAccess.make_dir_recursive_absolute(MAPS_DIR)
	if dir_err != OK:
		return {"ok": false, "reason": "Cannot create %s: %s" % [MAPS_DIR, error_string(dir_err)]}
	var target := path
	if target.is_empty():
		target = "%s/%s.bwm" % [MAPS_DIR, sanitize_filename(map.name)]
	var f := FileAccess.open(target, FileAccess.WRITE)
	if f == null:
		return {"ok": false, "reason": "Cannot write %s: %s" % [target, error_string(FileAccess.get_open_error())]}
	var content := JSON.stringify(to_dict(map))
	f.store_string(content)
	f.close()
	# A failed default write must not silently break the main-menu Custom Map.
	if update_default:
		var def := FileAccess.open("user://custom_map.bwm", FileAccess.WRITE)
		if def == null:
			return {
				"ok": false,
				"reason": "Saved %s but could not update the quick-load default: %s" % [
					target, error_string(FileAccess.get_open_error()),
				],
			}
		def.store_string(content)
		def.close()
	return {"ok": true, "path": target, "reason": "Saved %s" % target}

## Load with structured errors: missing file, unreadable file, invalid JSON,
## invalid dimensions/tiles are all reported with actionable text.
static func load_with_result(path: String) -> Dictionary:
	if path.is_empty():
		return {"ok": false, "reason": "No map path supplied"}
	if not FileAccess.file_exists(path):
		return {"ok": false, "reason": "No map file at %s" % path}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"ok": false, "reason": "Cannot open %s: %s" % [path, error_string(FileAccess.get_open_error())]}
	var text := f.get_as_text()
	f.close()
	if text.strip_edges().is_empty():
		return {"ok": false, "reason": "%s is empty" % path}
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return {"ok": false, "reason": "%s is not a valid JSON map" % path}
	var check := validate_detailed(parsed)
	if not bool(check.get("ok", false)):
		return {"ok": false, "reason": "Invalid map in %s: %s" % [path, str(check.get("reason", "unknown"))]}
	var map := from_dict(parsed as Dictionary)
	var playability := MapData.validate_map(map)
	return {
		"ok": true,
		"map": map,
		"reason": "Loaded '%s' from %s" % [map.name, path],
		"playable": bool(playability.get("ok", false)),
		"playability_reason": String(playability.get("reason", "")),
	}

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
