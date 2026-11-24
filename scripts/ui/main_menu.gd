# scripts/ui/main_menu.gd
extends Control

@onready var skirmish_btn = $VBox/SkirmishButton
@onready var difficulty_btn = $VBox/DifficultyButton
@onready var faction_btn = $VBox/FactionButton
@onready var host_btn = $VBox/HostButton
@onready var join_btn = $VBox/JoinButton
@onready var editor_btn = $VBox/EditorButton
@onready var ip_edit = $VBox/IpEdit
@onready var status = $VBox/Status

var selected_difficulty: int = AI.Difficulty.NORMAL
var selected_faction: int = Faction.Id.AERODYNE

func _ready():
	if is_instance_valid(skirmish_btn):
		skirmish_btn.pressed.connect(_on_skirmish)
	if is_instance_valid(difficulty_btn):
		difficulty_btn.pressed.connect(_on_cycle_difficulty)
	if is_instance_valid(faction_btn):
		faction_btn.pressed.connect(_on_cycle_faction)
	host_btn.pressed.connect(_on_host)
	join_btn.pressed.connect(_on_join)
	if is_instance_valid(editor_btn):
		editor_btn.pressed.connect(_on_editor)
	_refresh_labels()
	if has_node("VBox/VersionLabel"):
		$VBox/VersionLabel.text = "v%s (%s)" % [VersionInfo.version(), VersionInfo.commit_sha()]

func _refresh_labels() -> void:
	if is_instance_valid(difficulty_btn):
		difficulty_btn.text = "AI Difficulty: %s" % AI.difficulty_name(selected_difficulty)
	if is_instance_valid(faction_btn):
		faction_btn.text = "Corporation: %s" % Faction.name_of(selected_faction)

func _on_cycle_difficulty() -> void:
	selected_difficulty = (selected_difficulty + 1) % 3
	_refresh_labels()

func _on_cycle_faction() -> void:
	selected_faction = (selected_faction + 1) % 4
	_refresh_labels()

func _on_skirmish() -> void:
	var ai_fac := (selected_faction + 1) % 4
	GameManager.start_single_player(selected_difficulty, null, selected_faction, ai_fac)
	status.text = "Starting Single Player vs %s AI..." % AI.difficulty_name(selected_difficulty)
	_start_game()

func _on_host():
	GameManager.match_mode = GameManager.Mode.MULTIPLAYER
	var err = NetworkManager.host()
	if err == OK:
		status.text = "Hosting on 7777..."
		_start_game()
	else:
		status.text = "Host failed: %s" % err

func _on_join():
	GameManager.match_mode = GameManager.Mode.MULTIPLAYER
	var err = NetworkManager.join(ip_edit.text, 7777)
	if err == OK:
		status.text = "Connecting..."
		NetworkManager.connected_to_server.connect(_start_game, CONNECT_ONE_SHOT)
	else:
		status.text = "Join failed: %s" % err

func _start_game():
	SceneManager.goto_scene("res://scenes/game.tscn")

func _on_editor() -> void:
	SceneManager.goto_scene("res://scenes/map_editor.tscn")
