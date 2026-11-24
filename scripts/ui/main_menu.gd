# scripts/ui/main_menu.gd
extends Control

const MAP_OPTIONS := ["Desert", "Island Chain", "Forest", "Custom Map (.bwm)"]

@onready var skirmish_btn = $VBox/SkirmishButton
@onready var difficulty_btn = $VBox/DifficultyButton
@onready var faction_btn = $VBox/FactionButton
@onready var map_btn = get_node_or_null("VBox/MapButton")
@onready var host_btn = $VBox/HostButton
@onready var join_btn = $VBox/JoinButton
@onready var editor_btn = $VBox/EditorButton
@onready var ip_edit = $VBox/IpEdit
@onready var name_edit = $VBox/NameEdit
@onready var passcode_edit = $VBox/PasscodeEdit
@onready var status = $VBox/Status

var selected_difficulty: int = AI.Difficulty.NORMAL
var selected_faction: int = Faction.Id.AERODYNE
var selected_map_type: int = 2  # 0 Desert, 1 Island Chain, 2 Forest, 3 Custom Map

func _ready():
	SettingsManager.apply_to_scene()
	if is_instance_valid(skirmish_btn):
		skirmish_btn.pressed.connect(_on_skirmish)
	if is_instance_valid(difficulty_btn):
		difficulty_btn.pressed.connect(_on_cycle_difficulty)
	if is_instance_valid(faction_btn):
		faction_btn.pressed.connect(_on_cycle_faction)
	if is_instance_valid(map_btn):
		map_btn.pressed.connect(_on_cycle_map)
	host_btn.pressed.connect(_on_host)
	join_btn.pressed.connect(_on_join)
	if is_instance_valid(editor_btn):
		editor_btn.pressed.connect(_on_editor)
	var settings_btn := get_node_or_null("VBox/SettingsButton")
	if settings_btn == null and has_node("VBox"):
		var sb := Button.new()
		sb.name = "SettingsButton"
		sb.text = "Settings (Audio, Access & Controls)"
		$VBox.add_child(sb)
		sb.pressed.connect(_open_settings)
	_refresh_labels()
	if has_node("VBox/VersionLabel"):
		$VBox/VersionLabel.text = "v%s (%s)" % [VersionInfo.version(), VersionInfo.commit_sha()]

func _open_settings() -> void:
	var dialog := SettingsDialog.new()
	add_child(dialog)
	dialog.popup_centered(Vector2i(620, 640))

func _refresh_labels() -> void:
	if is_instance_valid(difficulty_btn):
		difficulty_btn.text = "AI Difficulty: %s" % AI.difficulty_name(selected_difficulty)
	if is_instance_valid(faction_btn):
		faction_btn.text = "Corporation: %s" % Faction.name_of(selected_faction)
	if is_instance_valid(map_btn):
		map_btn.text = "Map: %s" % MAP_OPTIONS[selected_map_type % MAP_OPTIONS.size()]

func _on_cycle_difficulty() -> void:
	selected_difficulty = (selected_difficulty + 1) % 3
	_refresh_labels()

func _on_cycle_faction() -> void:
	selected_faction = (selected_faction + 1) % 4
	_refresh_labels()

func _on_cycle_map() -> void:
	# Browsing the menu must not change global match state; the skirmish
	# handler pins the map type when the match actually starts.
	selected_map_type = (selected_map_type + 1) % MAP_OPTIONS.size()
	_refresh_labels()

func _on_skirmish() -> void:
	NetworkManager.leave()
	var ai_fac := (selected_faction + 1) % 4
	var custom_map: MapData = null
	if selected_map_type == 3:
		custom_map = MapSerializer.load_from_file("user://custom_map.bwm")
		if custom_map == null:
			status.text = "No saved custom map found. Save one in the Map Editor first."
			return
		var check: Dictionary = MapData.validate_map(custom_map)
		if not bool(check.get("ok", false)):
			status.text = "Custom map is invalid: %s" % str(check.get("reason", "unknown error"))
			return
	GameManager.start_single_player(selected_difficulty, custom_map, selected_faction, ai_fac, selected_map_type)
	status.text = "Starting Single Player vs %s AI..." % AI.difficulty_name(selected_difficulty)
	_start_game()

func _on_host():
	var err = NetworkManager.host_game(NetworkManager.DEFAULT_PORT, _player_name(), _passcode())
	if err == OK:
		GameManager.match_mode = GameManager.Mode.MULTIPLAYER
		status.text = "Hosting on %d..." % NetworkManager.DEFAULT_PORT
		SceneManager.goto_scene("res://scenes/lobby.tscn")
	else:
		status.text = "Host failed (is port %d already in use?)" % NetworkManager.DEFAULT_PORT

func _on_join():
	var address: String = ip_edit.text.strip_edges()
	if not NetSecurity.is_valid_address(address):
		status.text = "Enter a valid host address"
		return
	var err = NetworkManager.join_game(address, NetworkManager.DEFAULT_PORT, _player_name(), _passcode())
	if err == OK:
		GameManager.match_mode = GameManager.Mode.MULTIPLAYER
		status.text = "Connecting to %s..." % NetSecurity.mask_address(address)
		SceneManager.goto_scene("res://scenes/lobby.tscn")
	else:
		status.text = "Join failed"

func _player_name() -> String:
	var raw: String = "Commander"
	if is_instance_valid(name_edit) and not name_edit.text.strip_edges().is_empty():
		raw = name_edit.text
	var clean := NetSecurity.sanitize_name(raw)
	return clean if not clean.is_empty() else "Commander"

func _passcode() -> String:
	if not is_instance_valid(passcode_edit):
		return ""
	return String(passcode_edit.text.strip_edges())

func _start_game():
	SceneManager.goto_scene("res://scenes/game.tscn")

func _on_editor() -> void:
	GameManager.match_mode = GameManager.Mode.MAP_EDITOR
	SceneManager.goto_scene("res://scenes/map_editor.tscn")
