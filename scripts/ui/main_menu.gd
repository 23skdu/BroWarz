# scripts/ui/main_menu.gd
extends Control

@onready var host_btn = $VBox/HostButton
@onready var join_btn = $VBox/JoinButton
@onready var ip_edit = $VBox/IpEdit
@onready var status = $VBox/Status

func _ready():
	host_btn.pressed.connect(_on_host)
	join_btn.pressed.connect(_on_join)
	if has_node("VBox/VersionLabel"):
		$VBox/VersionLabel.text = "v%s (%s)" % [VersionInfo.version(), VersionInfo.commit_sha()]

func _on_host():
	var err = NetworkManager.host()
	if err == OK:
		status.text = "Hosting on 7777..."
		_start_game()
	else:
		status.text = "Host failed: %s" % err

func _on_join():
	var err = NetworkManager.join(ip_edit.text, 7777)
	if err == OK:
		status.text = "Connecting..."
		NetworkManager.connected_to_server.connect(_start_game, CONNECT_ONE_SHOT)
	else:
		status.text = "Join failed: %s" % err

func _start_game():
	get_tree().change_scene_to_file("res://scenes/game.tscn")
