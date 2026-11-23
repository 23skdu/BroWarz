# scripts/autoload/scene_manager.gd
extends Node

var current_scene_path: String = "res://scenes/main_menu.tscn"

func goto_scene(path: String) -> void:
	current_scene_path = path
	if is_inside_tree() and get_tree() != null:
		get_tree().change_scene_to_file(path)
