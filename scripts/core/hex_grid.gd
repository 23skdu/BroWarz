# scripts/core/hex_grid.gd
class_name HexGrid
extends RefCounted

var size: float = 16.0

func _init(s: float = 16.0) -> void:
	size = s

func world_to_hex(pos: Vector2) -> Vector2i:
	var q := (1.7320508 / 3.0 * pos.x - 1.0 / 3.0 * pos.y) / size
	var r := (2.0 / 3.0 * pos.y) / size
	return _axial_round(q, r)

func hex_to_world(h: Vector2i) -> Vector2:
	var x := size * (1.7320508 * float(h.x) + 0.8660254 * float(h.y))
	var y := size * (1.5 * float(h.y))
	return Vector2(x, y)

func _axial_round(q: float, r: float) -> Vector2i:
	var x := q
	var z := r
	var y := -x - z
	var rx := round(x)
	var ry := round(y)
	var rz := round(z)
	var x_diff := abs(rx - x)
	var y_diff := abs(ry - y)
	var z_diff := abs(rz - z)
	if x_diff > y_diff and x_diff > z_diff:
		rx = -ry - rz
	elif y_diff > z_diff:
		ry = -rx - rz
	else:
		rz = -rx - ry
	return Vector2i(int(rx), int(rz))

func neighbors(h: Vector2i) -> Array[Vector2i]:
	var dirs := [Vector2i(1,0), Vector2i(1,-1), Vector2i(0,-1), Vector2i(-1,0), Vector2i(-1,1), Vector2i(0,1)]
	var res: Array[Vector2i] = []
	for d in dirs:
		res.append(h + d)
	return res

func distance(a: Vector2i, b: Vector2i) -> int:
	var aq := a.x
	var ar := a.y
	var bq := b.x
	var br := b.y
	return (abs(aq - bq) + abs(aq + ar - bq - br) + abs(ar - br)) / 2

func hex_path(start: Vector2i, goal: Vector2i, passable: Callable) -> Array[Vector2i]:
	# A* over hex grid
	var open: Array = [start]
	var came_from: Dictionary = {}
	var g_score: Dictionary = {start: 0}
	var f_score: Dictionary = {start: distance(start, goal)}
	while open.size() > 0:
		# find lowest f
		var current = open[0]
		var best_f = f_score.get(current, 999999)
		for n in open:
			if f_score.get(n, 999999) < best_f:
				best_f = f_score.get(n, 999999)
				current = n
		if current == goal:
			var path: Array[Vector2i] = []
			var cur = current
			while cur != start:
				path.append(cur)
				cur = came_from[cur]
			path.reverse()
			return path
		open.erase(current)
		for nb in neighbors(current):
			if not passable.call(nb):
				continue
			var tentative = g_score.get(current, 999999) + 1
			if tentative < g_score.get(nb, 999999):
				came_from[nb] = current
				g_score[nb] = tentative
				f_score[nb] = tentative + distance(nb, goal)
				if not open.has(nb):
					open.append(nb)
	return []
GD
