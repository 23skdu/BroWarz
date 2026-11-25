# scripts/ui/lobby.gd
extends Control

# Pre-match P2P lobby: player roster, host-only match settings, ready gate
# and start button. All mutations go through NetworkManager request_* helpers
# so the host re-validates every client payload.

const MAP_NAMES: Array[String] = ["Desert", "Islands", "Forest"]
const TRANSPORT_NAMES: Dictionary = {"enet": "ENet", "webrtc": "WebRTC"}

@onready var players_label: Label = $VBox/PlayersLabel
@onready var map_btn: Button = $VBox/SettingsBox/MapButton
@onready var teams_btn: Button = $VBox/SettingsBox/TeamsButton
@onready var fog_btn: Button = $VBox/SettingsBox/FogButton
@onready var transport_btn: Button = $VBox/SettingsBox/TransportButton
@onready var alliance_btn: Button = get_node_or_null("VBox/SettingsBox/AllianceButton")
@onready var coop_btn: Button = get_node_or_null("VBox/SettingsBox/CoopButton")
@onready var human_faction_btn: Button = get_node_or_null("VBox/SettingsBox/HumanFactionButton")
@onready var ai_difficulty_btn: Button = get_node_or_null("VBox/SettingsBox/AiDifficultyButton")
@onready var ai_faction_btn: Button = get_node_or_null("VBox/SettingsBox/AiFactionButton")
@onready var passcode_label: Label = $VBox/SettingsBox/PasscodeLabel
@onready var ready_btn: Button = $VBox/ButtonsHBox/ReadyButton
@onready var start_btn: Button = $VBox/ButtonsHBox/StartButton
@onready var leave_btn: Button = $VBox/ButtonsHBox/LeaveButton
@onready var status: Label = $VBox/StatusLabel

var ice_box: VBoxContainer = null
var stun_edit: LineEdit = null
var turn_edit: LineEdit = null
var ice_apply_btn: Button = null
var ice_diag_label: Label = null

func _ready() -> void:
	if alliance_btn == null and has_node("VBox/SettingsBox"):
		var ab := Button.new()
		ab.name = "AllianceButton"
		ab.text = "Alliances: FFA"
		$VBox/SettingsBox.add_child(ab)
		alliance_btn = ab
	coop_btn = _ensure_button("CoopButton", "Co-op: Off")
	human_faction_btn = _ensure_button("HumanFactionButton", "Your Corp: AeroDyne")
	ai_difficulty_btn = _ensure_button("AiDifficultyButton", "AI Difficulty: Normal")
	ai_faction_btn = _ensure_button("AiFactionButton", "AI Corp: Vanguard")
	_build_ice_panel()
	coop_btn.pressed.connect(_on_coop_pressed)
	human_faction_btn.pressed.connect(_on_human_faction_pressed)
	ai_difficulty_btn.pressed.connect(_on_ai_difficulty_pressed)
	ai_faction_btn.pressed.connect(_on_ai_faction_pressed)
	map_btn.pressed.connect(_on_map_pressed)
	teams_btn.pressed.connect(_on_teams_pressed)
	fog_btn.pressed.connect(_on_fog_pressed)
	transport_btn.pressed.connect(_on_transport_pressed)
	alliance_btn.pressed.connect(_on_alliance_pressed)
	ready_btn.pressed.connect(_on_ready_pressed)
	start_btn.pressed.connect(_on_start_pressed)
	leave_btn.pressed.connect(_on_leave_pressed)
	NetworkManager.lobby_changed.connect(_on_lobby_changed)
	NetworkManager.match_starting.connect(_on_match_starting)
	NetworkManager.connection_failed.connect(_on_session_ended)
	NetworkManager.server_left.connect(_on_session_ended)
	NetworkManager.kicked.connect(_on_session_ended)
	NetworkManager.peer_status.connect(_on_peer_status)
	_refresh()

func _exit_tree() -> void:
	_disconnect_if_connected(NetworkManager.lobby_changed, _on_lobby_changed)
	_disconnect_if_connected(NetworkManager.match_starting, _on_match_starting)
	_disconnect_if_connected(NetworkManager.connection_failed, _on_session_ended)
	_disconnect_if_connected(NetworkManager.server_left, _on_session_ended)
	_disconnect_if_connected(NetworkManager.kicked, _on_session_ended)
	_disconnect_if_connected(NetworkManager.peer_status, _on_peer_status)

func _refresh() -> void:
	var lob := NetworkManager.lobby
	var host := NetworkManager.is_host()
	var my_id := multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	var lines: Array = []
	for pid in lob.all_ids():
		var rec: Dictionary = lob.players[pid]
		var badge := ""
		if pid == lob.host_id:
			badge = " (host)"
		elif pid == my_id:
			badge = " (you)"
		var ready_str := "READY" if bool(rec["ready"]) else "waiting"
		if not bool(rec["connected"]):
			ready_str = "dropped"
		lines.append("%s  |  team %d  |  %s%s" % [str(rec["name"]), int(rec["team"]) + 1, ready_str, badge])
	players_label.text = "\n".join(lines) if not lines.is_empty() else "Waiting for players..."
	map_btn.visible = host
	teams_btn.visible = host
	fog_btn.visible = host
	transport_btn.visible = host
	var coop := lob.is_coop()
	alliance_btn.visible = host and not coop
	coop_btn.visible = host
	human_faction_btn.visible = host and coop
	ai_difficulty_btn.visible = host and coop
	ai_faction_btn.visible = host and coop
	coop_btn.text = "Co-op: %s" % ("On (2 humans vs AI)" if coop else "Off")
	human_faction_btn.text = "Your Corp: %s" % Faction.name_of(int(lob.setting("human_faction", 0)))
	ai_difficulty_btn.text = "AI Difficulty: %s" % AI.difficulty_name(int(lob.setting("ai_difficulty", 1)))
	ai_faction_btn.text = "AI Faction: %s" % Faction.name_of(int(lob.setting("ai_faction", 1)))
	var alliance_mode := clampi(int(lob.setting("alliance_mode", 0)), 0, 1)
	alliance_btn.text = "Alliances: %s" % ("Paired Sides" if alliance_mode == 1 else "FFA")
	map_btn.text = "Map: %s" % MAP_NAMES[clampi(int(lob.setting("map_type", 2)), 0, 2)]
	teams_btn.visible = host and not coop
	teams_btn.text = "Teams: %d" % clampi(int(lob.setting("num_teams", 2)), 2, 4)
	fog_btn.text = "Fog: %s" % ("On" if bool(lob.setting("fog_of_war", true)) else "Off")
	var transport := str(lob.setting("transport", "enet"))
	transport_btn.text = "Transport: %s" % str(TRANSPORT_NAMES.get(transport, transport))
	if is_instance_valid(ice_box):
		ice_box.visible = (transport == "webrtc")
		var diag: Dictionary = NetworkManager.webrtc_diagnostics()
		if is_instance_valid(stun_edit) and not stun_edit.has_focus():
			stun_edit.text = String(diag.get("stun_url", ""))
			stun_edit.editable = host
		if is_instance_valid(turn_edit) and not turn_edit.has_focus():
			turn_edit.text = String(diag.get("turn_url", ""))
			turn_edit.editable = host
		if is_instance_valid(ice_apply_btn):
			ice_apply_btn.visible = host
		if is_instance_valid(ice_diag_label):
			var turn_disp := String(diag.get("turn_url", ""))
			ice_diag_label.text = "ICE: %s | TURN: %s | %s" % [
				String(diag.get("stun_url", "default")),
				turn_disp if not turn_disp.is_empty() else "none",
				String(diag.get("signaling", "")),
			]
	passcode_label.text = "Passcode: %s" % ("set" if not NetworkManager.passcode.is_empty() else "open")
	start_btn.visible = host
	start_btn.disabled = not host
	ready_btn.text = "Unready" if lob.ready_of(my_id) else "Ready"

func _on_lobby_changed() -> void:
	_refresh()

func _on_match_starting() -> void:
	status.text = "Launching match..."

func _on_peer_status(peer_id: int, message: String) -> void:
	status.text = "Peer %d: %s" % [peer_id, message]

func _on_session_ended(reason: String) -> void:
	status.text = str(reason)
	SceneManager.goto_scene("res://scenes/main_menu.tscn")

func _on_map_pressed() -> void:
	if not NetworkManager.is_host():
		return
	var cur := int(NetworkManager.lobby.setting("map_type", 2))
	NetworkManager.request_settings({"map_type": (cur + 1) % 3})

func _on_teams_pressed() -> void:
	if not NetworkManager.is_host():
		return
	var cur := int(NetworkManager.lobby.setting("num_teams", 2))
	NetworkManager.request_settings({"num_teams": 4 if cur == 2 else 2})

func _on_fog_pressed() -> void:
	if not NetworkManager.is_host():
		return
	NetworkManager.request_settings({"fog_of_war": not bool(NetworkManager.lobby.setting("fog_of_war", true))})

func _on_transport_pressed() -> void:
	if not NetworkManager.is_host():
		return
	var cur := str(NetworkManager.lobby.setting("transport", "enet"))
	NetworkManager.request_settings({"transport": "webrtc" if cur == "enet" else "enet"})

func _on_alliance_pressed() -> void:
	if not NetworkManager.is_host():
		return
	var cur := clampi(int(NetworkManager.lobby.setting("alliance_mode", 0)), 0, 1)
	NetworkManager.request_settings({"alliance_mode": 1 - cur})

func _on_coop_pressed() -> void:
	if not NetworkManager.is_host():
		return
	NetworkManager.request_settings({"coop_vs_ai": not NetworkManager.lobby.is_coop()})

func _on_human_faction_pressed() -> void:
	if not NetworkManager.is_host():
		return
	var cur := int(NetworkManager.lobby.setting("human_faction", 0))
	NetworkManager.request_settings({"human_faction": (cur + 1) % 4})

func _on_ai_difficulty_pressed() -> void:
	if not NetworkManager.is_host():
		return
	var cur := int(NetworkManager.lobby.setting("ai_difficulty", 1))
	NetworkManager.request_settings({"ai_difficulty": (cur + 1) % 3})

func _on_ai_faction_pressed() -> void:
	if not NetworkManager.is_host():
		return
	var cur := int(NetworkManager.lobby.setting("ai_faction", 1))
	NetworkManager.request_settings({"ai_faction": (cur + 1) % Faction.ai_ids().size()})

func _on_ready_pressed() -> void:
	NetworkManager.set_local_ready(not NetworkManager.lobby.ready_of(multiplayer.get_unique_id()))

func _on_start_pressed() -> void:
	if not NetworkManager.is_host():
		return
	status.text = "Starting..."
	NetworkManager.request_start()

func _on_leave_pressed() -> void:
	NetworkManager.leave()
	SceneManager.goto_scene("res://scenes/main_menu.tscn")

func _build_ice_panel() -> void:
	if not has_node("VBox/SettingsBox"):
		return
	ice_box = VBoxContainer.new()
	ice_box.name = "IceConfigBox"
	ice_box.visible = false
	$VBox/SettingsBox.add_child(ice_box)
	var row := HBoxContainer.new()
	ice_box.add_child(row)
	stun_edit = LineEdit.new()
	stun_edit.name = "StunUrlEdit"
	stun_edit.placeholder_text = "stun:stun.l.google.com:19302"
	stun_edit.custom_minimum_size = Vector2(220, 0)
	row.add_child(stun_edit)
	turn_edit = LineEdit.new()
	turn_edit.name = "TurnUrlEdit"
	turn_edit.placeholder_text = "Optional turn:host:3478"
	turn_edit.custom_minimum_size = Vector2(200, 0)
	row.add_child(turn_edit)
	ice_apply_btn = Button.new()
	ice_apply_btn.name = "ApplyIceButton"
	ice_apply_btn.text = "Apply ICE"
	ice_apply_btn.pressed.connect(_on_apply_ice_pressed)
	row.add_child(ice_apply_btn)
	ice_diag_label = Label.new()
	ice_diag_label.name = "IceDiagnosticsLabel"
	ice_box.add_child(ice_diag_label)

func _on_apply_ice_pressed() -> void:
	if not NetworkManager.is_host():
		return
	var stun := stun_edit.text.strip_edges() if is_instance_valid(stun_edit) else ""
	var turn := turn_edit.text.strip_edges() if is_instance_valid(turn_edit) else ""
	if not stun.is_empty() and not NetSecurity.is_valid_ice_url(stun):
		status.text = "Invalid STUN URL (must start with stun:, turn:, or turns:)"
		return
	if not turn.is_empty() and not NetSecurity.is_valid_ice_url(turn):
		status.text = "Invalid TURN URL (must start with stun:, turn:, or turns:)"
		return
	var payload: Dictionary = {"turn_url": turn}
	if not stun.is_empty():
		payload["stun_url"] = stun
		SettingsManager.set_setting("webrtc_stun_url", stun)
	SettingsManager.set_setting("webrtc_turn_url", turn)
	NetworkManager.request_settings(payload)
	status.text = "Updated WebRTC ICE configuration."

func _ensure_button(node_name: String, text: String) -> Button:
	var btn := get_node_or_null("VBox/SettingsBox/%s" % node_name) as Button
	if btn == null:
		btn = Button.new()
		btn.name = node_name
		btn.text = text
		$VBox/SettingsBox.add_child(btn)
	return btn

func _disconnect_if_connected(sig: Signal, cb: Callable) -> void:
	if sig.is_connected(cb):
		sig.disconnect(cb)
