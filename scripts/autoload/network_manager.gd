# scripts/autoload/network_manager.gd
extends Node

# Secure P2P session manager: lobby handshake, host-authoritative command
# validation, rate limiting, replay protection, disconnect grace, host
# migration and an optional WebRTC match transport (ENet-signaled).
#
# Threat model / devsecops posture:
#   - Fail closed: every inbound payload is whitelisted+coerced (NetSecurity).
#   - Never trust the client: team, order ownership and costs are decided by
#     the host from its own lobby record, never from payload fields.
#   - Anti-flood: token buckets per peer with escalating strikes to kick.
#   - Anti-replay: per-sender monotonic sequence guard (SeqGuard).
#   - Access control: optional lobby passcode (constant-time compare),
#     resume tokens for rejoin, session bans for kicked peers.
#   - Privacy: addresses are masked in all logs.

signal lobby_changed
signal connected_to_lobby
signal connection_failed(reason)
signal server_left(reason)
signal kicked(reason)
signal peer_status(peer_id, message)
signal match_starting
signal state_hash_received(peer_id, value)

enum State { IDLE, HOSTING, CONNECTING, HELLO_WAIT, LOBBY, MATCH }

const DEFAULT_PORT: int = 7777
const HELLO_TIMEOUT_MS: float = 5000.0
const HANDSHAKE_TIMEOUT_MS: float = 10000.0
const SWEEP_INTERVAL_MS: float = 1000.0
const RECONNECT_DELAY_MS: float = 2500.0
const RECONNECT_TIMEOUT_MS: float = 20000.0
const HASH_MIN_INTERVAL_MS: float = 3000.0
const BAN_DURATION_MS: float = 300000.0
const WEBRTC_TIMEOUT_MS: float = 15000.0

var lobby := LobbyState.new()
var state: int = State.IDLE
var passcode: String = ""
var my_name: String = "Commander"
var host_port: int = DEFAULT_PORT
var host_address: String = ""
var resume_token: String = ""
var resume_seat: int = 0
var game_node: Node = null

# Security state
var _inbound_limiter := RateLimiter.new(2.0, 4.0, 5)
var _lobby_limiter := RateLimiter.new(5.0, 10.0, 5)
var _cmd_limiter := RateLimiter.new(20.0, 40.0, 5)
var _hash_limiter := RateLimiter.new(1.0, 3.0, 10)
var _rtc_limiter := RateLimiter.new(20.0, 40.0, 5)
var _inbound_seq := SeqGuard.new()
var _outbound_seq := SeqGuard.new()
var _banned_tokens: Dictionary = {}
var _banned_addr_until: Dictionary = {}
var _pending_hello: Dictionary = {}
var _match_ready: Dictionary = {}
var _pending_cmds: Array = []
var _last_hash_rx: Dictionary = {}
var _last_hash_tx_ms: float = -10000.0
var _last_sweep_ms: float = 0.0
var _handshake_deadline_ms: float = -1.0
var _reconnect_at_ms: float = -1.0
var _reconnect_deadline_ms: float = -1.0
var _reconnect_tried: bool = false

# WebRTC transport state
var _rtc: WebRTCMultiplayerPeer = null
var _rtc_conns: Dictionary = {}
var _rtc_ready_reported: bool = false
var _rtc_remote_ready: Dictionary = {}
var _rtc_deadline_ms: float = -1.0
var _rtc_failed: bool = false
var _rtc_promoted: bool = false
var _old_enet_peer: MultiplayerPeer = null

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

# =====================================================================
# Public API
# =====================================================================

## Host a new lobby on `port`. Returns an Error code.
func host_game(port: int = DEFAULT_PORT, pname: String = "Commander", p_passcode: String = "") -> Error:
	leave()
	my_name = pname
	passcode = p_passcode
	host_port = port
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, NetSecurity.MAX_PLAYERS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	state = State.HOSTING
	lobby.reset()
	lobby.add_player(1, my_name, _local_ip())
	resume_seat = 1
	resume_token = str(lobby.players[1]["token"])
	_schedule_sync()
	connected_to_lobby.emit()
	return OK

## Join an existing lobby. Returns an Error code for local failures only;
## remote rejection arrives via connection_failed/kicked signals.
func join_game(
	address: String, port: int = DEFAULT_PORT, pname: String = "Commander",
	p_passcode: String = "", token: String = "", seat: int = 0,
) -> Error:
	_teardown_peer()
	if not NetSecurity.is_valid_address(address):
		return ERR_INVALID_PARAMETER
	my_name = pname
	passcode = p_passcode
	host_port = port
	host_address = address.strip_edges()
	resume_token = token
	resume_seat = seat
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(host_address, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	state = State.CONNECTING
	_handshake_deadline_ms = _now() + HANDSHAKE_TIMEOUT_MS
	return OK

## Close the transport without touching session state (used before a
## reconnect attempt so the game scene and lobby seat survive).
func _teardown_peer() -> void:
	_close_rtc()
	_old_enet_peer = null
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null

## Tear down the session and reset all security state.
func leave() -> void:
	_teardown_peer()
	lobby.reset()
	_inbound_seq.clear()
	_outbound_seq.clear()
	_inbound_limiter.clear()
	_lobby_limiter.clear()
	_cmd_limiter.clear()
	_hash_limiter.clear()
	_rtc_limiter.clear()
	_banned_tokens.clear()
	_banned_addr_until.clear()
	_pending_hello.clear()
	_match_ready.clear()
	_pending_cmds.clear()
	_last_hash_rx.clear()
	_handshake_deadline_ms = -1.0
	_reconnect_at_ms = -1.0
	_reconnect_deadline_ms = -1.0
	_reconnect_tried = false
	_rtc_promoted = false
	state = State.IDLE
	game_node = null
	passcode = ""
	resume_token = ""
	resume_seat = 0

## Route a local gameplay command: single player applies immediately, P2P
## sends it to the host for validation (host applies + relays back).
func send_command(cmd: Dictionary) -> void:
	if game_node == null:
		return
	if not _has_peer():
		game_node.call("apply_command", cmd)
		return
	if state != State.MATCH:
		return
	var out := cmd.duplicate()
	out["seq"] = _outbound_seq.advance(_my_id())
	if is_host():
		_host_process(_my_id(), out)
	else:
		_cli_cmd.rpc_id(1, out)

## Ask the host to apply new match settings (host-only on arrival).
func request_settings(raw: Dictionary) -> void:
	if _has_peer() and state != State.IDLE:
		_cli_settings.rpc_id(1, raw)

## Toggle this player's ready flag.
func set_local_ready(is_ready: bool) -> void:
	if _has_peer() and state != State.IDLE:
		_cli_ready.rpc_id(1, is_ready)

## Ask the host to start the match (host-only on arrival).
func request_start() -> void:
	if _has_peer() and state != State.IDLE:
		_cli_start.rpc_id(1)

## Host-only: remove a player and ban their seat for this session.
func request_kick(target: int) -> void:
	if _has_peer() and is_host():
		_cli_kick.rpc_id(1, target)

## Periodic simulation checksum for desync detection (throttled).
func broadcast_hash(value: int) -> void:
	if not _has_peer() or state != State.MATCH:
		return
	if _now() - _last_hash_tx_ms < HASH_MIN_INTERVAL_MS:
		return
	_last_hash_tx_ms = _now()
	_cli_hash.rpc(value)

## Bind/unbind the active game scene as the command sink.
func attach_game(node: Node) -> void:
	game_node = node
	if node != null:
		for cmd in _pending_cmds:
			node.call("apply_command", cmd)
		_pending_cmds.clear()

func is_host() -> bool:
	return state == State.HOSTING or (state == State.MATCH and lobby.host_id == _my_id() and _i_am_server())

func in_match() -> bool:
	return state == State.MATCH

func local_team() -> int:
	return lobby.team_of(_my_id())

func peer_count() -> int:
	return lobby.connected_ids().size()

# =====================================================================
# Testable validation pipeline (no socket access)
# =====================================================================

## Host-side hello validation. Pure: passcode, protocol, address, name and
## resume-token checks. Returns {ok, reason, name}.
func validate_hello_payload(
	protocol_version: Variant, p_passcode: Variant, pname: Variant,
	addr: Variant, token: Variant, seat: Variant,
) -> Dictionary:
	var base := NetSecurity.validate_hello(protocol_version, p_passcode, pname, addr, passcode)
	if not base["ok"]:
		return base
	if not (token is String) or not (seat is int or seat is float):
		return {"ok": false, "reason": "bad token", "name": ""}
	if not (token as String).is_empty():
		if _banned_tokens.has(token as String):
			return {"ok": false, "reason": "banned", "name": ""}
		var seat_id := int(seat)
		if seat_id <= 0 or not lobby.has_player(seat_id):
			return {"ok": false, "reason": "unknown seat", "name": ""}
		if not NetSecurity.constant_time_equal(str(lobby.players[seat_id]["token"]), token as String):
			return {"ok": false, "reason": "token rejected", "name": ""}
	elif _is_addr_banned(str(addr)):
		return {"ok": false, "reason": "banned", "name": ""}
	return base

## Host-side command pipeline: rate limit -> whitelist -> team ownership ->
## anti-replay. Returns the sanitized command (with authoritative team) or
## {} when the command must be dropped.
func prepare_inbound_command(sender_id: int, cmd: Variant, now_ms: float = -1.0) -> Dictionary:
	var now := _now() if now_ms < 0.0 else now_ms
	if not lobby.has_player(sender_id) or not lobby.is_peer_connected(sender_id):
		return {}
	if not _cmd_limiter.try_request(sender_id, now):
		return {}
	var clean := NetSecurity.sanitize_command(cmd)
	if clean.is_empty():
		_cmd_limiter.record_violation(sender_id)
		return {}
	var team := lobby.team_of(sender_id)
	if team < 0 or team > 7:
		return {}
	clean["team"] = team  # never trust a client-supplied team
	if not _inbound_seq.accept(sender_id, int(clean["seq"])):
		_cmd_limiter.record_violation(sender_id)
		return {}
	return clean

## True when the sender has exhausted its strike allowance (caller kicks).
func sender_is_banned(sender_id: int) -> bool:
	return _cmd_limiter.is_banned(sender_id) or _inbound_limiter.is_banned(sender_id)

# =====================================================================
# Server-side lobby operations
# =====================================================================

func _host_process(sender_id: int, clean: Dictionary) -> void:
	if game_node == null or clean.is_empty():
		return
	var applied := bool(game_node.call("apply_command", clean))
	if not applied:
		if sender_id != _my_id():
			_srv_cmd_rejected.rpc_id(sender_id)
		return
	if _has_peer():
		_srv_relay.rpc(clean)

func _schedule_sync() -> void:
	if _i_am_server() and _has_peer():
		_srv_sync.rpc(lobby.snapshot())

# =====================================================================
# SceneMultiplayer signal handlers
# =====================================================================

func _on_peer_connected(id: int) -> void:
	if state == State.HOSTING:
		_pending_hello[id] = _now() + HELLO_TIMEOUT_MS
		peer_status.emit(id, "connecting")

func _on_peer_disconnected(id: int) -> void:
	if state != State.HOSTING:
		return
	_pending_hello.erase(id)
	_match_ready.erase(id)
	_rtc_remote_ready.erase(id)
	if lobby.has_player(id):
		if lobby.phase == LobbyState.Phase.LOBBY:
			lobby.remove_player(id)
		else:
			lobby.mark_disconnected(id, _now())
			peer_status.emit(id, "dropped — grace period running")
		_schedule_sync()

func _on_connected_to_server() -> void:
	state = State.HELLO_WAIT
	_handshake_deadline_ms = _now() + HELLO_TIMEOUT_MS
	_cli_hello.rpc_id(
		1, NetSecurity.PROTOCOL_VERSION, passcode, my_name,
		_local_ip(), resume_token, resume_seat,
	)

func _on_connection_failed() -> void:
	var was_reconnect := _reconnect_deadline_ms > 0.0
	leave()
	if was_reconnect:
		server_left.emit("reconnect failed")
	else:
		connection_failed.emit("connection failed")

func _on_server_disconnected() -> void:
	if state == State.HOSTING:
		return
	var was_match := state == State.MATCH or lobby.phase == LobbyState.Phase.STARTING
	var was_reconnect := _reconnect_deadline_ms > 0.0
	# Mid-match host loss: migrate to the elected successor over ENet. The
	# WebRTC transport cannot re-signal after promotion (documented limit).
	if was_match and not was_reconnect and not _rtc_promoted and not _reconnect_tried:
		_begin_host_migration()
		return
	leave()
	if was_reconnect or was_match:
		server_left.emit("connection to host lost")
	else:
		server_left.emit("server closed")

# =====================================================================
# Reconnect grace & host migration (client side)
# =====================================================================

func _begin_host_migration() -> void:
	_reconnect_tried = true
	var successor := lobby.next_host_id
	var my_seat := resume_seat
	if successor == my_seat or successor == _my_id():
		_become_host_after_migration()
		return
	var rec = lobby.players.get(successor, null)
	var addr := str(rec["addr"]) if rec != null else ""
	if addr.is_empty() or not NetSecurity.is_valid_address(addr):
		leave()
		server_left.emit("host lost — successor unreachable")
		return
	host_address = addr
	_reconnect_at_ms = _now() + RECONNECT_DELAY_MS + randf() * 1500.0
	_reconnect_deadline_ms = _now() + RECONNECT_TIMEOUT_MS
	state = State.CONNECTING
	peer_status.emit(successor, "host lost — migrating to %s" % NetSecurity.mask_address(addr))

## The elected successor re-hosts on the same port with the same lobby.
func _become_host_after_migration() -> void:
	var old_seat := resume_seat
	var old_token := resume_token
	var old_passcode := passcode
	var old_name := my_name
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(host_port, NetSecurity.MAX_PLAYERS)
	if err != OK:
		leave()
		server_left.emit("host migration failed (port busy)")
		return
	multiplayer.multiplayer_peer = peer
	passcode = old_passcode
	my_name = old_name
	state = State.HOSTING
	var migrated := lobby.migrate_to(old_seat, old_token, _now())
	if not migrated["ok"]:
		lobby.reset()
		lobby.add_player(1, my_name, _local_ip())
	resume_seat = 1
	if lobby.has_player(1):
		resume_token = str(lobby.players[1]["token"])
	_handshake_deadline_ms = -1.0
	_reconnect_at_ms = -1.0
	_reconnect_deadline_ms = -1.0
	peer_status.emit(1, "you are now the host")
	_schedule_sync()

# =====================================================================
# Per-frame watchdogs
# =====================================================================

func _process(_delta: float) -> void:
	var now := _now()
	if state == State.HOSTING:
		_host_watchdog(now)
	elif state == State.CONNECTING and _reconnect_at_ms > 0.0 and now >= _reconnect_at_ms:
		_reconnect_at_ms = -1.0
		_attempt_reconnect()
	if _handshake_deadline_ms > 0.0 and now > _handshake_deadline_ms:
		_handshake_deadline_ms = -1.0
		var was_reconnect := _reconnect_tried
		leave()
		if was_reconnect:
			server_left.emit("reconnect handshake timeout")
		else:
			connection_failed.emit("handshake timeout")
	if _rtc != null:
		_rtc_poll(now)

func _host_watchdog(now: float) -> void:
	for pid in _pending_hello.keys():
		if now > float(_pending_hello[pid]):
			_pending_hello.erase(pid)
			_kick_peer(int(pid), "hello timeout")
	if lobby.phase == LobbyState.Phase.IN_MATCH:
		if now - _last_sweep_ms >= SWEEP_INTERVAL_MS:
			_last_sweep_ms = now
			var expired := lobby.sweep(now)
			for pid in expired:
				peer_status.emit(int(pid), "grace expired — removed")
			if not expired.is_empty() or lobby.changed.get_connections().size() > 0:
				_schedule_sync()

func _attempt_reconnect() -> void:
	if _now() > _reconnect_deadline_ms:
		leave()
		server_left.emit("reconnect timed out")
		return
	if join_game(host_address, host_port, my_name, passcode, resume_token, resume_seat) != OK:
		leave()
		server_left.emit("reconnect failed")

# =====================================================================
# Incoming RPCs — client → server
# =====================================================================

@rpc("any_peer", "call_remote", "reliable")
func _cli_hello(
	protocol_version: int, p_passcode: String, pname: String,
	addr: String, token: String, seat: int,
) -> void:
	if state != State.HOSTING:
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender <= 1:
		return
	if not _inbound_limiter.try_request(sender, _now()):
		if _inbound_limiter.record_violation(sender):
			_kick_peer(sender, "flooded handshake")
		return
	if _is_addr_banned(addr):
		_srv_reject.rpc_id(sender, "banned")
		_disconnect_soon(sender)
		return
	var verdict := validate_hello_payload(protocol_version, p_passcode, pname, addr, token, seat)
	if not verdict["ok"]:
		_srv_reject.rpc_id(sender, str(verdict["reason"]))
		_disconnect_soon(sender)
		return
	_pending_hello.erase(sender)
	var fresh := token.is_empty()
	if fresh:
		var added := lobby.add_player(sender, verdict["name"], addr)
		if not added["ok"]:
			_srv_reject.rpc_id(sender, str(added["reason"]))
			_disconnect_soon(sender)
			return
	else:
		var moved := lobby.transfer(int(seat), sender, token)
		if not moved["ok"]:
			_srv_reject.rpc_id(sender, str(moved["reason"]))
			_disconnect_soon(sender)
			return
		lobby.players[sender]["addr"] = addr
		lobby.players[sender]["name"] = str(verdict["name"]) if not str(verdict["name"]).is_empty() else lobby.player_name(sender)
	var my_token := str(lobby.players[sender]["token"])
	_srv_welcome.rpc_id(sender, lobby.snapshot(), my_token)
	_schedule_sync()

@rpc("any_peer", "call_remote", "reliable")
func _cli_ready(is_ready: bool) -> void:
	if state != State.HOSTING:
		return
	var sender := multiplayer.get_remote_sender_id()
	if not _lobby_gate(sender):
		return
	lobby.set_ready(sender, is_ready)
	_schedule_sync()

@rpc("any_peer", "call_remote", "reliable")
func _cli_settings(raw: Dictionary) -> void:
	if state != State.HOSTING:
		return
	var sender := multiplayer.get_remote_sender_id()
	if not _lobby_gate(sender):
		return
	if sender != lobby.host_id:
		return  # host-only, silently drop
	if lobby.update_settings(sender, raw):
		_schedule_sync()

@rpc("any_peer", "call_remote", "reliable")
func _cli_start() -> void:
	if state != State.HOSTING:
		return
	var sender := multiplayer.get_remote_sender_id()
	if not _lobby_gate(sender):
		return
	var gate := lobby.can_start(sender)
	if not gate["ok"]:
		_srv_reject.rpc_id(sender, str(gate["reason"]))
		return
	var seed_value := int(Crypto.new().generate_random_bytes(4).decode_u32(0))
	var started := lobby.start(sender, seed_value)
	if not started["ok"]:
		return
	_match_ready.clear()
	_match_ready[1] = true
	_schedule_sync()
	match_starting.emit()

@rpc("any_peer", "call_remote", "reliable")
func _cli_match_ready() -> void:
	if state != State.HOSTING:
		return
	var sender := multiplayer.get_remote_sender_id()
	if not lobby.has_player(sender) or not lobby.is_peer_connected(sender):
		return
	_match_ready[sender] = true
	_if_all_ready_begin_webrtc_or_finish()

@rpc("any_peer", "call_remote", "reliable")
func _cli_kick(target: int) -> void:
	if state != State.HOSTING:
		return
	var sender := multiplayer.get_remote_sender_id()
	if not _lobby_gate(sender) or sender != lobby.host_id:
		return
	if target == sender or not lobby.has_player(target):
		return
	_kick_peer(target, "kicked by host")

@rpc("any_peer", "call_remote", "reliable")
func _cli_cmd(cmd: Dictionary) -> void:
	if state != State.HOSTING:
		return
	var sender := multiplayer.get_remote_sender_id()
	var clean := prepare_inbound_command(sender, cmd)
	if clean.is_empty():
		if sender_is_banned(sender):
			_kick_peer(sender, "command flood")
		return
	_host_process(sender, clean)

@rpc("any_peer", "call_remote", "reliable")
func _cli_hash(value: int) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender < 1:
		return
	if not _hash_limiter.try_request(sender, _now()):
		if _hash_limiter.record_violation(sender):
			_kick_peer(sender, "hash flood")
		return
	var last := float(_last_hash_rx.get(sender, -10000.0))
	if _now() - last < HASH_MIN_INTERVAL_MS:
		return
	_last_hash_rx[sender] = _now()
	state_hash_received.emit(sender, value)

# =====================================================================
# Incoming RPCs — server → client (engine-enforced authority sender)
# =====================================================================

@rpc("authority", "call_remote", "reliable")
func _srv_welcome(snap: Dictionary, token: String) -> void:
	if not _from_server():
		return
	_handshake_deadline_ms = -1.0
	lobby.apply_snapshot(snap)
	resume_token = token
	resume_seat = _my_id()
	_reconnect_tried = false
	_reconnect_deadline_ms = -1.0
	if lobby.phase == LobbyState.Phase.LOBBY:
		state = State.LOBBY
	elif lobby.phase == LobbyState.Phase.STARTING:
		state = State.LOBBY
		_stage_from_lobby()
		_cli_match_ready.rpc_id(1)
	else:
		state = State.MATCH
		_stage_from_lobby()
		if game_node == null:
			_enter_match()
	connected_to_lobby.emit()

@rpc("authority", "call_remote", "reliable")
func _srv_reject(reason: String) -> void:
	if not _from_server():
		return
	var was_reconnect := _reconnect_deadline_ms > 0.0
	var was_in_session := state == State.LOBBY or state == State.MATCH
	leave()
	if was_in_session:
		kicked.emit(reason)
	elif was_reconnect:
		server_left.emit(reason)
	else:
		connection_failed.emit(reason)

@rpc("authority", "call_remote", "reliable")
func _srv_sync(snap: Dictionary) -> void:
	if not _from_server():
		return
	var previous_phase := lobby.phase
	lobby.apply_snapshot(snap)
	if previous_phase != lobby.phase and lobby.phase == LobbyState.Phase.STARTING:
		_on_match_starting()
	elif lobby.phase == LobbyState.Phase.LOBBY and state == State.MATCH:
		state = State.LOBBY
	lobby_changed.emit()

@rpc("authority", "call_remote", "reliable")
func _srv_relay(cmd: Dictionary) -> void:
	if not _from_server():
		return
	var clean := NetSecurity.sanitize_command(cmd)
	if clean.is_empty() or not clean.has("team"):
		return
	_deliver(clean)

@rpc("authority", "call_remote", "reliable")
func _srv_cmd_rejected() -> void:
	if not _from_server():
		return
	# Local sim diverged from the host's verdict; resync comes via hash check.
	pass

@rpc("authority", "call_remote", "reliable")
func _srv_begin_match() -> void:
	if not _from_server():
		return
	_enter_match()

@rpc("authority", "call_remote", "reliable")
func _srv_rtc(from_id: int, kind: String, payload: Dictionary) -> void:
	if not _from_server() or _rtc == null:
		return
	_handle_rtc_signal(from_id, kind, payload)

@rpc("authority", "call_remote", "reliable")
func _srv_promote() -> void:
	if not _from_server():
		return
	_promote_rtc()

@rpc("authority", "call_remote", "reliable")
func _srv_rtc_abort() -> void:
	if not _from_server():
		return
	_discard_rtc()

# =====================================================================
# Incoming RPCs — WebRTC signaling relay (client → host)
# =====================================================================

@rpc("any_peer", "call_remote", "reliable")
func _cli_rtc(kind: String, to_id: int, payload: Dictionary) -> void:
	if state != State.HOSTING:
		return
	var sender := multiplayer.get_remote_sender_id()
	if not lobby.is_peer_connected(sender):
		return
	if not _rtc_limiter.try_request(sender, _now()):
		if _rtc_limiter.record_violation(sender):
			_kick_peer(sender, "signaling flood")
		return
	if to_id == sender or not lobby.is_peer_connected(to_id):
		return
	_srv_rtc.rpc_id(to_id, sender, kind, payload)

@rpc("any_peer", "call_remote", "reliable")
func _cli_rtc_ready() -> void:
	if state != State.HOSTING or _rtc == null:
		return
	var sender := multiplayer.get_remote_sender_id()
	if not lobby.is_peer_connected(sender):
		return
	_rtc_remote_ready[sender] = true
	_if_all_ready_begin_webrtc_or_finish()

@rpc("any_peer", "call_remote", "reliable")
func _cli_rtc_abort() -> void:
	if state != State.HOSTING:
		return
	var sender := multiplayer.get_remote_sender_id()
	if not lobby.is_peer_connected(sender):
		return
	if _rtc != null:
		_srv_rtc_abort.rpc()
		_discard_rtc()
		_finish_start()

# =====================================================================
# Match start sequencing
# =====================================================================

func _on_match_starting() -> void:
	_stage_from_lobby()
	if not is_host():
		_cli_match_ready.rpc_id(1)

## Copy host-pinned match settings into GameManager (single source of truth).
func _stage_from_lobby() -> void:
	GameManager.stage_net_match(
		int(lobby.setting("map_type", 2)),
		int(lobby.setting("seed", 1337)),
		bool(lobby.setting("fog_of_war", true)),
		str(lobby.setting("transport", "enet")),
		_net_teams(),
		local_team(),
	)
	if (
		lobby.phase == LobbyState.Phase.STARTING
		and str(lobby.setting("transport", "enet")) == "webrtc"
		and not is_host() and _rtc == null and not _rtc_failed and not _rtc_promoted
	):
		_begin_webrtc_client()

func _if_all_ready_begin_webrtc_or_finish() -> void:
	if state != State.HOSTING or lobby.phase != LobbyState.Phase.STARTING:
		return
	for pid in lobby.connected_ids():
		if not _match_ready.has(pid):
			return
	if str(lobby.setting("transport", "enet")) == "webrtc":
		if _rtc == null and not _rtc_failed:
			_begin_webrtc_host()
			return
		if not _rtc_failed and not _all_rtc_connected():
			return
		if _rtc != null:
			if _has_peer():
				_srv_promote.rpc()
			_promote_rtc()
	_finish_start()

func _finish_start() -> void:
	if not _i_am_server() or lobby.phase != LobbyState.Phase.STARTING:
		return
	lobby.mark_in_match()
	state = State.MATCH
	_schedule_sync()
	GameManager.stage_net_match(
		int(lobby.setting("map_type", 2)),
		int(lobby.setting("seed", 1337)),
		bool(lobby.setting("fog_of_war", true)),
		str(lobby.setting("transport", "enet")),
		_net_teams(),
		local_team(),
	)
	if _has_peer():
		_srv_begin_match.rpc()
	_enter_match()

func _enter_match() -> void:
	state = State.MATCH
	if lobby.host_id == _my_id() and _i_am_server():
		_schedule_sync()
	if game_node == null:
		SceneManager.goto_scene("res://scenes/game.tscn")

func _net_teams() -> Array:
	var teams: Array = []
	for pid in lobby.connected_ids():
		var t := lobby.team_of(pid)
		if not teams.has(t):
			teams.append(t)
	teams.sort()
	return teams

# =====================================================================
# WebRTC transport (signaling relayed over the ENet lobby channel)
# =====================================================================

func _begin_webrtc_host() -> void:
	_rtc = WebRTCMultiplayerPeer.new()
	if _rtc.create_server() != OK:
		_webrtc_give_up()
		return
	for pid in lobby.connected_ids():
		if pid == 1:
			continue
		_rtc_add_conn(pid)
	_rtc_deadline_ms = _now() + WEBRTC_TIMEOUT_MS

func _begin_webrtc_client() -> void:
	_rtc = WebRTCMultiplayerPeer.new()
	if _rtc.create_client(_my_id()) != OK:
		_webrtc_give_up()
		return
	_rtc_add_conn(1)
	_rtc_deadline_ms = _now() + WEBRTC_TIMEOUT_MS

func _rtc_add_conn(pid: int) -> void:
	var conn := WebRTCPeerConnection.new()
	conn.session_description_created.connect(_on_rtc_sdp.bind(pid))
	conn.ice_candidate_created.connect(_on_rtc_ice.bind(pid))
	_rtc.add_peer(conn, pid)
	_rtc_conns[pid] = conn
	# The lower peer id initiates the offer (host = 1 always offers).
	if _my_id() < pid:
		conn.create_offer()

func _on_rtc_sdp(type: String, sdp: String, pid: int) -> void:
	if _rtc == null or not _rtc_conns.has(pid):
		return
	var conn: WebRTCPeerConnection = _rtc_conns[pid]
	conn.set_local_description(type, sdp)
	if _i_am_server():
		_srv_rtc.rpc_id(pid, 1, "desc", {"type": type, "sdp": sdp})
	else:
		_cli_rtc.rpc_id(1, "desc", pid, {"type": type, "sdp": sdp})

func _on_rtc_ice(media: String, index: int, sdp_name: String, pid: int) -> void:
	if _rtc == null or not _rtc_conns.has(pid):
		return
	var payload := {"media": media, "index": index, "name": sdp_name}
	if _i_am_server():
		_srv_rtc.rpc_id(pid, 1, "ice", payload)
	else:
		_cli_rtc.rpc_id(1, "ice", pid, payload)

func _handle_rtc_signal(from_id: int, kind: String, payload: Dictionary) -> void:
	if _rtc == null or not _rtc_conns.has(from_id):
		return
	var conn: WebRTCPeerConnection = _rtc_conns[from_id]
	match kind:
		"desc":
			var stype := str(payload.get("type", ""))
			if stype != "offer" and stype != "answer":
				return
			var sdp := str(payload.get("sdp", ""))
			if sdp.length() > 65536:
				return
			conn.set_remote_description(stype, sdp)
		"ice":
			var media := str(payload.get("media", ""))
			var idx := int(payload.get("index", -1))
			var cand := str(payload.get("name", ""))
			if media.length() > 32 or cand.length() > 4096 or idx < 0:
				return
			conn.add_ice_candidate(media, idx, cand)

func _rtc_poll(now: float) -> void:
	if _rtc == null:
		return
	_rtc.poll()
	for pid in _rtc_conns.keys():
		var conn: WebRTCPeerConnection = _rtc_conns[pid]
		var st := conn.get_connection_state()
		if st == WebRTCPeerConnection.STATE_FAILED:
			_webrtc_give_up()
			return
	if not _rtc_ready_reported and _all_rtc_connected():
		_rtc_ready_reported = true
		if _i_am_server():
			_rtc_remote_ready[1] = true
			_if_all_ready_begin_webrtc_or_finish()
		else:
			_cli_rtc_ready.rpc_id(1)
	if now > _rtc_deadline_ms:
		_webrtc_give_up()

func _all_rtc_connected() -> bool:
	if _rtc == null or _rtc_conns.is_empty():
		return false
	for pid in _rtc_conns.keys():
		var conn: WebRTCPeerConnection = _rtc_conns[pid]
		if conn.get_connection_state() != WebRTCPeerConnection.STATE_CONNECTED:
			return false
	return true

func _webrtc_give_up() -> void:
	# Degrade gracefully: the match runs on ENet instead.
	if _rtc == null:
		return
	_discard_rtc()
	if _i_am_server():
		_srv_rtc_abort.rpc()
		if lobby.phase == LobbyState.Phase.STARTING:
			_finish_start()
	else:
		_cli_rtc_abort.rpc_id(1)

func _promote_rtc() -> void:
	if _rtc == null:
		return
	_old_enet_peer = multiplayer.multiplayer_peer
	multiplayer.multiplayer_peer = _rtc
	_rtc = null
	_rtc_conns.clear()
	_rtc_promoted = true
	if _old_enet_peer != null:
		_old_enet_peer.close()
	_old_enet_peer = null

func _discard_rtc() -> void:
	if _rtc == null:
		return
	for pid in _rtc_conns.keys():
		var conn: WebRTCPeerConnection = _rtc_conns[pid]
		conn.close()
	_rtc_conns.clear()
	_rtc.close()
	_rtc = null
	_rtc_ready_reported = false
	_rtc_remote_ready.clear()
	_rtc_deadline_ms = -1.0
	_rtc_failed = true

func _close_rtc() -> void:
	_rtc_failed = false
	_discard_rtc()
	_rtc_failed = false

# =====================================================================
# Delivery helpers
# =====================================================================

func _deliver(clean: Dictionary) -> void:
	if game_node == null:
		_pending_cmds.append(clean)
		if _pending_cmds.size() > 256:
			_pending_cmds.pop_front()
		return
	game_node.call("apply_command", clean)

func _kick_peer(target: int, reason: String) -> void:
	if lobby.has_player(target):
		var tok := str(lobby.players[target]["token"])
		if not tok.is_empty():
			_banned_tokens[tok] = true
		var addr := str(lobby.players[target]["addr"])
		if not addr.is_empty():
			_banned_addr_until[addr] = _now() + BAN_DURATION_MS
		lobby.remove_player(target)
	if _i_am_server() and _has_peer():
		_srv_reject.rpc_id(target, reason)
		_disconnect_soon(target)
		_schedule_sync()
	peer_status.emit(target, reason)

func _disconnect_soon(target: int) -> void:
	var peer := multiplayer.multiplayer_peer
	if peer != null and peer.has_method("disconnect_peer"):
		peer.call_deferred("disconnect_peer", target)

func _is_addr_banned(addr: String) -> bool:
	var until_ms := float(_banned_addr_until.get(addr, -1.0))
	return until_ms > _now()

func _lobby_gate(sender: int) -> bool:
	if not _lobby_limiter.try_request(sender, _now()):
		if _lobby_limiter.record_violation(sender):
			_kick_peer(sender, "lobby flood")
		return false
	return lobby.has_player(sender) and lobby.is_peer_connected(sender)

func _from_server() -> bool:
	return multiplayer.get_remote_sender_id() == 1

func _i_am_server() -> bool:
	return _has_peer() and multiplayer.get_unique_id() == 1

func _my_id() -> int:
	return multiplayer.get_unique_id() if _has_peer() else 1

func _has_peer() -> bool:
	return multiplayer.has_multiplayer_peer()

func _now() -> float:
	return float(Time.get_ticks_msec())

func _local_ip() -> String:
	for a in IP.get_local_addresses():
		if str(a).contains(".") and not str(a).begins_with("127.") and not str(a).begins_with("169.254."):
			return str(a)
	return "127.0.0.1"
