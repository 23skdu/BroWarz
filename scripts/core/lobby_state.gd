# scripts/core/lobby_state.gd
class_name LobbyState
extends RefCounted

# Host-authoritative lobby model: players, teams, match settings, ready
# gating, disconnect grace period and host migration. Pure logic — no
# sockets — so every policy below is unit-testable.

enum Phase { LOBBY, STARTING, IN_MATCH }

signal changed

const DEFAULT_GRACE_MS: int = 30000
const DEFAULT_SETTINGS: Dictionary = {
	"map_type": 2,
	"num_teams": 2,
	"fog_of_war": true,
	"transport": "enet",
}

var phase: int = Phase.LOBBY
var host_id: int = 1
var next_host_id: int = 1
var settings: Dictionary = {}
var players: Dictionary = {}  # peer id -> {name, team, ready, addr, token, connected, dropped_at}
var grace_ms: int = DEFAULT_GRACE_MS

func _init() -> void:
	settings = DEFAULT_SETTINGS.duplicate()

func reset() -> void:
	phase = Phase.LOBBY
	host_id = 1
	next_host_id = 1
	settings = DEFAULT_SETTINGS.duplicate()
	players.clear()

# --- Membership -----------------------------------------------------------

## Validate and admit a new peer. Returns {ok: bool, reason: String}.
func add_player(peer_id: int, raw_name: Variant, addr: Variant, now_ms: float = 0.0) -> Dictionary:
	if peer_id <= 0:
		return {"ok": false, "reason": "bad peer id"}
	if phase != Phase.LOBBY:
		return {"ok": false, "reason": "match in progress"}
	if players.has(peer_id):
		return {"ok": false, "reason": "duplicate peer"}
	if players.size() >= NetSecurity.MAX_PLAYERS:
		return {"ok": false, "reason": "lobby full"}
	var clean := NetSecurity.sanitize_name(raw_name)
	if clean.is_empty():
		clean = "Commander-%d" % (peer_id % 100)
	players[peer_id] = {
		"name": clean,
		"team": 0,
		"ready": false,
		"addr": str(addr) if addr is String else "",
		"token": NetSecurity.new_token(),
		"connected": true,
		"dropped_at": -1.0,
	}
	_reassign_teams()
	_refresh_next_host()
	changed.emit()
	return {"ok": true, "reason": ""}

func remove_player(peer_id: int) -> void:
	if not players.has(peer_id):
		return
	players.erase(peer_id)
	if host_id == peer_id:
		migrate_host()
	_refresh_next_host()
	changed.emit()

func has_player(peer_id: int) -> bool:
	return players.has(peer_id)

func connected_ids() -> Array:
	var out: Array = []
	for pid in players.keys():
		if players[pid]["connected"]:
			out.append(pid)
	out.sort()
	return out

func all_ids() -> Array:
	var out: Array = players.keys()
	out.sort()
	return out

func player_name(peer_id: int) -> String:
	if not players.has(peer_id):
		return ""
	return str(players[peer_id]["name"])

func team_of(peer_id: int) -> int:
	if not players.has(peer_id):
		return -1
	return int(players[peer_id]["team"])

func ready_of(peer_id: int) -> bool:
	if not players.has(peer_id):
		return false
	return bool(players[peer_id]["ready"])

func set_ready(peer_id: int, is_ready: bool) -> bool:
	if not players.has(peer_id):
		return false
	if phase != Phase.LOBBY:
		return false
	players[peer_id]["ready"] = bool(is_ready)
	changed.emit()
	return true

## Rejoin path: prove ownership of a dropped seat with the resume token
## issued at admission. Transfers the seat to the new connection's peer id.
func transfer(old_peer_id: int, new_peer_id: int, token: Variant, now_ms: float = 0.0) -> Dictionary:
	if not (token is String):
		return {"ok": false, "reason": "bad token"}
	if not players.has(old_peer_id):
		return {"ok": false, "reason": "unknown seat"}
	var record: Dictionary = players[old_peer_id]
	if not NetSecurity.constant_time_equal(str(record["token"]), token as String):
		return {"ok": false, "reason": "token rejected"}
	if bool(record["connected"]):
		return {"ok": false, "reason": "seat active"}
	if players.has(new_peer_id):
		return {"ok": false, "reason": "peer already present"}
	players.erase(old_peer_id)
	record["connected"] = true
	record["dropped_at"] = -1.0
	players[new_peer_id] = record
	_refresh_next_host()
	changed.emit()
	return {"ok": true, "reason": "", "team": int(record["team"])}

# --- Settings -------------------------------------------------------------

## Host-only settings update; payload is whitelisted/coerced first.
func update_settings(from_peer: int, raw: Variant) -> bool:
	if from_peer != host_id:
		return false
	if phase != Phase.LOBBY:
		return false
	if not (raw is Dictionary):
		return false
	var clean := NetSecurity.sanitize_settings(raw)
	for k in clean.keys():
		settings[k] = clean[k]
	_reassign_teams()
	changed.emit()
	return true

func setting(key: String, fallback = null):
	return settings.get(key, fallback)

# --- Start gate -----------------------------------------------------------

## Host-only start authorization. Returns {ok: bool, reason: String}.
func can_start(from_peer: int) -> Dictionary:
	if from_peer != host_id:
		return {"ok": false, "reason": "host only"}
	if phase != Phase.LOBBY:
		return {"ok": false, "reason": "already started"}
	var connected := connected_ids()
	if connected.size() < NetSecurity.MIN_PLAYERS:
		return {"ok": false, "reason": "need at least %d players" % NetSecurity.MIN_PLAYERS}
	for pid in connected:
		if not ready_of(pid):
			return {"ok": false, "reason": "%s is not ready" % player_name(pid)}
	return {"ok": true, "reason": ""}

## Advance to STARTING, pin the seed and re-assign teams deterministically.
func start(from_peer: int, seed_value: int) -> Dictionary:
	var gate := can_start(from_peer)
	if not gate["ok"]:
		return gate
	phase = Phase.STARTING
	settings["seed"] = seed_value
	_reassign_teams()
	changed.emit()
	return {"ok": true, "reason": ""}

func mark_in_match() -> void:
	if phase == Phase.STARTING:
		phase = Phase.IN_MATCH
		changed.emit()

# --- Disconnect grace & migration -----------------------------------------

func mark_disconnected(peer_id: int, now_ms: float) -> void:
	if not players.has(peer_id):
		return
	players[peer_id]["connected"] = false
	players[peer_id]["dropped_at"] = now_ms
	players[peer_id]["ready"] = false
	changed.emit()

func is_peer_connected(peer_id: int) -> bool:
	return players.has(peer_id) and bool(players[peer_id]["connected"])

## Seats still inside the reconnect grace window.
func in_grace(peer_id: int, now_ms: float) -> bool:
	if not players.has(peer_id):
		return false
	var rec: Dictionary = players[peer_id]
	if bool(rec["connected"]):
		return false
	var dropped_at := float(rec["dropped_at"])
	return now_ms - dropped_at <= float(grace_ms)

## Expire grace windows; returns the peer ids that were dropped for good.
func sweep(now_ms: float) -> Array:
	var expired: Array = []
	for pid in players.keys():
		var rec: Dictionary = players[pid]
		if bool(rec["connected"]):
			continue
		if now_ms - float(rec["dropped_at"]) > float(grace_ms):
			expired.append(pid)
	for pid in expired:
		players.erase(pid)
		_refresh_next_host()
	if not expired.is_empty():
		changed.emit()
	return expired

## Successor for host migration: the lowest currently connected peer id.
func migrate_host() -> int:
	var connected := connected_ids()
	if connected.is_empty():
		host_id = 0
		next_host_id = 0
		return 0
	host_id = int(connected[0])
	_refresh_next_host()
	changed.emit()
	return host_id

func _refresh_next_host() -> void:
	var connected := connected_ids()
	for pid in connected:
		if int(pid) != host_id:
			next_host_id = int(pid)
			return
	next_host_id = host_id

## Host migration: the elected successor adopts the lobby. The dead host's
## seat (id 1) is dropped, every other seat is marked disconnected so the
## surviving peers can rejoin within the grace window using their tokens.
func migrate_to(old_seat: int, token: String, now_ms: float) -> Dictionary:
	if not players.has(old_seat):
		return {"ok": false, "reason": "unknown seat"}
	var mine: Dictionary = players[old_seat]
	if not NetSecurity.constant_time_equal(str(mine["token"]), token):
		return {"ok": false, "reason": "token rejected"}
	var kept: Dictionary = {}
	for pid in players.keys():
		if int(pid) == 1 and int(pid) != int(old_seat):
			continue  # dead host seat
		var rec: Dictionary = players[pid]
		if int(pid) == int(old_seat):
			rec["connected"] = true
			rec["dropped_at"] = -1.0
		else:
			rec["connected"] = false
			rec["dropped_at"] = now_ms
		kept[pid] = rec
	players = kept
	if int(old_seat) != 1:
		var moved: Dictionary = players[old_seat]
		players.erase(old_seat)
		players[1] = moved
	host_id = 1
	_refresh_next_host()
	changed.emit()
	return {"ok": true, "reason": "", "team": int(players[1]["team"])}

# --- Team assignment ------------------------------------------------------

func _team_for_index(index: int) -> int:
	var num_teams := int(settings.get("num_teams", 2))
	return index % clampi(num_teams, 2, 4)

func _reassign_teams() -> void:
	var ids := all_ids()
	for i in range(ids.size()):
		var pid = ids[i]
		players[pid]["team"] = _team_for_index(i)
	changed.emit()

# --- Snapshots ------------------------------------------------------------

func snapshot() -> Dictionary:
	var plist: Array = []
	for pid in all_ids():
		var rec: Dictionary = players[pid]
		plist.append({
			"id": pid,
			"name": rec["name"],
			"team": rec["team"],
			"ready": rec["ready"],
			"addr": rec["addr"],
			"token": rec["token"],
			"connected": rec["connected"],
			"dropped_at": rec["dropped_at"],
		})
	return {
		"phase": phase,
		"host_id": host_id,
		"next_host_id": next_host_id,
		"settings": settings.duplicate(),
		"players": plist,
		"grace_ms": grace_ms,
	}

## Client side: adopt a host snapshot wholesale (single source of truth).
func apply_snapshot(snap: Variant) -> bool:
	if not (snap is Dictionary):
		return false
	var d := snap as Dictionary
	if not d.has("players") or not (d["players"] is Array):
		return false
	var new_settings := NetSecurity.sanitize_settings(d.get("settings", {}))
	var snap_settings = d.get("settings", {})
	var raw_seed = null
	if snap_settings is Dictionary:
		raw_seed = snap_settings.get("seed", null)
	phase = int(d.get("phase", Phase.LOBBY))
	host_id = int(d.get("host_id", 1))
	next_host_id = int(d.get("next_host_id", host_id))
	grace_ms = clampi(int(d.get("grace_ms", DEFAULT_GRACE_MS)), 1000, 300000)
	settings = DEFAULT_SETTINGS.duplicate()
	for k in new_settings.keys():
		settings[k] = new_settings[k]
	if (raw_seed is int) or (raw_seed is float):
		settings["seed"] = int(raw_seed)
	players.clear()
	for entry in d["players"]:
		if not (entry is Dictionary):
			continue
		var e := entry as Dictionary
		var pid := int(e.get("id", 0))
		if pid <= 0:
			continue
		players[pid] = {
			"name": NetSecurity.sanitize_name(e.get("name", "")),
			"team": clampi(int(e.get("team", 0)), 0, 7),
			"ready": bool(e.get("ready", false)),
			"addr": str(e.get("addr", "")),
			"token": str(e.get("token", "")),
			"connected": bool(e.get("connected", true)),
			"dropped_at": float(e.get("dropped_at", -1.0)),
		}
	changed.emit()
	return true
