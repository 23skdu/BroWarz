# scripts/core/formation.gd
class_name Formation
extends RefCounted

# Returns offset positions for a group of units in a grid formation.
static func grid_offsets(count: int, spacing: float = 32.0) -> Array[Vector2]:
	var offsets: Array[Vector2] = []
	var cols = int(ceil(sqrt(float(count))))
	for i in range(count):
		var r = int(float(i) / float(cols))
		var c = i % cols
		offsets.append(Vector2(c * spacing, r * spacing))
	# center
	var center = Vector2.ZERO
	for o in offsets:
		center += o
	if count > 0:
		center /= count
	for i in range(offsets.size()):
		offsets[i] -= center
	return offsets
