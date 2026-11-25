# scripts/core/formation.gd
class_name Formation
extends RefCounted

enum Style { GRID = 0, WEDGE = 1, LINE = 2, ECHELON = 3 }

const STYLE_NAMES := ["Grid", "Wedge", "Line", "Echelon"]

static func style_name(style: int) -> String:
	return STYLE_NAMES[clampi(style, 0, STYLE_NAMES.size() - 1)]

## Tactical echelon rank: 0 = front vanguard/armor, 1 = mid/flank/AA, 2 = rear standoff/support.
static func role_rank(role: String) -> int:
	match role:
		"vanguard", "armor", "raider", "scout", "navy":
			return 0
		"standoff", "worker":
			return 2
		_:
			return 1

# Returns offset positions for a group of units in a grid formation.
static func grid_offsets(count: int, spacing: float = 32.0) -> Array[Vector2]:
	var offsets: Array[Vector2] = []
	var cols := int(ceil(sqrt(float(count))))
	for i in range(count):
		var r := int(float(i) / float(cols))
		var c := i % cols
		offsets.append(Vector2(c * spacing, r * spacing))
	# center
	var center := Vector2.ZERO
	for o in offsets:
		center += o
	if count > 0:
		center /= float(count)
	for i in range(offsets.size()):
		offsets[i] -= center
	return offsets

## Role-aware combined-arms formation offsets oriented along `heading`.
## Places armor/vanguard in front, anti-air/infantry on flanks, and artillery/workers in rear.
static func tactical_offsets(
	unit_roles: Array, heading: Vector2 = Vector2.RIGHT,
	style: int = Style.WEDGE, spacing: float = 30.0
) -> Array[Vector2]:
	var count := unit_roles.size()
	var result: Array[Vector2] = []
	if count == 0:
		return result
	result.resize(count)
	if count == 1:
		result[0] = Vector2.ZERO
		return result
	var fwd := heading.normalized() if heading.length_squared() > 0.0001 else Vector2.RIGHT
	var right := Vector2(-fwd.y, fwd.x)

	var front: Array[int] = []
	var mid: Array[int] = []
	var rear: Array[int] = []
	for i in range(count):
		var rk := role_rank(String(unit_roles[i]))
		if rk == 0:
			front.append(i)
		elif rk == 1:
			mid.append(i)
		else:
			rear.append(i)
	var ordered: Array[int] = []
	ordered.append_array(front)
	ordered.append_array(mid)
	ordered.append_array(rear)

	var clamped_style := clampi(style, 0, Style.ECHELON)
	match clamped_style:
		Style.LINE:
			var tiers: Array = []
			if not front.is_empty():
				tiers.append(front)
			if not mid.is_empty():
				tiers.append(mid)
			if not rear.is_empty():
				tiers.append(rear)
			for row_idx in range(tiers.size()):
				var row: Array = tiers[row_idx]
				var row_n := row.size()
				for col_idx in range(row_n):
					var lateral := (float(col_idx) - float(row_n - 1) * 0.5) * spacing
					var depth := -float(row_idx) * spacing * 1.15
					result[int(row[col_idx])] = fwd * depth + right * lateral
		Style.ECHELON:
			for rank_pos in range(ordered.size()):
				var u_idx := ordered[rank_pos]
				var lateral := (float(rank_pos) - float(count - 1) * 0.5) * spacing * 0.92
				var depth := -float(rank_pos) * spacing * 0.58
				result[u_idx] = fwd * depth + right * lateral
		Style.WEDGE:
			# Front units form the leading spearhead; mid units guard outer wings;
			# standoff/support units tuck safely behind the center pocket.
			for f_i in range(front.size()):
				if f_i == 0:
					result[front[f_i]] = Vector2.ZERO
				else:
					var wing := int(ceil(float(f_i) * 0.5))
					var side := 1.0 if (f_i % 2 == 1) else -1.0
					result[front[f_i]] = -fwd * (float(wing) * spacing * 0.85) + right * (side * float(wing) * spacing * 0.95)
			var base_wing := maxi(1, int(ceil(float(front.size()) * 0.5)))
			for m_i in range(mid.size()):
				var wing_m := base_wing + int(floor(float(m_i) * 0.5))
				var side_m := 1.0 if (m_i % 2 == 0) else -1.0
				result[mid[m_i]] = -fwd * (float(wing_m) * spacing * 0.95) + right * (side_m * float(wing_m) * spacing * 1.05)
			var rear_depth := float(base_wing + int(ceil(float(mid.size()) * 0.5))) * spacing * 0.95
			for r_i in range(rear.size()):
				var lat_r := (float(r_i) - float(rear.size() - 1) * 0.5) * spacing
				result[rear[r_i]] = -fwd * rear_depth + right * lat_r
		_:
			# Oriented role-sorted grid (vanguard in leading row, standoff in back row)
			var cols := maxi(1, int(ceil(sqrt(float(count)))))
			for rank_pos in range(ordered.size()):
				var row_g := int(float(rank_pos) / float(cols))
				var col_g := rank_pos % cols
				var lat_g := (float(col_g) - float(cols - 1) * 0.5) * spacing
				var dep_g := -float(row_g) * spacing
				result[ordered[rank_pos]] = fwd * dep_g + right * lat_g

	var centroid := Vector2.ZERO
	for v in result:
		centroid += v
	centroid /= float(count)
	for i in range(count):
		result[i] -= centroid
	return result
