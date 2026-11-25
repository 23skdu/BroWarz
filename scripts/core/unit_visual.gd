# scripts/core/unit_visual.gd
class_name UnitVisual
extends RefCounted

# Procedural sprite animation state machine, 48x48 high-detail uniform faction-styled
# unit-type sprite generator, and high-resolution terrain + foliage helpers.

enum AnimState { IDLE = 0, MOVE = 1, FIRE = 2, HIT = 3, EXPLODE = 4 }

const DEFAULT_SPRITE_SIZE: int = 48
const LOD_ICON_SIZE: int = 24
const SpatialCellSize: float = 128.0

static var _shared_texture_cache: Dictionary = {}  # "uid:uclass:state:frame:color_hex:size" -> ImageTexture

static func clear_shared_cache() -> void:
	_shared_texture_cache.clear()

static func shared_cache_size() -> int:
	return _shared_texture_cache.size()

static func lod_sprite_size(camera_zoom: float = 1.0, active_unit_count: int = 0) -> int:
	if camera_zoom < 0.65 or active_unit_count >= 500:
		return LOD_ICON_SIZE
	return DEFAULT_SPRITE_SIZE

static func get_cached_unit_texture(
	unit_class: int, state: int, frame: int, team_color: Color,
	size: int = DEFAULT_SPRITE_SIZE, unit_id: String = ""
) -> ImageTexture:
	var key := "%s:%d:%d:%d:%s:%d" % [unit_id, unit_class, state, frame, team_color.to_html(false), size]
	if not _shared_texture_cache.has(key):
		var img := build_unit_frame_image(unit_class, state, frame, team_color, size, unit_id)
		_shared_texture_cache[key] = ImageTexture.create_from_image(img)
	return _shared_texture_cache[key]

static func build_spatial_grid(unit_positions: Array, cell_size: float = SpatialCellSize) -> Dictionary:
	# Spatial hash grid for 500+ unit nearest-neighbor queries: Vector2i(cx, cy) -> Array[int] (indices)
	var grid: Dictionary = {}
	var inv := 1.0 / maxf(16.0, cell_size)
	for i in range(unit_positions.size()):
		var p: Vector2 = unit_positions[i]
		var cell := Vector2i(int(floor(p.x * inv)), int(floor(p.y * inv)))
		if not grid.has(cell):
			grid[cell] = []
		(grid[cell] as Array).append(i)
	return grid

static func query_spatial_radius(grid: Dictionary, unit_positions: Array, center: Vector2, radius: float, cell_size: float = SpatialCellSize) -> Array[int]:
	var out: Array[int] = []
	var inv := 1.0 / maxf(16.0, cell_size)
	var min_c := Vector2i(int(floor((center.x - radius) * inv)), int(floor((center.y - radius) * inv)))
	var max_c := Vector2i(int(floor((center.x + radius) * inv)), int(floor((center.y + radius) * inv)))
	var r2 := radius * radius
	for cy in range(min_c.y, max_c.y + 1):
		for cx in range(min_c.x, max_c.x + 1):
			var bucket: Array = grid.get(Vector2i(cx, cy), [])
			for idx in bucket:
				var p: Vector2 = unit_positions[int(idx)]
				if center.distance_squared_to(p) <= r2:
					out.append(int(idx))
	return out

const FRAME_COUNTS := {
	AnimState.IDLE: 4,
	AnimState.MOVE: 6,
	AnimState.FIRE: 4,
	AnimState.HIT: 2,
	AnimState.EXPLODE: 8,
}

const FRAME_FPS := {
	AnimState.IDLE: 4.0,
	AnimState.MOVE: 12.0,
	AnimState.FIRE: 16.0,
	AnimState.HIT: 14.0,
	AnimState.EXPLODE: 14.0,
}

static func state_name(state: int) -> String:
	match state:
		AnimState.IDLE: return "idle"
		AnimState.MOVE: return "move"
		AnimState.FIRE: return "fire"
		AnimState.HIT: return "hit"
		AnimState.EXPLODE: return "explode"
		_: return "idle"

static func select_state(is_exploding: bool, fire_anim_timer: float, hit_flash_timer: float, speed_sq: float) -> int:
	if is_exploding:
		return AnimState.EXPLODE
	if fire_anim_timer > 0.0:
		return AnimState.FIRE
	if hit_flash_timer > 0.0:
		return AnimState.HIT
	if speed_sq > 4.0:
		return AnimState.MOVE
	return AnimState.IDLE

static func frame_count(state: int) -> int:
	return int(FRAME_COUNTS.get(state, 4))

static func frame_index(state: int, elapsed: float, loop: bool = true) -> int:
	var count := frame_count(state)
	var fps := float(FRAME_FPS.get(state, 8.0))
	var raw := int(floor(maxf(0.0, elapsed) * fps))
	if loop and state != AnimState.EXPLODE:
		return raw % count
	return clampi(raw, 0, count - 1)

static func explosion_duration() -> float:
	return float(FRAME_COUNTS[AnimState.EXPLODE]) / float(FRAME_FPS[AnimState.EXPLODE])

static func compute_kinematics(state: int, elapsed: float, unit_class: int) -> Dictionary:
	var phase := elapsed * float(FRAME_FPS.get(state, 8.0))
	var stride := 0.0
	var bob := 0.0
	var recoil := 0.0
	var muzzle := 0.0
	var exp_prog := 0.0
	if state == AnimState.MOVE:
		stride = sin(phase * 1.4)
		bob = absf(cos(phase * 1.4)) * (1.8 if unit_class == 0 else 0.7)
	elif state == AnimState.IDLE:
		bob = sin(phase * 0.8) * 0.6
	elif state == AnimState.FIRE:
		var f := frame_index(state, elapsed, false)
		recoil = 4.5 if f <= 1 else (2.0 if f == 2 else 0.5)
		muzzle = 1.0 if f <= 1 else (0.45 if f == 2 else 0.0)
	elif state == AnimState.EXPLODE:
		exp_prog = clampf(elapsed / explosion_duration(), 0.0, 1.0)
	return {
		"stride": stride,
		"bob": bob,
		"recoil": recoil,
		"muzzle_alpha": muzzle,
		"rotor_angle": fmod(elapsed * 18.0, TAU),
		"explosion_progress": exp_prog,
	}

static func generate_explosion_debris(seed_val: int, count: int = 8) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var particles: Array[Dictionary] = []
	for i in range(maxi(1, count)):
		var angle := (TAU / float(maxi(1, count))) * float(i) + rng.randf_range(-0.25, 0.25)
		var speed := rng.randf_range(28.0, 78.0)
		var size := rng.randf_range(2.2, 5.2)
		particles.append({
			"dir": Vector2(cos(angle), sin(angle)),
			"speed": speed,
			"size": size,
			"heat": rng.randf_range(0.3, 1.0),
		})
	return particles

static func terrain_base_color(terrain: int, variation: float = 0.0) -> Color:
	var c := Color(0.28, 0.44, 0.23, 1.0)
	match terrain:
		MapData.Terrain.PLAINS:
			c = Color(0.30, 0.47, 0.24, 1.0)
		MapData.Terrain.FOREST:
			c = Color(0.16, 0.34, 0.16, 1.0)
		MapData.Terrain.SWAMP:
			c = Color(0.23, 0.32, 0.21, 1.0)
		MapData.Terrain.RIVER:
			c = Color(0.14, 0.39, 0.62, 1.0)
		MapData.Terrain.SEA:
			c = Color(0.08, 0.26, 0.48, 1.0)
		MapData.Terrain.MOUNTAIN:
			c = Color(0.43, 0.42, 0.40, 1.0)
		MapData.Terrain.URBAN:
			c = Color(0.37, 0.37, 0.40, 1.0)
		MapData.Terrain.ROAD:
			c = Color(0.50, 0.47, 0.40, 1.0)
		MapData.Terrain.BRIDGE:
			c = Color(0.56, 0.47, 0.33, 1.0)
		MapData.Terrain.WASTELAND:
			c = Color(0.33, 0.23, 0.17, 1.0)
		MapData.Terrain.DESERT:
			c = Color(0.76, 0.65, 0.38, 1.0)
		MapData.Terrain.HILLS:
			c = Color(0.45, 0.50, 0.28, 1.0)
	if variation >= 0.0:
		return c.lightened(clampf(variation * 0.08, 0.0, 0.11))
	return c.darkened(clampf(-variation * 0.08, 0.0, 0.11))

static func build_terrain_map_image(map: MapData, px_per_tile: int = 4) -> Image:
	var ppt := maxi(2, px_per_tile)
	var img := Image.create(map.width * ppt, map.height * ppt, false, Image.FORMAT_RGBA8)
	for ty in range(map.height):
		for tx in range(map.width):
			var t := map.get_terrain(tx, ty)
			var h_noise := float(((tx * 73856093) ^ (ty * 19349663)) & 255) / 127.5 - 1.0
			var base_c := terrain_base_color(t, h_noise)
			var bx := tx * ppt
			var by := ty * ppt
			_fill_rect(img, bx, by, ppt, ppt, base_c)
			if t == MapData.Terrain.FOREST and ppt >= 4:
				var deep_tree := Color(0.09, 0.23, 0.10, 1.0)
				var canopy_hi := Color(0.24, 0.50, 0.22, 1.0)
				img.set_pixel(bx + 1, by + 1, canopy_hi)
				img.set_pixel(bx + 2, by + 1, deep_tree)
				img.set_pixel(bx + 1, by + 2, deep_tree)
				if ((tx + ty) & 1) == 0:
					img.set_pixel(bx + ppt - 1, by + ppt - 1, canopy_hi)
			elif (t == MapData.Terrain.SEA or t == MapData.Terrain.RIVER) and ((tx + ty) % 3 == 0):
				img.set_pixel(bx + 1, by + 1, base_c.lightened(0.16))
			elif t == MapData.Terrain.MOUNTAIN and ppt >= 4:
				var ridge_c := Color(0.62, 0.61, 0.58, 1.0)
				img.set_pixel(bx + 1, by + 1, ridge_c)
				img.set_pixel(bx + 2, by + 2, ridge_c.darkened(0.25))
			elif t == MapData.Terrain.HILLS and ppt >= 4:
				var hill_crest := base_c.lightened(0.18)
				var hill_shadow := base_c.darkened(0.16)
				img.set_pixel(bx + 1, by + 1, hill_crest)
				img.set_pixel(bx + 2, by + 1, hill_crest)
				img.set_pixel(bx + 2, by + 2, hill_shadow)
			elif t == MapData.Terrain.DESERT and ppt >= 4 and ((tx + ty) % 2 == 0):
				img.set_pixel(bx + 1, by + 2, base_c.lightened(0.12))
	return img

static func build_unit_frame_image(
	unit_class: int, state: int, frame: int, team_color: Color,
	size: int = DEFAULT_SPRITE_SIZE, unit_id: String = "", _accent_color: Color = Color.WHITE
) -> Image:
	# Generates a uniform, high-detail pixel-art sprite frame (default 48x48).
	# Every corporation uses the exact same geometry, structural shading, and luminance ramps
	# derived purely from `team_color` so the same unit looks 100% uniform across all factions.
	var target_size := maxi(16, size)
	var base_size := 48
	var img := Image.create(base_size, base_size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := 24

	# Strictly uniform palette derived solely from `team_color`
	var outline := Color(0.05, 0.06, 0.08, 0.98)
	var dark := team_color.darkened(0.45)
	var mid := team_color
	var bright := team_color.lightened(0.32)
	var trim := team_color.lightened(0.62)
	var steel := Color(0.76, 0.80, 0.86, 1.0)
	var gunmetal := Color(0.26, 0.29, 0.34, 1.0)
	var tread := Color(0.14, 0.16, 0.19, 1.0)
	var visor := Color(0.88, 0.97, 1.0, 1.0)

	if state == AnimState.EXPLODE:
		var rad := int(lerpf(6.0, float(c - 2), float(frame + 1) / float(frame_count(state))))
		var fire_c := Color(1.0, 0.9, 0.3, 1.0).lerp(Color(0.9, 0.2, 0.05, 0.75), float(frame) / 7.0)
		_fill_circle(img, c, c, rad, fire_c)
		_fill_circle(img, c, c, maxi(3, int(float(rad) * 0.5)), Color(1.0, 0.98, 0.8, 1.0 - float(frame) * 0.1))
		return _finalize_size(img, target_size)

	var recoil := 3 if (state == AnimState.FIRE and frame < 2) else 0
	var leg_shift := ((frame % 2) * 2 - 1) * 3 if state == AnimState.MOVE else 0

	if not _draw_detailed_unit(img, unit_id, unit_class, state, c, outline, dark, mid, bright, trim, steel, gunmetal, tread, visor, recoil, leg_shift):
		_draw_fallback_domain(img, unit_class, state, c, outline, dark, mid, bright, trim, steel, tread, recoil, leg_shift)

	if state == AnimState.FIRE and frame < 2:
		_fill_circle(img, c + 19, c, 4, Color(1.0, 0.92, 0.35, 1.0))
		_fill_circle(img, c + 20, c, 2, Color(1.0, 1.0, 0.85, 1.0))
	elif state == AnimState.HIT:
		_fill_circle(img, c, c, 10, Color(1.0, 1.0, 1.0, 0.65))

	return _finalize_size(img, target_size)

static func _finalize_size(img: Image, target_size: int) -> Image:
	if img.get_width() == target_size and img.get_height() == target_size:
		return img
	var out := img.duplicate()
	out.resize(target_size, target_size, Image.INTERPOLATE_NEAREST)
	return out

static func _draw_detailed_unit(
	img: Image, unit_id: String, _unit_class: int, state: int, c: int,
	outline: Color, dark: Color, mid: Color, bright: Color, trim: Color,
	steel: Color, gunmetal: Color, tread: Color, visor: Color,
	recoil: int, leg_shift: int
) -> bool:
	match unit_id:
		"riflebot":
			# Articulated line-infantry combat android with pauldrons, visor & assault rifle
			_fill_rect(img, c - 9, c - 13, 18, 26, outline)
			_fill_rect(img, c - 6 + leg_shift, c - 14, 7, 5, tread)
			_fill_rect(img, c - 6 - leg_shift, c + 9, 7, 5, tread)
			_fill_rect(img, c - 8, c - 11, 15, 22, dark)
			_fill_rect(img, c - 6, c - 9, 11, 4, bright)
			_fill_rect(img, c - 6, c + 5, 11, 4, bright)
			_fill_circle(img, c, c, 7, outline)
			_fill_circle(img, c, c, 6, mid)
			_fill_rect(img, c + 2, c - 3, 4, 6, visor)
			# Assault rifle + barrel
			_fill_rect(img, c + 1 - recoil, c + 3, 17, 5, outline)
			_fill_rect(img, c + 2 - recoil, c + 4, 15, 3, steel)
			_fill_rect(img, c + 4 - recoil, c + 4, 5, 3, gunmetal)
		"heavybot":
			# Heavy mountain-assault juggernaut exo-suit with dual pauldrons & rotary autocannon
			_fill_rect(img, c - 12, c - 15, 24, 30, outline)
			_fill_rect(img, c - 8 + leg_shift, c - 16, 9, 5, tread)
			_fill_rect(img, c - 8 - leg_shift, c + 11, 9, 5, tread)
			_fill_rect(img, c - 10, c - 13, 19, 26, dark)
			_fill_rect(img, c - 8, c - 11, 15, 22, mid)
			_fill_rect(img, c - 6, c - 12, 10, 3, trim)
			_fill_rect(img, c - 6, c + 9, 10, 3, trim)
			_fill_circle(img, c + 1, c, 7, bright)
			_fill_rect(img, c + 3, c - 4, 4, 8, visor)
			_fill_rect(img, c + 3 - recoil, c + 3, 18, 7, outline)
			_fill_rect(img, c + 4 - recoil, c + 4, 16, 5, steel)
		"sapperbot":
			# Combat demolition engineer with hazard charge Satchel & heavy breaching clamp
			_fill_rect(img, c - 13, c - 12, 23, 24, outline)
			_fill_rect(img, c - 5 + leg_shift, c - 13, 6, 4, tread)
			_fill_rect(img, c - 5 - leg_shift, c + 9, 6, 4, tread)
			_fill_rect(img, c - 12, c - 8, 6, 16, Color(0.95, 0.72, 0.15, 1.0))
			_fill_rect(img, c - 11, c - 6, 4, 4, gunmetal)
			_fill_rect(img, c - 11, c + 2, 4, 4, gunmetal)
			_fill_rect(img, c - 6, c - 10, 14, 20, dark)
			_fill_circle(img, c, c, 6, mid)
			_fill_rect(img, c + 2, c - 3, 3, 6, visor)
			_fill_rect(img, c + 4 - recoil, c - 5, 13, 10, outline)
			_fill_rect(img, c + 5 - recoil, c - 4, 11, 3, steel)
			_fill_rect(img, c + 5 - recoil, c + 1, 11, 3, steel)
		"stealthbot":
			# Sleek recon/ambush infiltrator with swept cloak fins & twin energy blades
			_fill_rect(img, c - 9, c - 13, 18, 26, outline)
			_fill_rect(img, c - 7, c - 11, 13, 22, dark)
			_fill_rect(img, c - 5, c - 8, 9, 16, mid)
			_fill_circle(img, c, c, 5, bright)
			_fill_rect(img, c + 1, c - 3, 4, 6, visor)
			_fill_rect(img, c + 3 - recoil, c - 9, 15, 4, outline)
			_fill_rect(img, c + 4 - recoil, c - 8, 13, 2, trim)
			_fill_rect(img, c + 3 - recoil, c + 5, 15, 4, outline)
			_fill_rect(img, c + 4 - recoil, c + 6, 13, 2, trim)
		"sniperbot":
			# Long-range sharpshooter with stabilized bipod rail-rifle & optical scope
			_fill_rect(img, c - 9, c - 11, 18, 22, outline)
			_fill_rect(img, c - 7, c - 9, 14, 18, dark)
			_fill_circle(img, c - 1, c, 6, mid)
			_fill_rect(img, c + 1, c - 4, 4, 4, visor)
			_fill_rect(img, c + 1 - recoil, c - 2, 22, 5, outline)
			_fill_rect(img, c + 2 - recoil, c - 1, 20, 3, steel)
			_fill_rect(img, c + 6 - recoil, c - 4, 6, 2, trim)
		"rocketbot":
			# Anti-armor specialist with shoulder-mounted heavy tandem missile tube
			_fill_rect(img, c - 9, c - 12, 18, 24, outline)
			_fill_rect(img, c - 7, c - 10, 14, 20, dark)
			_fill_circle(img, c, c - 1, 6, mid)
			_fill_rect(img, c + 2, c - 4, 3, 5, visor)
			_fill_rect(img, c - 8 - recoil, c + 1, 24, 9, outline)
			_fill_rect(img, c - 7 - recoil, c + 2, 22, 7, gunmetal)
			_fill_rect(img, c + 11 - recoil, c + 2, 4, 7, Color(0.95, 0.35, 0.18, 1.0))
			_fill_rect(img, c - 2 - recoil, c + 3, 8, 3, trim)
		"medicbot", "engineerbot", "adv_engineerbot":
			# Unified worker: hardening gantry frame, hazard beacon, welding arm,
			# and a high-visibility cross/ledger for field repair, capture and build.
			_fill_rect(img, c - 11, c - 12, 22, 24, outline)
			_fill_rect(img, c - 9, c - 10, 18, 20, dark)
			_fill_rect(img, c - 7, c - 8, 14, 16, mid)
			_fill_rect(img, c - 2, c - 6, 4, 12, Color(0.96, 0.99, 0.98, 1.0))
			_fill_rect(img, c - 6, c - 2, 12, 4, Color(0.96, 0.99, 0.98, 1.0))
			_fill_rect(img, c - 6, c - 10, 10, 3, trim)
			_fill_rect(img, c - 6, c + 8, 10, 3, trim)
		"apc":
			# 6x6 Armored Personnel Carrier with Troop Compartment & roof autocannon
			_fill_rect(img, c - 16, c - 12, 32, 24, outline)
			for wx in [-12, -2, 8]:
				_fill_rect(img, c + wx, c - 14, 6, 3, tread)
				_fill_rect(img, c + wx, c + 11, 6, 3, tread)
			_fill_rect(img, c - 14, c - 10, 28, 20, dark)
			_fill_rect(img, c - 11, c - 8, 22, 16, mid)
			_fill_rect(img, c - 9, c - 5, 6, 10, trim)
			_fill_circle(img, c + 2, c, 5, bright)
			_fill_rect(img, c + 4 - recoil, c - 2, 13, 4, steel)
		"light_mech":
			# Fast bipedal scout walker with reverse-joint legs & twin chin autocannons
			_fill_rect(img, c - 12, c - 14, 24, 28, outline)
			_fill_rect(img, c - 8 + leg_shift, c - 15, 10, 4, gunmetal)
			_fill_rect(img, c - 8 - leg_shift, c + 11, 10, 4, gunmetal)
			_fill_rect(img, c - 10, c - 10, 18, 20, dark)
			_fill_rect(img, c - 7, c - 8, 13, 16, mid)
			_fill_circle(img, c, c, 5, bright)
			_fill_rect(img, c + 2, c - 3, 4, 6, visor)
			_fill_rect(img, c + 5 - recoil, c - 7, 13, 3, steel)
			_fill_rect(img, c + 5 - recoil, c + 4, 13, 3, steel)
		"light_tank":
			# Fast reconnaissance tank with compact tracks, sloped glacis & rapid cannon
			_fill_rect(img, c - 15, c - 12, 30, 24, outline)
			_fill_rect(img, c - 14, c - 11, 28, 4, tread)
			_fill_rect(img, c - 14, c + 7, 28, 4, tread)
			_fill_rect(img, c - 12, c - 7, 24, 14, dark)
			_fill_rect(img, c - 9, c - 5, 18, 10, mid)
			_fill_rect(img, c - 7, c - 4, 3, 8, trim)
			_fill_circle(img, c - 1 - recoil, c, 6, bright)
			_fill_rect(img, c + 3 - recoil, c - 2, 15, 4, steel)
		"mbt":
			# Main Battle Tank with heavy armored skirts, reactive glacis, turret & 120mm cannon
			_fill_rect(img, c - 18, c - 14, 36, 28, outline)
			_fill_rect(img, c - 16, c - 13, 32, 5, tread)
			_fill_rect(img, c - 16, c + 8, 32, 5, tread)
			_fill_rect(img, c - 14, c - 8, 28, 16, dark)
			_fill_rect(img, c - 11, c - 6, 22, 12, mid)
			_fill_rect(img, c - 9, c - 5, 4, 10, trim)
			_fill_circle(img, c - 1 - recoil, c, 7, outline)
			_fill_circle(img, c - 1 - recoil, c, 6, bright)
			_fill_rect(img, c + 3 - recoil, c - 3, 19, 6, outline)
			_fill_rect(img, c + 4 - recoil, c - 2, 17, 4, steel)
		"heavy_tank":
			# Twin-barrel siege mammoth tank with wide armored tracks & reinforced turret
			_fill_rect(img, c - 20, c - 16, 40, 32, outline)
			_fill_rect(img, c - 18, c - 15, 36, 6, tread)
			_fill_rect(img, c - 18, c + 9, 36, 6, tread)
			_fill_rect(img, c - 16, c - 9, 32, 18, dark)
			_fill_rect(img, c - 13, c - 7, 26, 14, mid)
			_fill_rect(img, c - 11, c - 6, 5, 12, trim)
			_fill_rect(img, c - 7 - recoil, c - 6, 14, 12, bright)
			_fill_rect(img, c + 5 - recoil, c - 5, 18, 4, steel)
			_fill_rect(img, c + 5 - recoil, c + 1, 18, 4, steel)
		"artillery":
			# Self-Propelled Siege Howitzer with rear recoil spades & long heavy barrel
			_fill_rect(img, c - 18, c - 13, 34, 26, outline)
			_fill_rect(img, c - 16, c - 12, 30, 4, tread)
			_fill_rect(img, c - 16, c + 8, 30, 4, tread)
			_fill_rect(img, c - 15, c - 8, 26, 16, dark)
			_fill_rect(img, c - 12, c - 6, 18, 12, mid)
			_fill_rect(img, c - 10, c - 4, 5, 8, trim)
			_fill_rect(img, c - 4 - recoil, c - 3, 26, 6, outline)
			_fill_rect(img, c - 3 - recoil, c - 2, 24, 4, steel)
		"aa_vehicle":
			# Mobile Air-Defense Flak platform with quad autocannons & rotating radar dish
			_fill_rect(img, c - 16, c - 13, 32, 26, outline)
			_fill_rect(img, c - 15, c - 12, 30, 4, tread)
			_fill_rect(img, c - 15, c + 8, 30, 4, tread)
			_fill_rect(img, c - 13, c - 8, 26, 16, dark)
			_fill_rect(img, c - 10, c - 6, 20, 12, mid)
			_fill_circle(img, c - 2, c, 6, bright)
			_fill_rect(img, c - 6, c - 5, 3, 10, trim)
			_fill_rect(img, c + 3 - recoil, c - 6, 15, 3, steel)
			_fill_rect(img, c + 3 - recoil, c + 3, 15, 3, steel)
		"heavy_mech":
			# Colossal Assault Killer Mech with shoulder missile pods, reactor core & dual heavy lasers
			_fill_rect(img, c - 16, c - 18, 32, 36, outline)
			_fill_rect(img, c - 10 + leg_shift, c - 19, 12, 5, tread)
			_fill_rect(img, c - 10 - leg_shift, c + 14, 12, 5, tread)
			_fill_rect(img, c - 14, c - 15, 26, 30, dark)
			_fill_rect(img, c - 11, c - 12, 20, 24, mid)
			_fill_rect(img, c - 9, c - 14, 12, 4, trim)
			_fill_rect(img, c - 9, c + 10, 12, 4, trim)
			_fill_circle(img, c, c, 7, outline)
			_fill_circle(img, c, c, 6, bright)
			_fill_circle(img, c, c, 3, visor)
			_fill_rect(img, c + 6 - recoil, c - 11, 16, 5, steel)
			_fill_rect(img, c + 6 - recoil, c + 6, 16, 5, steel)
		"siege_mech":
			# Quad-legged Bombardment Mech with dorsal plasma mortar & twin thermal cannons
			_fill_rect(img, c - 17, c - 17, 34, 34, outline)
			_fill_rect(img, c - 15, c - 15, 30, 30, dark)
			_fill_rect(img, c - 12, c - 12, 24, 24, mid)
			_fill_rect(img, c - 8, c - 10, 14, 4, trim)
			_fill_rect(img, c - 8, c + 6, 14, 4, trim)
			_fill_circle(img, c - 2, c, 7, bright)
			_fill_rect(img, c + 2 - recoil, c - 4, 20, 8, outline)
			_fill_rect(img, c + 3 - recoil, c - 3, 18, 6, steel)
		"patrol_boat":
			# Fast Naval Patrol Gunboat with pointed bow, bridge & bow autocannon
			_fill_rect(img, c - 17, c - 8, 34, 16, outline)
			_fill_rect(img, c - 15, c - 6, 30, 12, dark)
			_fill_rect(img, c - 11, c - 4, 22, 8, mid)
			_fill_rect(img, c - 6, c - 3, 7, 6, trim)
			_fill_rect(img, c + 4 - recoil, c - 2, 12, 4, steel)
			if state == AnimState.MOVE:
				_fill_rect(img, c - 20, c - 5 + leg_shift, 4, 10, Color(0.82, 0.96, 1.0, 0.88))
		"corvette":
			# Guided-Missile Corvette with VLS cells, stealth superstructure & twin gun mount
			_fill_rect(img, c - 19, c - 9, 38, 18, outline)
			_fill_rect(img, c - 17, c - 7, 34, 14, dark)
			_fill_rect(img, c - 13, c - 5, 26, 10, mid)
			_fill_rect(img, c - 8, c - 4, 8, 8, bright)
			_fill_rect(img, c + 2, c - 3, 6, 6, trim)
			_fill_rect(img, c + 8 - recoil, c - 2, 12, 4, steel)
		"attack_sub":
			# Tear-drop fast attack submarine with diving planes, conning tower & torpedo tubes
			_fill_rect(img, c - 18, c - 6, 36, 12, outline)
			_fill_rect(img, c - 16, c - 5, 32, 10, dark)
			_fill_rect(img, c - 12, c - 3, 24, 6, mid)
			_fill_rect(img, c + 2, c - 8, 5, 16, dark)
			_fill_rect(img, c - 3, c - 2, 8, 4, trim)
		"ballistic_sub":
			# Strategic boomer submarine with elongated missile deck & dual rows of silo hatches
			_fill_rect(img, c - 21, c - 8, 42, 16, outline)
			_fill_rect(img, c - 19, c - 6, 38, 12, dark)
			_fill_rect(img, c - 15, c - 4, 30, 8, mid)
			for sx in [-10, -4, 2, 8]:
				_fill_rect(img, c + sx, c - 3, 3, 2, trim)
				_fill_rect(img, c + sx, c + 1, 3, 2, trim)
			_fill_rect(img, c + 10, c - 2, 6, 4, bright)
		"landing_craft":
			# Amphibious assault transport with bow ramp, open cargo bay & twin stern thrusters
			_fill_rect(img, c - 18, c - 11, 36, 22, outline)
			_fill_rect(img, c - 16, c - 9, 32, 18, dark)
			_fill_rect(img, c - 12, c - 6, 22, 12, gunmetal)
			_fill_rect(img, c - 14, c - 8, 26, 2, mid)
			_fill_rect(img, c - 14, c + 6, 26, 2, mid)
			_fill_rect(img, c + 12, c - 7, 4, 14, steel)
			_fill_rect(img, c - 10, c - 3, 6, 6, trim)
		"hovercraft":
			# Amphibious air-cushion assault craft with rubber skirt, deck cabin & twin rear fans
			_fill_rect(img, c - 18, c - 13, 36, 26, outline)
			_fill_rect(img, c - 16, c - 11, 32, 22, tread)
			_fill_rect(img, c - 13, c - 8, 26, 16, dark)
			_fill_rect(img, c - 10, c - 6, 20, 12, mid)
			_fill_rect(img, c - 14, c - 7, 4, 5, steel)
			_fill_rect(img, c - 14, c + 2, 4, 5, steel)
			_fill_rect(img, c - 2, c - 4, 8, 8, trim)
			_fill_rect(img, c + 6 - recoil, c - 2, 11, 4, steel)
		"cruiser":
			# Naval Guided-Missile Cruiser with helipad, radar mast & fore/aft turrets
			_fill_rect(img, c - 21, c - 9, 42, 18, outline)
			_fill_rect(img, c - 19, c - 7, 38, 14, dark)
			_fill_rect(img, c - 15, c - 5, 30, 10, mid)
			_fill_rect(img, c - 6, c - 4, 12, 8, bright)
			_fill_rect(img, c - 2, c - 3, 4, 6, trim)
			_fill_rect(img, c + 9 - recoil, c - 2, 11, 4, steel)
			_fill_rect(img, c - 16, c - 2, 8, 4, steel)
		"battleship":
			# Heavy dreadnought battleship with broad beam, armored citadel & triple heavy gun turrets
			_fill_rect(img, c - 22, c - 11, 44, 22, outline)
			_fill_rect(img, c - 20, c - 9, 40, 18, dark)
			_fill_rect(img, c - 16, c - 7, 32, 14, mid)
			_fill_rect(img, c - 8, c - 5, 14, 10, bright)
			_fill_rect(img, c - 4, c - 4, 6, 8, trim)
			# Fore and aft multi-barrel turrets
			_fill_rect(img, c + 7 - recoil, c - 5, 14, 3, steel)
			_fill_rect(img, c + 7 - recoil, c - 1, 14, 3, steel)
			_fill_rect(img, c + 7 - recoil, c + 3, 14, 3, steel)
			_fill_rect(img, c - 18, c - 3, 9, 6, steel)
		"aircraft_carrier":
			# Fleet Aircraft Carrier with angled flight deck, runway striping & starboard island
			_fill_rect(img, c - 22, c - 12, 44, 24, outline)
			_fill_rect(img, c - 20, c - 10, 40, 20, dark)
			_fill_rect(img, c - 18, c - 8, 36, 16, gunmetal)
			# Flight deck centerline markings
			for rx in range(-14, 16, 6):
				_fill_rect(img, c + rx, c - 1, 4, 2, Color(0.95, 0.95, 0.95, 0.95))
			# Island superstructure + faction deck stripe
			_fill_rect(img, c - 6, c - 10, 14, 4, mid)
			_fill_rect(img, c - 4, c - 10, 8, 2, trim)
			_fill_rect(img, c - 16, c + 6, 32, 2, mid)
		"frogbot", "frogman":
			# Elite amphibious stealth frogbot with twin hydro-thruster tanks, dive fins & limpet demolition mine
			_fill_rect(img, c - 10, c - 9, 20, 18, outline)
			_fill_rect(img, c - 11 + leg_shift, c - 7, 5, 4, trim)
			_fill_rect(img, c - 11 - leg_shift, c + 3, 5, 4, trim)
			_fill_rect(img, c - 6, c - 7, 12, 14, dark)
			_fill_rect(img, c - 4, c - 5, 8, 10, mid)
			_fill_circle(img, c + 4, c, 4, bright)
			_fill_rect(img, c + 5, c - 2, 3, 4, visor)
		"scout_drone":
			# High-speed reconnaissance UAV with slender high-aspect wings & nose camera pod
			_fill_rect(img, c - 6, c - 18, 12, 36, outline)
			_fill_rect(img, c - 13, c - 4, 26, 8, outline)
			_fill_rect(img, c - 4, c - 16, 8, 32, dark)
			_fill_rect(img, c - 3, c - 14, 6, 28, mid)
			_fill_rect(img, c - 11, c - 3, 22, 6, bright)
			_fill_rect(img, c - 3, c - 16, 6, 3, trim)
			_fill_rect(img, c - 3, c + 13, 6, 3, trim)
			_fill_circle(img, c + 6, c, 3, visor)
		"fighter_drone":
			# Swept forward-delta Air Superiority Fighter with twin wingtip missiles & nose cannon
			_fill_rect(img, c - 10, c - 18, 18, 36, outline)
			_fill_rect(img, c - 16, c - 5, 32, 10, outline)
			_fill_rect(img, c - 8, c - 16, 14, 32, dark)
			_fill_rect(img, c - 6, c - 13, 10, 26, mid)
			_fill_rect(img, c - 14, c - 4, 28, 8, bright)
			_fill_rect(img, c - 8, c - 17, 10, 3, trim)
			_fill_rect(img, c - 8, c + 14, 10, 3, trim)
			_fill_rect(img, c + 3, c - 2, 7, 4, visor)
			_fill_rect(img, c + 12 - recoil, c - 1, 8, 2, steel)
		"bomber_drone":
			# Heavy flying-wing strategic strike bomber with twin engine nacelles & bomb bay
			_fill_rect(img, c - 14, c - 20, 26, 40, outline)
			_fill_rect(img, c - 12, c - 18, 22, 36, dark)
			_fill_rect(img, c - 9, c - 14, 16, 28, mid)
			_fill_rect(img, c - 5, c - 8, 12, 16, bright)
			_fill_rect(img, c - 8, c - 16, 8, 3, trim)
			_fill_rect(img, c - 8, c + 13, 8, 3, trim)
			_fill_rect(img, c + 6 - recoil, c - 3, 10, 6, steel)
		"awacs":
			# Airborne Early-Warning aircraft with large dorsal rotating radar rotodome
			_fill_rect(img, c - 8, c - 19, 16, 38, outline)
			_fill_rect(img, c - 17, c - 5, 34, 10, outline)
			_fill_rect(img, c - 6, c - 17, 12, 34, dark)
			_fill_rect(img, c - 15, c - 3, 30, 6, mid)
			_fill_circle(img, c - 1, c, 11, outline)
			_fill_circle(img, c - 1, c, 9, bright)
			_fill_rect(img, c - 9, c - 2, 16, 4, trim)
		# --- AI-only NPC faction hulls (IDs 4-7) ---
		"ufo_wisp":
			# Vesper Ascendancy: agile scout saucer with luminous lime rim & sensor dome
			var alien_glow := Color(0.78, 1.0, 0.31, 1.0)
			_fill_circle(img, c, c, 14, outline)
			_fill_circle(img, c, c, 12, dark)
			_fill_circle(img, c, c, 9, mid)
			_fill_circle(img, c + 1, c, 5, bright)
			_fill_circle(img, c + 1, c, 3, alien_glow)
			# Orbital sensor nodes around the saucer rim
			for pt in [Vector2i(10, 0), Vector2i(-10, 0), Vector2i(0, -10), Vector2i(0, 10)]:
				_fill_rect(img, c + pt.x - 1, c + pt.y - 1, 3, 3, alien_glow)
			_fill_rect(img, c + 10 - recoil, c - 1, 6, 2, trim)
		"ufo_talon":
			# Vesper Ascendancy: swept crescent-wing interceptor saucer with twin plasma prongs
			var alien_glow := Color(0.78, 1.0, 0.31, 1.0)
			_fill_circle(img, c - 2, c, 13, outline)
			_fill_rect(img, c - 6, c - 18, 18, 7, outline)
			_fill_rect(img, c - 6, c + 11, 18, 7, outline)
			_fill_rect(img, c + 6 - recoil, c - 16, 13, 5, outline)
			_fill_rect(img, c + 6 - recoil, c + 11, 13, 5, outline)
			_fill_circle(img, c - 2, c, 11, dark)
			_fill_rect(img, c - 4, c - 16, 14, 4, mid)
			_fill_rect(img, c - 4, c + 12, 14, 4, mid)
			_fill_rect(img, c + 7 - recoil, c - 15, 10, 3, alien_glow)
			_fill_rect(img, c + 7 - recoil, c + 12, 10, 3, alien_glow)
			_fill_circle(img, c - 1, c, 7, mid)
			_fill_circle(img, c, c, 4, bright)
			_fill_circle(img, c + 1, c, 2, alien_glow)
		"ufo_nova":
			# Vesper Ascendancy: massive ringed dreadnought saucer with 4 outer pylons & plasma core
			var alien_glow := Color(0.78, 1.0, 0.31, 1.0)
			_fill_circle(img, c, c, 20, outline)
			_fill_circle(img, c, c, 18, dark)
			_fill_circle(img, c, c, 15, mid)
			_fill_circle(img, c, c, 11, dark)
			_fill_circle(img, c, c, 9, bright)
			_fill_circle(img, c, c, 5, alien_glow)
			_fill_circle(img, c, c, 2, Color(1.0, 1.0, 0.92, 1.0))
			for px in [-15, 13]:
				_fill_rect(img, c + px, c - 3, 3, 6, trim)
			for py in [-15, 13]:
				_fill_rect(img, c - 3, c + py, 6, 3, trim)
			_fill_rect(img, c + 11 - recoil, c - 5, 10, 3, alien_glow)
			_fill_rect(img, c + 11 - recoil, c + 2, 10, 3, alien_glow)
		"abyssal_trireme":
			# Thalassa Dominion: armored Atlantean prow-ram warship with outrigger hydrofoils
			var aqua := Color(0.39, 1.0, 0.88, 1.0)
			_fill_rect(img, c - 20, c - 10, 38, 20, outline)
			_fill_rect(img, c - 8, c - 16, 16, 32, outline)
			_fill_rect(img, c + 14, c - 4, 9, 8, outline)
			_fill_rect(img, c - 18, c - 8, 34, 16, dark)
			_fill_rect(img, c - 6, c - 14, 12, 28, mid)
			_fill_rect(img, c - 14, c - 5, 26, 10, mid)
			_fill_rect(img, c + 12, c - 2, 10, 4, aqua)
			_fill_circle(img, c - 2, c, 5, bright)
			_fill_rect(img, c - 10, c - 14, 6, 3, aqua)
			_fill_rect(img, c - 10, c + 11, 6, 3, aqua)
			_fill_rect(img, c + 4 - recoil, c - 4, 12, 2, steel)
			_fill_rect(img, c + 4 - recoil, c + 2, 12, 2, steel)
		"leviathan_carrier":
			# Thalassa Dominion: twin-hulled Atlantean catamaran capital carrier with rune flight deck
			var aqua := Color(0.39, 1.0, 0.88, 1.0)
			_fill_rect(img, c - 22, c - 15, 44, 30, outline)
			_fill_rect(img, c - 20, c - 13, 40, 7, dark)
			_fill_rect(img, c - 20, c + 6, 40, 7, dark)
			_fill_rect(img, c - 18, c - 11, 36, 4, mid)
			_fill_rect(img, c - 18, c + 7, 36, 4, mid)
			_fill_rect(img, c - 16, c - 6, 32, 12, gunmetal)
			# Glowing Atlantean trident launch runes on deck
			_fill_rect(img, c - 12, c - 1, 24, 2, aqua)
			_fill_rect(img, c + 4, c - 4, 6, 2, aqua)
			_fill_rect(img, c + 4, c + 2, 6, 2, aqua)
			_fill_rect(img, c - 14, c - 5, 7, 10, bright)
			_fill_rect(img, c - 12, c - 3, 3, 6, trim)
		"nereid_raider":
			# Thalassa Dominion: razor-fast Atlantean hydro-dart skiff with swept fins
			var aqua := Color(0.39, 1.0, 0.88, 1.0)
			_fill_rect(img, c - 17, c - 6, 34, 12, outline)
			_fill_rect(img, c - 14, c - 13, 12, 26, outline)
			_fill_rect(img, c - 15, c - 4, 30, 8, dark)
			_fill_rect(img, c - 12, c - 11, 8, 22, mid)
			_fill_rect(img, c - 8, c - 3, 22, 6, bright)
			_fill_rect(img, c + 8 - recoil, c - 1, 11, 2, aqua)
			_fill_rect(img, c - 12, c - 10, 4, 3, aqua)
			_fill_rect(img, c - 12, c + 7, 4, 3, aqua)
		"bone_legionary":
			# Gravebound Legion: skeletal line soldier with skull helm, bone shield & glaive
			var bone := Color(0.85, 0.79, 0.64, 1.0)
			_fill_rect(img, c - 9, c - 13, 18, 26, outline)
			_fill_rect(img, c - 6 + leg_shift, c - 14, 7, 4, bone)
			_fill_rect(img, c - 6 - leg_shift, c + 10, 7, 4, bone)
			_fill_rect(img, c - 7, c - 10, 13, 20, dark)
			# Ribbed skeletal armor bars
			for ry in [-7, -2, 3]:
				_fill_rect(img, c - 5, c + ry, 9, 2, bone)
			# Left-flank tower shield
			_fill_rect(img, c - 1, c - 14, 12, 6, outline)
			_fill_rect(img, c, c - 13, 10, 4, mid)
			_fill_rect(img, c + 2, c - 12, 6, 2, bone)
			# Skull helmet with glowing olive visor eyes
			_fill_circle(img, c, c, 6, outline)
			_fill_circle(img, c, c, 5, bone)
			_fill_rect(img, c + 2, c - 3, 2, 2, bright)
			_fill_rect(img, c + 2, c + 1, 2, 2, bright)
			# Bone glaive rifle
			_fill_rect(img, c + 2 - recoil, c + 4, 18, 4, outline)
			_fill_rect(img, c + 3 - recoil, c + 5, 16, 2, bone)
		"ghoul_stalker":
			# Gravebound Legion: hunched undead stalker with dorsal bone spikes & toxic claws
			var bone := Color(0.85, 0.79, 0.64, 1.0)
			_fill_rect(img, c - 11, c - 11, 20, 22, outline)
			_fill_rect(img, c - 9, c - 9, 16, 18, dark)
			_fill_rect(img, c - 7, c - 5, 12, 10, mid)
			# Dorsal spine ridges
			for sx in [-8, -4, 0]:
				_fill_rect(img, c + sx, c - 2, 2, 4, bone)
			_fill_circle(img, c + 3, c, 5, bone)
			_fill_rect(img, c + 5, c - 2, 2, 4, bright)
			# Twin toxic scythe-blades
			_fill_rect(img, c + 4 - recoil, c - 12, 16, 4, outline)
			_fill_rect(img, c + 5 - recoil, c - 11, 14, 2, bright)
			_fill_rect(img, c + 4 - recoil, c + 8, 16, 4, outline)
			_fill_rect(img, c + 5 - recoil, c + 9, 14, 2, bright)
		"lichen_colossus":
			# Gravebound Legion: colossal ossuary siege juggernaut with mossy pauldrons & furnace core
			var bone := Color(0.85, 0.79, 0.64, 1.0)
			_fill_rect(img, c - 17, c - 19, 34, 38, outline)
			_fill_rect(img, c - 11 + leg_shift, c - 20, 12, 5, tread)
			_fill_rect(img, c - 11 - leg_shift, c + 15, 12, 5, tread)
			_fill_rect(img, c - 15, c - 16, 28, 32, dark)
			_fill_rect(img, c - 12, c - 14, 22, 28, mid)
			# Bone rib pauldrons
			_fill_rect(img, c - 10, c - 15, 14, 5, bone)
			_fill_rect(img, c - 10, c + 10, 14, 5, bone)
			# Glowing necrotic core
			_fill_circle(img, c - 1, c, 7, outline)
			_fill_circle(img, c - 1, c, 5, bright)
			_fill_circle(img, c - 1, c, 2, trim)
			# Giant siege maul + mortar arm
			_fill_rect(img, c + 6 - recoil, c - 12, 16, 6, outline)
			_fill_rect(img, c + 7 - recoil, c - 11, 14, 4, bone)
			_fill_rect(img, c + 6 - recoil, c + 6, 16, 6, outline)
			_fill_rect(img, c + 7 - recoil, c + 7, 14, 4, gunmetal)
		"lumen_operative":
			# Lumen Cabal: hooded gold-trimmed infiltrator with glowing violet psi-blades
			var violet := Color(0.61, 0.48, 1.0, 1.0)
			_fill_rect(img, c - 10, c - 13, 20, 26, outline)
			_fill_rect(img, c - 8, c - 11, 16, 22, dark)
			_fill_rect(img, c - 6, c - 9, 12, 18, mid)
			_fill_rect(img, c - 8, c - 11, 4, 22, violet)
			# Shrouded cowl with single radiant eye
			_fill_circle(img, c + 1, c, 6, outline)
			_fill_circle(img, c + 1, c, 5, dark)
			_fill_circle(img, c + 3, c, 2, bright)
			# Twin violet energy blades
			_fill_rect(img, c + 4 - recoil, c - 9, 15, 3, violet)
			_fill_rect(img, c + 4 - recoil, c + 6, 15, 3, violet)
		"lumen_oracle":
			# Lumen Cabal: floating gilded All-Seeing Eye construct with cardinal obelisks
			var violet := Color(0.61, 0.48, 1.0, 1.0)
			_fill_circle(img, c, c, 15, outline)
			_fill_circle(img, c, c, 13, dark)
			_fill_rect(img, c - 10, c - 10, 20, 20, mid)
			# All-seeing central eye
			_fill_circle(img, c, c, 8, outline)
			_fill_circle(img, c, c, 7, Color(0.98, 0.96, 0.88, 1.0))
			_fill_circle(img, c + 1, c, 4, violet)
			_fill_circle(img, c + 2, c, 2, outline)
			# Four floating cardinal obelisk pylons
			for pt in [Vector2i(0, -18), Vector2i(0, 16), Vector2i(-18, 0), Vector2i(16, 0)]:
				_fill_rect(img, c + pt.x - 2, c + pt.y - 2, 5, 5, outline)
				_fill_rect(img, c + pt.x - 1, c + pt.y - 1, 3, 3, bright)
		"lumen_enforcer":
			# Lumen Cabal: heavy gilded pyramid-turret shock enforcer with twin energy lances
			var violet := Color(0.61, 0.48, 1.0, 1.0)
			_fill_rect(img, c - 19, c - 15, 38, 30, outline)
			_fill_rect(img, c - 17, c - 14, 34, 5, tread)
			_fill_rect(img, c - 17, c + 9, 34, 5, tread)
			_fill_rect(img, c - 15, c - 9, 30, 18, dark)
			_fill_rect(img, c - 12, c - 7, 24, 14, mid)
			_fill_rect(img, c - 10, c - 5, 6, 10, violet)
			# Pyramid turret cap with radiant eye
			_fill_rect(img, c - 6 - recoil, c - 6, 13, 12, outline)
			_fill_rect(img, c - 5 - recoil, c - 5, 11, 10, bright)
			_fill_circle(img, c - recoil, c, 3, violet)
			# Twin golden energy lances
			_fill_rect(img, c + 6 - recoil, c - 6, 16, 3, trim)
			_fill_rect(img, c + 6 - recoil, c + 3, 16, 3, trim)
		_:
			return false
	return true

static func _draw_fallback_domain(
	img: Image, unit_class: int, state: int, c: int,
	outline: Color, dark: Color, mid: Color, bright: Color, trim: Color,
	steel: Color, tread: Color, recoil: int, leg_shift: int
) -> void:
	match unit_class:
		1, 4, 7:
			_fill_rect(img, c - 16, c - 13, 32, 26, outline)
			_fill_rect(img, c - 15, c - 12, 30, 4, tread)
			_fill_rect(img, c - 15, c + 8, 30, 4, tread)
			_fill_rect(img, c - 13, c - 8, 26, 16, dark)
			_fill_rect(img, c - 10, c - 6, 20, 12, mid)
			_fill_rect(img, c - 8, c - 5, 4, 10, trim)
			_fill_circle(img, c - recoil, c, 6, bright)
			_fill_rect(img, c + 3 - recoil, c - 2, 15, 4, steel)
		2:
			_fill_rect(img, c - 18, c - 8, 36, 16, outline)
			_fill_rect(img, c - 16, c - 6, 32, 12, dark)
			_fill_rect(img, c - 12, c - 4, 24, 8, mid)
			_fill_rect(img, c - 6, c - 3, 5, 6, trim)
			_fill_rect(img, c + 2 - recoil, c - 2, 12, 4, steel)
			if state == AnimState.MOVE:
				_fill_rect(img, c - 20, c - 4 + leg_shift, 3, 8, Color(0.8, 0.95, 1.0, 0.85))
		3:
			_fill_rect(img, c - 6, c - 17, 12, 34, outline)
			_fill_rect(img, c - 15, c - 5, 30, 10, outline)
			_fill_rect(img, c - 4, c - 15, 8, 30, dark)
			_fill_rect(img, c - 13, c - 3, 26, 6, mid)
			_fill_circle(img, c, c, 5, bright)
			_fill_rect(img, c + 4 - recoil, c - 1, 10, 2, steel)
		_:
			_fill_rect(img, c - 8, c - 11, 16, 22, outline)
			_fill_rect(img, c - 6, c - 9, 12, 18, dark)
			_fill_circle(img, c, c, 6, mid)
			_fill_rect(img, c + 2, c - 3, 3, 6, trim)
			_fill_rect(img, c + 3 - recoil, c + 2, 12, 3, steel)

static func _fill_rect(img: Image, rx: int, ry: int, rw: int, rh: int, col: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for y in range(maxi(0, ry), mini(h, ry + rh)):
		for x in range(maxi(0, rx), mini(w, rx + rw)):
			img.set_pixel(x, y, col)

static func _fill_circle(img: Image, cx: int, cy: int, radius: int, col: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var r2 := radius * radius
	for y in range(maxi(0, cy - radius), mini(h, cy + radius + 1)):
		for x in range(maxi(0, cx - radius), mini(w, cx + radius + 1)):
			var dx := x - cx
			var dy := y - cy
			if dx * dx + dy * dy <= r2:
				img.set_pixel(x, y, col)
