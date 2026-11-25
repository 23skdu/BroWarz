# scripts/core/building_visual.gd
class_name BuildingVisual
extends RefCounted

## Per-building pixel-art sprite generator. Unlike units (which deliberately
## share one silhouette per faction), every building ID owns a distinct outline
## and marker colour so players can identify a structure at a glance.

const SPRITE_SIZE: int = 48

static var _texture_cache: Dictionary = {}  # "id:color_hex:size" -> ImageTexture

const OUTLINE := Color(0.045, 0.055, 0.075, 1.0)
const SHADOW := Color(0.13, 0.16, 0.20, 1.0)
const STEEL := Color(0.74, 0.80, 0.88, 1.0)
const GUNMETAL := Color(0.28, 0.32, 0.38, 1.0)
const GLASS := Color(0.86, 0.97, 1.0, 1.0)
const HAZARD := Color(0.98, 0.72, 0.12, 1.0)
const DANGER := Color(0.95, 0.30, 0.18, 1.0)
const GREEN := Color(0.30, 0.92, 0.42, 1.0)
const CYAN := Color(0.28, 0.88, 1.0, 1.0)


static func clear_cache() -> void:
	_texture_cache.clear()


static func shared_cache_size() -> int:
	return _texture_cache.size()


static func get_cached_building_texture(
	building_id: String, team_color: Color, size: int = SPRITE_SIZE
) -> ImageTexture:
	var key := "%s:%s:%d" % [building_id, team_color.to_html(false), size]
	if not _texture_cache.has(key):
		_texture_cache[key] = ImageTexture.create_from_image(
			build_building_frame_image(building_id, team_color, size)
		)
	return _texture_cache[key]


static func build_building_frame_image(
	building_id: String, team_color: Color, size: int = SPRITE_SIZE
) -> Image:
	var target_size := maxi(16, size)
	var img := Image.create(SPRITE_SIZE, SPRITE_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var dark := team_color.darkened(0.52)
	var mid := team_color
	var bright := team_color.lightened(0.26)
	var trim := team_color.lightened(0.55)
	if not _draw_building(img, building_id, dark, mid, bright, trim):
		_draw_fallback(img, building_id, dark, mid, bright, trim)
	if img.get_width() == target_size and img.get_height() == target_size:
		return img
	var out := img.duplicate()
	out.resize(target_size, target_size, Image.INTERPOLATE_NEAREST)
	return out


static func _draw_building(
	img: Image, id: String, dark: Color, mid: Color, bright: Color, trim: Color
) -> bool:
	var c := SPRITE_SIZE >> 1
	match id:
		"hq":
			# Stepped command tower with antenna, lit bridge and helipad ring.
			_pad(img, c, dark, trim)
			_rect(img, c - 15, c - 12, 30, 26, OUTLINE)
			_rect(img, c - 13, c - 10, 26, 22, dark)
			_rect(img, c - 9, c - 16, 18, 8, OUTLINE)
			_rect(img, c - 7, c - 14, 14, 6, mid)
			_rect(img, c - 4, c - 22, 8, 8, OUTLINE)
			_rect(img, c - 2, c - 24, 4, 4, HAZARD)
			_rect(img, c - 2, c - 5, 4, 15, bright)
			_rect(img, c - 11, c - 3, 5, 4, GLASS)
			_rect(img, c + 7, c - 3, 5, 4, GLASS)
			_circle(img, c, c + 6, 8, OUTLINE)
			_circle(img, c, c + 6, 6, GUNMETAL)
			_rect(img, c - 1, c + 2, 2, 8, trim)
		"docks":
			# Low pier, crane arm and a moored patrol hull.
			_rect(img, c - 20, c + 8, 40, 5, OUTLINE)
			_rect(img, c - 18, c + 9, 36, 3, dark)
			for px in [-14, 0, 14]:
				_rect(img, c + px, c + 12, 3, 6, GUNMETAL)
			_rect(img, c - 12, c - 8, 14, 16, OUTLINE)
			_rect(img, c - 10, c - 6, 10, 12, dark)
			_rect(img, c - 8, c - 4, 6, 7, mid)
			_rect(img, c - 10, c - 12, 3, 18, STEEL)
			_rect(img, c - 10, c - 12, 21, 3, STEEL)
			_rect(img, c + 8, c - 12, 2, 6, HAZARD)
			_rect(img, c + 2, c + 2, 18, 6, OUTLINE)
			_rect(img, c + 3, c + 3, 16, 4, bright)
			_rect(img, c + 16, c + 1, 4, 8, trim)
		"mech_factory_1":
			# Sawtooth-roof light assembly shed with a robot on the line.
			_pad(img, c, dark, trim)
			_rect(img, c - 17, c - 4, 34, 18, OUTLINE)
			_rect(img, c - 15, c - 2, 30, 14, dark)
			for rx in [-14, -6, 2, 10]:
				_rect(img, c + rx, c - 10, 7, 7, mid)
				_rect(img, c + rx + 4, c - 10, 3, 7, trim)
			_rect(img, c - 12, c + 3, 10, 7, GUNMETAL)
			_rect(img, c - 10, c + 4, 6, 5, bright)
			_rect(img, c + 3, c + 2, 11, 8, OUTLINE)
			_rect(img, c + 4, c + 3, 9, 6, STEEL)
			_rect(img, c + 7, c + 1, 3, 4, HAZARD)
		"mech_factory_2":
			# Wide medium-armor plant with twin stacks and shutter doors.
			_pad(img, c, dark, trim)
			_rect(img, c - 19, c - 7, 38, 22, OUTLINE)
			_rect(img, c - 17, c - 5, 34, 18, dark)
			_rect(img, c - 17, c - 5, 34, 4, mid)
			for sx in [-12, 10]:
				_rect(img, c + sx, c - 17, 6, 13, OUTLINE)
				_rect(img, c + sx + 1, c - 15, 4, 10, GUNMETAL)
				_rect(img, c + sx + 1, c - 17, 4, 3, HAZARD)
			for dx in [-13, -2, 9]:
				_rect(img, c + dx, c + 1, 9, 12, OUTLINE)
				_rect(img, c + dx + 1, c + 2, 7, 10, GUNMETAL)
				_rect(img, c + dx + 1, c + 4, 7, 2, bright)
			_rect(img, c - 18, c + 14, 36, 3, trim)
		"mech_factory_3":
			# Massive foundry: three furnace towers and a glowing core.
			_pad(img, c, dark, trim)
			_rect(img, c - 20, c - 5, 40, 24, OUTLINE)
			_rect(img, c - 18, c - 3, 36, 20, dark)
			for tx in [-13, 0, 13]:
				_rect(img, c + tx - 5, c - 17, 10, 14, OUTLINE)
				_rect(img, c + tx - 3, c - 15, 6, 11, mid)
				_rect(img, c + tx - 2, c - 18, 4, 4, DANGER)
			_circle(img, c, c + 5, 8, OUTLINE)
			_circle(img, c, c + 5, 6, HAZARD)
			_circle(img, c, c + 5, 3, Color(1.0, 0.94, 0.62, 1.0))
			_rect(img, c - 19, c + 15, 38, 3, trim)
		"shipyard":
			# Drydock basin with a cruiser hull framed by a gantry.
			_rect(img, c - 21, c + 10, 42, 6, OUTLINE)
			_rect(img, c - 19, c + 11, 38, 4, CYAN.darkened(0.35))
			_rect(img, c - 13, c + 1, 27, 9, OUTLINE)
			_rect(img, c - 11, c + 2, 23, 6, bright)
			_rect(img, c + 10, c - 3, 4, 12, trim)
			for px in [-16, 14]:
				_rect(img, c + px, c - 14, 4, 26, STEEL)
			_rect(img, c - 16, c - 14, 34, 4, STEEL)
			_rect(img, c - 6, c - 12, 12, 6, OUTLINE)
			_rect(img, c - 4, c - 11, 8, 4, dark)
		"advanced_shipyard":
			# Deep-water capital yard with carrier silhouette and twin cranes.
			_rect(img, c - 22, c + 12, 44, 6, OUTLINE)
			_rect(img, c - 20, c + 13, 40, 4, CYAN.darkened(0.35))
			_rect(img, c - 18, c + 3, 36, 8, OUTLINE)
			_rect(img, c - 16, c + 4, 32, 6, bright)
			_rect(img, c - 6, c - 2, 12, 6, STEEL)
			for px in [-19, 17]:
				_rect(img, c + px, c - 18, 4, 30, STEEL)
				_rect(img, c + px - 6, c - 18, 12, 3, HAZARD)
			_rect(img, c - 19, c - 18, 40, 3, STEEL)
			_rect(img, c + 3, c - 15, 3, 14, trim)
		"aeries_1":
			# Compact flight deck with a delta drone and control mast.
			_rect(img, c - 20, c + 8, 40, 8, OUTLINE)
			_rect(img, c - 18, c + 10, 36, 4, dark)
			_rect(img, c - 8, c + 11, 4, 2, GLASS)
			_rect(img, c + 4, c + 11, 4, 2, GLASS)
			_rect(img, c - 18, c - 5, 10, 14, OUTLINE)
			_rect(img, c - 16, c - 3, 6, 10, dark)
			_rect(img, c - 16, c - 9, 4, 5, mid)
			_rect(img, c - 17, c - 11, 6, 2, HAZARD)
			_rect(img, c - 2, c - 2, 20, 7, OUTLINE)
			_rect(img, c + 2, c - 6, 12, 4, bright)
			_rect(img, c + 15, c - 2, 6, 7, OUTLINE)
		"aeries_2":
			# Heavy flight wing: angled runway, hangar and tracking dish.
			_rect(img, c - 22, c + 10, 44, 9, OUTLINE)
			_rect(img, c - 20, c + 12, 40, 5, dark)
			for rx in [-14, 0, 14]:
				_rect(img, c + rx, c + 13, 6, 2, GLASS)
			_rect(img, c - 18, c - 8, 18, 18, OUTLINE)
			_rect(img, c - 16, c - 6, 14, 14, dark)
			_rect(img, c - 14, c - 4, 10, 10, mid)
			_rect(img, c + 2, c - 15, 3, 20, STEEL)
			_circle(img, c + 6, c - 14, 8, OUTLINE)
			_circle(img, c + 6, c - 14, 6, bright)
			_rect(img, c + 3, c - 17, 6, 6, trim)
			_rect(img, c + 14, c - 5, 12, 7, OUTLINE)
			_rect(img, c + 17, c - 8, 7, 4, bright)
		"barracks":
			# Compact robot barracks with three training bays and flag.
			_pad(img, c, dark, trim)
			_rect(img, c - 17, c - 4, 34, 20, OUTLINE)
			_rect(img, c - 15, c - 2, 30, 16, dark)
			_rect(img, c - 15, c - 2, 30, 3, mid)
			for bx in [-11, -2, 7]:
				_rect(img, c + bx, c + 3, 7, 11, OUTLINE)
				_rect(img, c + bx + 1, c + 4, 5, 9, GUNMETAL)
				_rect(img, c + bx + 1, c + 4, 5, 2, bright)
			_rect(img, c + 13, c - 15, 2, 12, STEEL)
			_rect(img, c + 13, c - 15, 8, 5, HAZARD)
		"factory":
			# Armor garage with oversized shutter and a tank tread emblem.
			_pad(img, c, dark, trim)
			_rect(img, c - 19, c - 8, 38, 24, OUTLINE)
			_rect(img, c - 17, c - 6, 34, 20, dark)
			_rect(img, c - 17, c - 6, 34, 4, mid)
			_rect(img, c - 12, c + 1, 24, 13, OUTLINE)
			_rect(img, c - 10, c + 2, 20, 11, GUNMETAL)
			for rx in [-8, -2, 4, 10]:
				_rect(img, c + rx, c + 3, 2, 9, bright)
			_rect(img, c - 15, c - 13, 8, 7, STEEL)
			_rect(img, c + 9, c - 13, 8, 7, STEEL)
			_rect(img, c - 4, c - 15, 8, 4, HAZARD)
		"airfield":
			# Runway cross-stripes with a parked scout drone and windsock.
			_rect(img, c - 21, c + 4, 42, 13, OUTLINE)
			_rect(img, c - 19, c + 6, 38, 9, dark)
			for rx in [-13, -1, 11]:
				_rect(img, c + rx, c + 9, 7, 3, GLASS)
			_rect(img, c - 5, c - 4, 20, 6, OUTLINE)
			_rect(img, c - 1, c - 9, 12, 5, bright)
			_rect(img, c + 14, c - 4, 5, 6, OUTLINE)
			_rect(img, c + 18, c - 15, 2, 12, STEEL)
			_rect(img, c + 18, c - 15, 7, 3, HAZARD)
		"extractor":
			# Derrick over an ore seam with drill head and pipe manifold.
			_pad(img, c, dark, trim)
			_rect(img, c - 14, c - 4, 28, 20, OUTLINE)
			_rect(img, c - 12, c - 2, 24, 16, dark)
			_rect(img, c - 4, c - 18, 8, 16, STEEL)
			_rect(img, c - 6, c - 22, 12, 4, HAZARD)
			_rect(img, c - 2, c - 2, 4, 12, mid)
			_rect(img, c - 9, c + 5, 6, 6, CYAN)
			_rect(img, c + 3, c + 5, 6, 6, CYAN)
			_rect(img, c - 15, c + 14, 30, 3, trim)
		"farm":
			# Hydroponic greenhouse domes with green grow rows.
			_pad(img, c, dark, trim)
			_rect(img, c - 19, c - 1, 38, 18, OUTLINE)
			_rect(img, c - 17, c + 1, 34, 14, dark)
			for dx in [-15, 1]:
				_circle(img, c + dx + 7, c + 4, 7, OUTLINE)
				_circle(img, c + dx + 7, c + 4, 5, GREEN.darkened(0.25))
				_rect(img, c + dx + 5, c + 3, 4, 8, GREEN)
			for rx in [-14, -4, 6, 14]:
				_rect(img, c + rx, c + 10, 5, 4, GREEN.lightened(0.2))
			_rect(img, c - 19, c + 14, 38, 3, trim)
		"power_plant":
			# Geothermal stack with molten core and cooling fins.
			_pad(img, c, dark, trim)
			_rect(img, c - 16, c, 32, 18, OUTLINE)
			_rect(img, c - 14, c + 2, 28, 14, dark)
			_rect(img, c - 5, c - 17, 10, 19, OUTLINE)
			_rect(img, c - 3, c - 19, 6, 20, mid)
			_rect(img, c - 2, c - 22, 4, 5, HAZARD)
			_circle(img, c, c + 8, 6, DANGER)
			_circle(img, c, c + 8, 3, HAZARD)
			for fx in [-12, 10]:
				_rect(img, c + fx, c + 4, 3, 10, STEEL)
		"research_lab":
			# Observatory dome with orbital-ring emblem and antenna.
			_pad(img, c, dark, trim)
			_rect(img, c - 17, c + 2, 34, 16, OUTLINE)
			_rect(img, c - 15, c + 4, 30, 12, dark)
			_circle(img, c, c + 2, 13, OUTLINE)
			_circle(img, c, c + 3, 11, mid)
			_rect(img, c - 11, c + 2, 22, 3, GLASS)
			_rect(img, c - 1, c - 17, 3, 8, STEEL)
			_circle(img, c, c - 18, 3, trim)
			_circle(img, c, c + 4, 7, OUTLINE)
			_circle(img, c, c + 4, 5, GUNMETAL)
			_rect(img, c - 6, c + 3, 12, 2, CYAN)
		"radar":
			# Dish on a mast with a sweeping arc and receiver pod.
			_pad(img, c, dark, trim)
			_rect(img, c - 13, c + 7, 26, 12, OUTLINE)
			_rect(img, c - 11, c + 9, 22, 8, dark)
			_rect(img, c - 2, c - 9, 4, 18, STEEL)
			_circle(img, c, c - 12, 12, OUTLINE)
			_circle(img, c, c - 12, 10, mid)
			_circle(img, c, c - 12, 6, bright)
			_rect(img, c + 4, c - 15, 8, 5, trim)
			_rect(img, c - 8, c + 10, 5, 5, GLASS)
		"turret":
			# Octagonal bunker with rotating gun barrel drawn over the sprite.
			_pad(img, c, dark, trim)
			_circle(img, c, c + 3, 15, OUTLINE)
			_circle(img, c, c + 3, 12, dark)
			_circle(img, c, c + 1, 8, mid)
			_rect(img, c - 5, c - 2, 10, 8, GUNMETAL)
			_rect(img, c - 11, c + 9, 22, 6, OUTLINE)
			_rect(img, c - 9, c + 10, 18, 4, bright)
			_rect(img, c - 12, c - 7, 5, 5, HAZARD)
			_rect(img, c + 8, c - 7, 5, 5, HAZARD)
		"silo":
			# Inset missile silo with open hatch and warhead nose.
			_pad(img, c, dark, trim)
			_rect(img, c - 16, c - 6, 32, 24, OUTLINE)
			_rect(img, c - 14, c - 4, 28, 20, dark)
			_circle(img, c, c + 6, 12, OUTLINE)
			_circle(img, c, c + 6, 10, GUNMETAL)
			_rect(img, c - 4, c - 15, 8, 20, STEEL)
			_rect(img, c - 3, c - 20, 6, 6, DANGER)
			_rect(img, c - 2, c - 23, 4, 4, bright)
			for hx in [-11, 9]:
				_rect(img, c + hx, c - 3, 3, 15, HAZARD)
		"orbital_uplink":
			# Ground laser emitter with satellite dish and vertical beam.
			_pad(img, c, dark, trim)
			_rect(img, c - 14, c + 5, 28, 14, OUTLINE)
			_rect(img, c - 12, c + 7, 24, 10, dark)
			_rect(img, c - 5, c - 2, 10, 10, GUNMETAL)
			_rect(img, c - 2, c - 5, 4, 5, trim)
			_circle(img, c - 9, c - 7, 9, OUTLINE)
			_circle(img, c - 9, c - 7, 7, mid)
			_rect(img, c - 12, c - 9, 6, 5, STEEL)
			_rect(img, c - 1, c - 22, 2, 18, CYAN)
			_circle(img, c, c - 23, 3, Color(1.0, 0.98, 0.80, 1.0))
		"missile_tower":
			# Sapper-built AA tower with triple launcher tubes and radar cap.
			_pad(img, c, dark, trim)
			_rect(img, c - 13, c - 2, 26, 20, OUTLINE)
			_rect(img, c - 11, c, 22, 16, dark)
			for tx in [-8, 0, 8]:
				_rect(img, c + tx - 2, c - 12, 5, 13, OUTLINE)
				_rect(img, c + tx - 1, c - 11, 3, 11, STEEL)
				_rect(img, c + tx - 1, c - 12, 3, 3, DANGER)
			_circle(img, c, c - 15, 6, OUTLINE)
			_circle(img, c, c - 15, 4, bright)
			_rect(img, c - 10, c + 12, 20, 4, trim)
		"wall":
			# Crenellated barrier segment seen from above.
			_rect(img, c - 20, c - 9, 40, 18, OUTLINE)
			_rect(img, c - 18, c - 7, 36, 14, dark)
			for bx in [-16, -6, 4, 14]:
				_rect(img, c + bx, c - 11, 8, 6, mid)
			_rect(img, c - 18, c - 2, 36, 3, bright)
			for jx in [-13, -3, 7, 17]:
				_rect(img, c + jx, c + 5, 2, 4, trim)
		"barbed_wire":
			# Low pickets with two coiled wire strands.
			_rect(img, c - 20, c + 11, 40, 3, dark)
			for px in [-14, 0, 14]:
				_rect(img, c + px - 1, c - 8, 3, 20, GUNMETAL)
				_rect(img, c + px - 3, c - 11, 7, 3, OUTLINE)
			for wy in [-4, 3]:
				_rect(img, c - 20, c + wy, 40, 2, STEEL)
				for wx in range(-18, 20, 6):
					_circle(img, c + wx, c + wy - 2, 2, STEEL)
					_circle(img, c + wx + 3, c + wy + 2, 2, STEEL)
			_rect(img, c - 3, c - 13, 6, 4, HAZARD)
		_:
			return false
	return true


static func _draw_fallback(img: Image, id: String, dark: Color, mid: Color, bright: Color, trim: Color) -> void:
	# Unknown IDs still get a stable, unique marker derived from their name.
	var hash_seed := 0
	for ch in id:
		hash_seed = wrapi(hash_seed * 31 + ch.unicode_at(0), 0, 1 << 16)
	_pad(img, SPRITE_SIZE >> 1, dark, trim)
	_rect(img, 10, 14, 28, 22, OUTLINE)
	_rect(img, 12, 16, 24, 18, mid)
	_rect(img, 12 + int(hash_seed % 9), 18, 8, 5, bright)
	_rect(img, 22 - int(hash_seed % 7), 26, 12, 5, dark)


static func _pad(img: Image, c: int, dark: Color, trim: Color) -> void:
	_rect(img, c - 19, c + 15, 38, 4, OUTLINE)
	_rect(img, c - 17, c + 16, 34, 2, trim)
	_rect(img, c - 14, c - 14, 28, 28, SHADOW)
	_rect(img, c - 12, c - 12, 24, 24, dark)


static func _rect(img: Image, x: int, y: int, w: int, h: int, col: Color) -> void:
	var width := img.get_width()
	var height := img.get_height()
	for py in range(maxi(0, y), mini(height, y + h)):
		for px in range(maxi(0, x), mini(width, x + w)):
			img.set_pixel(px, py, col)


static func _circle(img: Image, cx: int, cy: int, radius: int, col: Color) -> void:
	var width := img.get_width()
	var height := img.get_height()
	var r2 := radius * radius
	for py in range(maxi(0, cy - radius), mini(height, cy + radius + 1)):
		for px in range(maxi(0, cx - radius), mini(width, cx + radius + 1)):
			var dx := px - cx
			var dy := py - cy
			if dx * dx + dy * dy <= r2:
				img.set_pixel(px, py, col)
