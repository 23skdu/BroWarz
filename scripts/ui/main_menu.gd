# scripts/ui/main_menu.gd
extends Control

const MAP_OPTIONS := ["Desert", "Island Chain", "Forest", "Custom Map (.bwm)"]

const PLAY_COLUMN := "MenuPanel/Margin/VBox/Columns/PlayColumn"
const OPTIONS_COLUMN := "MenuPanel/Margin/VBox/Columns/OptionsColumn"

@onready var play_column: VBoxContainer = $MenuPanel/Margin/VBox/Columns/PlayColumn
@onready var options_column: VBoxContainer = $MenuPanel/Margin/VBox/Columns/OptionsColumn
@onready var skirmish_btn = $MenuPanel/Margin/VBox/Columns/PlayColumn/SkirmishButton
@onready var difficulty_btn = $MenuPanel/Margin/VBox/Columns/OptionsColumn/DifficultyButton
@onready var faction_btn = $MenuPanel/Margin/VBox/Columns/OptionsColumn/FactionButton
@onready var spectator_btn = get_node_or_null("%s/SpectatorButton" % PLAY_COLUMN)
@onready var spectator_faction_btn = get_node_or_null("%s/SpectatorFactionButton" % OPTIONS_COLUMN)
@onready var map_btn = get_node_or_null("%s/MapButton" % OPTIONS_COLUMN)
@onready var host_btn = $MenuPanel/Margin/VBox/Columns/PlayColumn/HostButton
@onready var join_btn = $MenuPanel/Margin/VBox/Columns/PlayColumn/JoinButton
@onready var editor_btn = $MenuPanel/Margin/VBox/Columns/PlayColumn/EditorButton
@onready var ip_edit = $MenuPanel/Margin/VBox/Columns/OptionsColumn/IpEdit
@onready var name_edit = $MenuPanel/Margin/VBox/Columns/OptionsColumn/NameEdit
@onready var passcode_edit = $MenuPanel/Margin/VBox/Columns/OptionsColumn/PasscodeEdit
@onready var status = $MenuPanel/Margin/VBox/Status

var selected_difficulty: int = AI.Difficulty.NORMAL
var selected_faction: int = Faction.Id.AERODYNE
var selected_spectator_faction: int = Faction.Id.VANGUARD
var selected_map_type: int = 2  # 0 Desert, 1 Island Chain, 2 Forest, 3 Custom Map
var custom_map_path: String = "user://custom_map.bwm"
var custom_map_picker: OptionButton = null

func _ready():
	SettingsManager.apply_to_scene()
	AudioManager.set_music("menu")
	if is_instance_valid(skirmish_btn):
		skirmish_btn.pressed.connect(_on_skirmish)
	if is_instance_valid(difficulty_btn):
		difficulty_btn.pressed.connect(_on_cycle_difficulty)
	if is_instance_valid(faction_btn):
		faction_btn.pressed.connect(_on_cycle_faction)
	spectator_btn = _ensure_menu_button("SpectatorButton", "Watch AI vs AI (View Only)", play_column)
	spectator_faction_btn = _ensure_menu_button("SpectatorFactionButton", "AI Side B Corp: Vanguard", options_column)
	spectator_btn.pressed.connect(_on_spectator)
	spectator_faction_btn.pressed.connect(_on_cycle_spectator_faction)
	if is_instance_valid(map_btn):
		map_btn.pressed.connect(_on_cycle_map)
	host_btn.pressed.connect(_on_host)
	join_btn.pressed.connect(_on_join)
	if is_instance_valid(editor_btn):
		editor_btn.pressed.connect(_on_editor)
	var settings_btn := _ensure_menu_button("SettingsButton", "Settings (Audio, Access & Controls)", options_column)
	settings_btn.pressed.connect(_open_settings)
	var replay_btn := _ensure_menu_button("ReplayButton", "Watch Saved Replay", options_column)
	replay_btn.pressed.connect(_open_replay)
	_refresh_labels()
	_build_custom_map_picker()
	var version_label := get_node_or_null("MenuPanel/Margin/VBox/VersionLabel") as Label
	if version_label != null:
		version_label.text = "v%s (%s)" % [VersionInfo.version(), VersionInfo.commit_sha()]

func _build_custom_map_picker() -> void:
	if not is_instance_valid(options_column):
		return
	var paths := MapSerializer.list_saved_maps()
	if paths.is_empty():
		return
	custom_map_picker = OptionButton.new()
	custom_map_picker.name = "CustomMapPicker"
	custom_map_picker.add_item("Custom Map: quick map")
	for path in paths:
		custom_map_picker.add_item(path.get_file())
	custom_map_picker.item_selected.connect(_on_custom_map_selected)
	options_column.add_child(custom_map_picker)
	var map_button := options_column.get_node_or_null("MapButton")
	if map_button != null:
		options_column.move_child(custom_map_picker, map_button.get_index() + 1)

func _on_custom_map_selected(index: int) -> void:
	var paths := MapSerializer.list_saved_maps()
	custom_map_path = paths[index - 1] if index > 0 and index <= paths.size() else "user://custom_map.bwm"

func _open_settings() -> void:
	var dialog := SettingsDialog.new()
	add_child(dialog)
	dialog.popup_centered(Vector2i(620, 640))

func _open_replay() -> void:
	var viewer := get_node_or_null("ReplayViewer")
	if viewer == null:
		viewer = ReplayViewer.new()
		viewer.name = "ReplayViewer"
		add_child(viewer)
	viewer.popup_centered(Vector2i(720, 560))

func _ensure_menu_button(node_name: String, text: String, parent: VBoxContainer) -> Button:
	var btn := parent.get_node_or_null(node_name) as Button
	if btn == null:
		btn = Button.new()
		btn.name = node_name
		btn.text = text
		parent.add_child(btn)
	return btn

func _refresh_labels() -> void:
	if is_instance_valid(difficulty_btn):
		difficulty_btn.text = "AI Difficulty: %s" % AI.difficulty_name(selected_difficulty)
	if is_instance_valid(faction_btn):
		faction_btn.text = "Corporation / AI Side A: %s" % Faction.name_of(selected_faction)
	if is_instance_valid(spectator_faction_btn):
		spectator_faction_btn.text = "AI Side B Corp: %s" % Faction.name_of(selected_spectator_faction)
	if is_instance_valid(map_btn):
		map_btn.text = "Map: %s" % MAP_OPTIONS[selected_map_type % MAP_OPTIONS.size()]

func _on_cycle_difficulty() -> void:
	selected_difficulty = (selected_difficulty + 1) % 3
	_refresh_labels()

func _on_cycle_faction() -> void:
	selected_faction = (selected_faction + 1) % 4
	_refresh_labels()

func _on_cycle_spectator_faction() -> void:
	selected_spectator_faction = (selected_spectator_faction + 1) % 4
	_refresh_labels()

func _on_cycle_map() -> void:
	# Browsing the menu must not change global match state; the skirmish
	# handler pins the map type when the match actually starts.
	selected_map_type = (selected_map_type + 1) % MAP_OPTIONS.size()
	_refresh_labels()

func _load_selected_map() -> Dictionary:
	if selected_map_type != 3:
		return {"ok": true, "map": null}
	var result := MapSerializer.load_with_result(custom_map_path)
	if not bool(result.get("ok", false)):
		status.text = "Cannot load %s: %s" % [custom_map_path, String(result.get("reason", "unknown error"))]
		return {"ok": false, "map": null}
	var custom_map := result.get("map", null) as MapData
	if not bool(result.get("playable", false)):
		status.text = "Custom map is not playable: %s" % String(result.get("playability_reason", "unknown issue"))
		return {"ok": false, "map": null}
	return {"ok": true, "map": custom_map}

func _on_skirmish() -> void:
	NetworkManager.leave()
	var loaded := _load_selected_map()
	if not bool(loaded["ok"]):
		return
	var ai_fac := (selected_faction + 1) % 4
	GameManager.start_single_player(selected_difficulty, loaded["map"], selected_faction, ai_fac, selected_map_type)
	status.text = "Starting Single Player vs %s AI..." % AI.difficulty_name(selected_difficulty)
	_start_game()

func _on_spectator() -> void:
	NetworkManager.leave()
	var loaded := _load_selected_map()
	if not bool(loaded["ok"]):
		return
	GameManager.start_spectator(
		selected_difficulty, loaded["map"], selected_faction,
		selected_spectator_faction, selected_map_type,
	)
	status.text = "Spectating %s vs %s (%s AI, view only)..." % [
		Faction.name_of(selected_faction), Faction.name_of(selected_spectator_faction),
		AI.difficulty_name(selected_difficulty),
	]
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
