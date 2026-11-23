# scripts/core/production.gd
class_name Production
extends RefCounted

# A simple production queue operating on build times.
# Items: Dictionary { "id": String, "time": float, "remaining": float }

static func new_queue() -> Array:
	return []

static func enqueue(queue: Array, item_id: String, build_time: float) -> void:
	queue.append({"id": item_id, "time": build_time, "remaining": build_time})

static func tick(queue: Array, delta: float) -> Array:
	# returns list of completed item ids this tick
	var completed: Array = []
	if queue.is_empty():
		return completed
	# only first item progresses
	var item = queue[0]
	item["remaining"] = float(item["remaining"]) - delta
	if float(item["remaining"]) <= 0.0:
		completed.append(String(item["id"]))
		queue.pop_front()
	return completed

static func cancel(queue: Array, index: int) -> String:
	if index < 0 or index >= queue.size():
		return ""
	var item = queue[index]
	var id = String(item["id"])
	queue.remove_at(index)
	return id

static func queue_size(queue: Array) -> int:
	return queue.size()

static func current_progress(queue: Array) -> float:
	if queue.is_empty():
		return 0.0
	var item = queue[0]
	var total = float(item["time"])
	var rem = float(item["remaining"])
	if total <= 0.0:
		return 1.0
	return clampf((total - rem) / total, 0.0, 1.0)
