# scripts/core/fog_of_war.gd
class_name FogOfWar
extends RefCounted

var width: int
var height: int
var explored: PackedByteArray
var visible: PackedByteArray
var map: MapData = null

func _init(w: int, h: int, m: MapData = null) -> void:
	width = w
	height = h
	map = m
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
			var tx: int = x + dx
			var ty: int = y + dy
			if not _has_los(x, y, tx, ty):
				continue
			var i: int = _idx(tx, ty)
			if i >= 0:
				visible[i] = 1
				explored[i] = 1

func _has_los(x0: int, y0: int, x1: int, y1: int) -> bool:
	if map == null:
		return true
	var dx: int = abs(x1 - x0)
	var dy: int = -abs(y1 - y0)
	var sx: int = 1 if x0 < x1 else -1
	var sy: int = 1 if y0 < y1 else -1
	var err: int = dx + dy
	var cx: int = x0
	var cy: int = y0
	while true:
		if (cx != x0 or cy != y0) and (cx != x1 or cy != y1):
			if map.in_bounds(cx, cy) and map.get_terrain(cx, cy) == MapData.Terrain.MOUNTAIN:
				return false
		if cx == x1 and cy == y1:
			break
		var e2: int = 2 * err
		if e2 >= dy:
			err += dy
			cx += sx
		if e2 <= dx:
			err += dx
			cy += sy
	return true

func is_visible(x: int, y: int) -> bool:
	var i: int = _idx(x, y)
	if i < 0:
		return false
	return visible[i] == 1

func is_explored(x: int, y: int) -> bool:
	var i: int = _idx(x, y)
	if i < 0:
		return false
	return explored[i] == 1
