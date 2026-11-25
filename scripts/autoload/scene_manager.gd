# scripts/autoload/scene_manager.gd
extends Node

func goto_scene(path: String) -> void:
	if is_inside_tree() and get_tree() != null:
		get_tree().change_scene_to_file(path)
