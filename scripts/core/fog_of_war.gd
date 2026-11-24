# scripts/core/fog_of_war.gd
class_name FogOfWar
extends RefCounted

var width: int
var height: int
var explored: PackedByteArray
var visible: PackedByteArray

func _init(w: int, h: int) -> void:
	width = w
	height = h
	explored.resize(w * h)
	visible.resize(w * h)

func _idx(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= width or y >= height:
		return -1
	return y * width + x

func reset_visibility() -> void:
	for i in range(visible.size()):
		visible[i] = 0

func mark_visible(x: int, y: int, radius: int) -> void:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dy * dy > radius * radius:
				continue
			var i = _idx(x + dx, y + dy)
			if i >= 0:
				visible[i] = 1
				explored[i] = 1

func is_visible(x: int, y: int) -> bool:
	var i = _idx(x, y)
	if i < 0:
		return false
	return visible[i] == 1

func is_explored(x: int, y: int) -> bool:
	var i = _idx(x, y)
	if i < 0:
		return false
	return explored[i] == 1
