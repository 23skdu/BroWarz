# scripts/core/net_security.gd
class_name NetSecurity
extends RefCounted

# Validation and sanitization helpers for the P2P lobby and command pipeline.
# Security posture: fail closed. Unknown types, out-of-range values and
# non-whitelisted keys are dropped; callers treat an empty result as "reject".

const PROTOCOL_VERSION: int = 1
const MIN_NAME_LENGTH: int = 2
const MAX_NAME_LENGTH: int = 24
const MAX_ADDRESS_LENGTH: int = 253
const MAX_TOKEN_LENGTH: int = 64
const MAX_CMD_IDS: int = 256
const MAX_SEQ: int = 1000000000
const MAX_COORD: float = 4096.0
const MIN_PLAYERS: int = 2
const MAX_PLAYERS: int = 8
const ALLOWED_COMMAND_TYPES: Array[String] = [
	"move", "hold", "stop", "train", "build", "fortify", "tech", "laser", "nuke", "embark", "disembark",
	"capture", "demolish", "diplomacy",
]
const ALLOWED_TRANSPORTS: Array[String] = ["enet", "webrtc"]

# --- Identity -------------------------------------------------------------

## Strip control characters and non-whitelisted glyphs from a display name.
## Returns "" when the result is unusably short (caller supplies a fallback).
static func sanitize_name(raw: Variant) -> String:
	if not (raw is String):
		return ""
	var s := raw as String
	var cleaned := ""
	for i in range(s.length()):
		var code := s.unicode_at(i)
		var keep := (
			code == 32 or code == 45 or code == 46 or code == 95  # space - . _
			or (code >= 48 and code <= 57)  # 0-9
			or (code >= 65 and code <= 90)  # A-Z
			or (code >= 97 and code <= 122)  # a-z
		)
		if keep:
			cleaned += s[i]
	cleaned = cleaned.strip_edges()
	if cleaned.length() < MIN_NAME_LENGTH:
		return ""
	if cleaned.length() > MAX_NAME_LENGTH:
		cleaned = cleaned.substr(0, MAX_NAME_LENGTH)
	return cleaned

## Strict address validation before any connection attempt: hostnames and
## IPv4/IPv6 literals only, no whitespace, slashes, quotes or control bytes.
static func is_valid_address(raw: Variant) -> bool:
	if not (raw is String):
		return false
	var s := (raw as String).strip_edges()
	if s.is_empty() or s.length() > MAX_ADDRESS_LENGTH:
		return false
	var has_alnum := false
	for i in range(s.length()):
		var code := s.unicode_at(i)
		var is_alnum := (
			(code >= 48 and code <= 57)
			or (code >= 65 and code <= 90)
			or (code >= 97 and code <= 122)
		)
		var is_sep := code == 46 or code == 45 or code == 58  # . - :
		if not (is_alnum or is_sep):
			return false
		if is_alnum:
			has_alnum = true
	if not has_alnum:
		return false
	if s.begins_with(".") or s.ends_with(".") or s.contains(".."):
		return false
	if s.begins_with("-") or s.ends_with("-"):
		return false
	return true

## Privacy-preserving address for logs (last IPv4 octet / IPv6 tail masked).
## Loopback literals are kept verbatim: they carry no host information.
static func mask_address(addr: Variant) -> String:
	if not (addr is String):
		return "<none>"
	var s := (addr as String).strip_edges()
	if s.is_empty():
		return "<none>"
	if s == "127.0.0.1" or s == "::1" or s == "localhost":
		return s
	var parts := s.split(".")
	if parts.size() == 4:
		var all_digits := true
		for p in parts:
			if p.is_empty() or not p.is_valid_int():
				all_digits = false
				break
		if all_digits:
			return "%s.%s.%s.*" % [parts[0], parts[1], parts[2]]
	if s.contains(":"):
		var v6 := s.split(":")
		if v6.size() >= 2:
			return "%s:%s:***" % [v6[0], v6[1]]
	var dot := s.find(".")
	if dot > 0:
		return s.substr(0, dot) + ".***"
	return "***"

## Cryptographically random hex token (resume tokens, session nonces).
static func new_token(length: int = 32) -> String:
	var crypto := Crypto.new()
	var bytes := crypto.generate_random_bytes(length)
	var out := ""
	for b in bytes:
		out += "%02x" % b
	return out

## Length-independent-in-content comparison for secrets (passcodes/tokens).
static func constant_time_equal(a: Variant, b: Variant) -> bool:
	if not (a is String) or not (b is String):
		return false
	var sa := a as String
	var sb := b as String
	if sa.length() != sb.length():
		return false
	var diff := 0
	for i in range(sa.length()):
		diff |= sa.unicode_at(i) ^ sb.unicode_at(i)
	return diff == 0

# --- Settings -------------------------------------------------------------

## Whitelist + coerce lobby settings. Unknown keys and wrong types are
## dropped (fail closed); numeric ranges are clamped to safe bounds.
static func sanitize_settings(raw: Variant) -> Dictionary:
	var out := {}
	if not (raw is Dictionary):
		return out
	var d := raw as Dictionary
	if d.has("map_type"):
		var v = d["map_type"]
		if (v is int) or (v is float):
			out["map_type"] = clampi(int(v), 0, 2)
	if d.has("num_teams"):
		var v2 = d["num_teams"]
		if (v2 is int) or (v2 is float):
			out["num_teams"] = clampi(int(v2), 2, 4)
	if d.has("fog_of_war"):
		var v3 = d["fog_of_war"]
		if v3 is bool:
			out["fog_of_war"] = v3
	if d.has("transport"):
		var v4 = d["transport"]
		if v4 is String:
			var t := (v4 as String).to_lower()
			if t in ALLOWED_TRANSPORTS:
				out["transport"] = t
	if d.has("alliance_mode"):
		var v5 = d["alliance_mode"]
		if (v5 is int) or (v5 is float):
			out["alliance_mode"] = clampi(int(v5), 0, 1)
	return out

## Default lobby settings used when nothing has been configured yet.
static func default_settings() -> Dictionary:
	return {
		"map_type": 2,
		"num_teams": 2,
		"fog_of_war": true,
		"transport": "enet",
		"alliance_mode": 0,
	}

# --- Hello handshake ------------------------------------------------------

## Validate a hello payload on the host. Returns {ok: bool, reason: String,
## name: String}. The passcode check uses a constant-time comparison.
static func validate_hello(
	protocol_version: Variant,
	passcode: Variant,
	player_name: Variant,
	addr: Variant,
	expected_passcode: String,
) -> Dictionary:
	if not ((protocol_version is int) or (protocol_version is float)):
		return {"ok": false, "reason": "bad protocol", "name": ""}
	if int(protocol_version) != PROTOCOL_VERSION:
		return {"ok": false, "reason": "protocol mismatch", "name": ""}
	if not (passcode is String):
		return {"ok": false, "reason": "bad passcode", "name": ""}
	if not expected_passcode.is_empty():
		if not constant_time_equal(passcode as String, expected_passcode):
			return {"ok": false, "reason": "passcode rejected", "name": ""}
	if not is_valid_address(addr):
		return {"ok": false, "reason": "bad address", "name": ""}
	var clean := sanitize_name(player_name)
	return {"ok": true, "reason": "", "name": clean}

# --- Commands -------------------------------------------------------------

## Whitelist a gameplay command dictionary. Returns {} when the payload is
## malformed, carries an unknown type, or contains out-of-range values.
## The "team" key is optional here: the host overwrites it authoritatively
## from the sender's lobby record and clients re-sanitize the relayed copy.
static func sanitize_command(raw: Variant) -> Dictionary:
	if not (raw is Dictionary):
		return {}
	var d := raw as Dictionary
	var ctype = d.get("type", null)
	if not (ctype is String):
		return {}
	if not (ctype in ALLOWED_COMMAND_TYPES):
		return {}
	var seq := _opt_int(d, "seq", -1)
	if seq < 0 or seq > MAX_SEQ:
		return {}
	var out := {"type": ctype, "seq": seq}
	if d.has("team"):
		var team := _opt_int(d, "team", -1)
		if team < 0 or team > 7:
			return {}
		out["team"] = team
	match ctype:
		"move", "hold", "stop", "embark", "disembark":
			var ids := _sanitize_ids(d.get("unit_ids", null))
			if ids.is_empty():
				return {}
			out["unit_ids"] = ids
			if ctype == "move":
				var tx := _opt_float(d, "target_x", NAN)
				var ty := _opt_float(d, "target_y", NAN)
				if is_nan(tx) or is_nan(ty):
					return {}
				out["target_x"] = clampf(tx, 0.0, MAX_COORD)
				out["target_y"] = clampf(ty, 0.0, MAX_COORD)
				var am = d.get("attack_move", true)
				out["attack_move"] = am if (am is bool) else true
		"train", "build", "fortify":
			var id = d.get("id", null)
			if not (id is String) or not _is_id(id as String):
				return {}
			out["id"] = id
			if ctype == "fortify":
				var fx := _opt_float(d, "x", NAN)
				var fy := _opt_float(d, "y", NAN)
				if is_nan(fx) or is_nan(fy):
					return {}
				out["x"] = clampf(fx, 0.0, MAX_COORD)
				out["y"] = clampf(fy, 0.0, MAX_COORD)
		"tech":
			if d.has("id"):
				var tech_id = d.get("id", null)
				if tech_id is String and _is_id(tech_id as String):
					out["id"] = tech_id
		"capture":
			var ids := _sanitize_ids(d.get("unit_ids", null))
			if ids.is_empty():
				return {}
			out["unit_ids"] = ids
			if not _sanitize_target(d, out):
				return {}
		"demolish":
			if not _sanitize_target(d, out):
				return {}
		"laser", "nuke":
			var lx := _opt_float(d, "x", NAN)
			var ly := _opt_float(d, "y", NAN)
			if is_nan(lx) or is_nan(ly):
				return {}
			out["x"] = clampf(lx, 0.0, MAX_COORD)
			out["y"] = clampf(ly, 0.0, MAX_COORD)
		"diplomacy":
			var action = d.get("action", null)
			if not (action is String) or not Alliance.ACTIONS.has(action):
				return {}
			out["action"] = action
			var target := _opt_int(d, "target_team", -1)
			if target < 0 or target > 7:
				return {}
			out["target_team"] = target
	return out

## Accept both local target_x/target_y input and relayed x/y coordinates.
static func _sanitize_target(d: Dictionary, out: Dictionary) -> bool:
	var tx := _opt_float(d, "target_x", _opt_float(d, "x", NAN))
	var ty := _opt_float(d, "target_y", _opt_float(d, "y", NAN))
	if is_nan(tx) or is_nan(ty):
		return false
	out["x"] = clampf(tx, 0.0, MAX_COORD)
	out["y"] = clampf(ty, 0.0, MAX_COORD)
	return true

static func _sanitize_ids(raw: Variant) -> Array:
	var out: Array = []
	if not (raw is Array):
		return out
	for v in raw as Array:
		if not ((v is int) or (v is float)):
			return []  # one bad entry rejects the whole batch
		var n := int(v)
		if n <= 0 or n > MAX_SEQ:
			return []
		if not out.has(n):
			out.append(n)
		if out.size() >= MAX_CMD_IDS:
			break
	return out

static func _is_id(s: String) -> bool:
	if s.is_empty() or s.length() > 32:
		return false
	for i in range(s.length()):
		var code := s.unicode_at(i)
		var lower := code >= 97 and code <= 122
		var digit := code >= 48 and code <= 57
		var underscore := code == 95
		if not (lower or digit or underscore):
			return false
		if i == 0 and not lower:
			return false
	return true

static func _opt_int(d: Dictionary, key: String, fallback: int) -> int:
	if not d.has(key):
		return fallback
	var v = d[key]
	if (v is int) or (v is float):
		return int(v)
	return fallback

static func _opt_float(d: Dictionary, key: String, fallback: float) -> float:
	if not d.has(key):
		return fallback
	var v = d[key]
	if (v is int) or (v is float):
		return float(v)
	return fallback
