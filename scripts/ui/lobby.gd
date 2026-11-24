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
@onready var passcode_label: Label = $VBox/SettingsBox/PasscodeLabel
@onready var ready_btn: Button = $VBox/ButtonsHBox/ReadyButton
@onready var start_btn: Button = $VBox/ButtonsHBox/StartButton
@onready var leave_btn: Button = $VBox/ButtonsHBox/LeaveButton
@onready var status: Label = $VBox/StatusLabel

func _ready() -> void:
	map_btn.pressed.connect(_on_map_pressed)
	teams_btn.pressed.connect(_on_teams_pressed)
	fog_btn.pressed.connect(_on_fog_pressed)
	transport_btn.pressed.connect(_on_transport_pressed)
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
	var my_id := multiplayer.get_unique_id()
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
	map_btn.text = "Map: %s" % MAP_NAMES[clampi(int(lob.setting("map_type", 2)), 0, 2)]
	teams_btn.text = "Teams: %d" % clampi(int(lob.setting("num_teams", 2)), 2, 4)
	fog_btn.text = "Fog: %s" % ("On" if bool(lob.setting("fog_of_war", true)) else "Off")
	var transport := str(lob.setting("transport", "enet"))
	transport_btn.text = "Transport: %s" % str(TRANSPORT_NAMES.get(transport, transport))
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

func _on_ready_pressed() -> void:
	NetworkManager.request_ready(not NetworkManager.lobby.ready_of(multiplayer.get_unique_id()))

func _on_start_pressed() -> void:
	if not NetworkManager.is_host():
		return
	status.text = "Starting..."
	NetworkManager.request_start()

func _on_leave_pressed() -> void:
	NetworkManager.leave()
	SceneManager.goto_scene("res://scenes/main_menu.tscn")

func _disconnect_if_connected(sig: Signal, cb: Callable) -> void:
	if sig.is_connected(cb):
		sig.disconnect(cb)
