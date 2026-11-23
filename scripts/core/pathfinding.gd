# scripts/core/pathfinding.gd
class_name Pathfinding
extends RefCounted

# A* on tile grid. Returns array of Vector2i from start to end (excluding start).
static func find_path(map: MapData, start: Vector2i, goal: Vector2i, unit_class: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not map.in_bounds(start.x, start.y) or not map.in_bounds(goal.x, goal.y):
		return result
	if not MapData.is_passable(map.get_terrain(goal.x, goal.y), unit_class):
		return result
	# A*
	var open: Array = [start]
	var came_from: Dictionary = {}
	var g_score: Dictionary = {start: 0.0}
	var f_score: Dictionary = {start: _heuristic(start, goal)}
	while not open.is_empty():
		# find node with lowest f
		var current = open[0]
		var best_f = f_score.get(current, INF)
		for n in open:
			if f_score.get(n, INF) < best_f:
				best_f = f_score.get(n, INF)
				current = n
		if current == goal:
			# reconstruct
			var path: Array[Vector2i] = []
			var cur = current
			while cur != start:
				path.append(cur)
				cur = came_from[cur]
			path.reverse()
			return path
		open.erase(current)
		for nb in _neighbors(current):
			if not map.in_bounds(nb.x, nb.y):
				continue
			var terrain = map.get_terrain(nb.x, nb.y)
			if not MapData.is_passable(terrain, unit_class):
				continue
			var move_cost = MapData.movement_cost(terrain, unit_class)
			var tentative = g_score.get(current, INF) + move_cost
			if tentative < g_score.get(nb, INF):
				came_from[nb] = current
				g_score[nb] = tentative
				f_score[nb] = tentative + _heuristic(nb, goal)
				if not open.has(nb):
					open.append(nb)
	return result

static func _heuristic(a: Vector2i, b: Vector2i) -> float:
	return abs(a.x - b.x) + abs(a.y - b.y)

static func _neighbors(p: Vector2i) -> Array[Vector2i]:
	return [Vector2i(p.x+1,p.y), Vector2i(p.x-1,p.y), Vector2i(p.x,p.y+1), Vector2i(p.x,p.y-1)]
