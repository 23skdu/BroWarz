# scripts/core/unit_visual.gd
class_name UnitVisual
extends RefCounted

# Procedural sprite animation state machine, high-contrast faction-styled
# unit-type sprite generator, and high-resolution terrain + foliage helpers.

enum AnimState { IDLE = 0, MOVE = 1, FIRE = 2, HIT = 3, EXPLODE = 4 }

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
	if variation >= 0.0:
		return c.lightened(clampf(variation * 0.08, 0.0, 0.11))
	return c.darkened(clampf(-variation * 0.08, 0.0, 0.11))

static func build_terrain_map_image(map: MapData, px_per_tile: int = 4) -> Image:
	# Renders a high-resolution terrain texture (e.g. 512x512 for 128x128 tiles)
	# with sub-tile texture variation, water wave crests, mountain ridges, and forest foliage.
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
	return img

static func build_unit_frame_image(
	unit_class: int, state: int, frame: int, team_color: Color,
	size: int = 32, unit_id: String = "", accent_color: Color = Color.WHITE
) -> Image:
	# Generates a crisp RGBA pixel-art sprite frame with high-contrast dark outlines
	# and corporation primary + accent livery so units pop against terrain and each other.
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := size / 2
	var outline := Color(0.05, 0.06, 0.08, 0.96)
	var dark := team_color.darkened(0.42)
	var mid := team_color
	var bright := team_color.lightened(0.36)
	var accent := accent_color if accent_color != Color.WHITE else team_color.lightened(0.52)
	var steel := Color(0.76, 0.80, 0.86, 1.0)

	if state == AnimState.EXPLODE:
		var rad := int(lerpf(4.0, float(c - 2), float(frame + 1) / float(frame_count(state))))
		var fire_c := Color(1.0, 0.9, 0.3, 1.0).lerp(Color(0.9, 0.2, 0.05, 0.75), float(frame) / 7.0)
		_fill_circle(img, c, c, rad, fire_c)
		_fill_circle(img, c, c, maxi(2, rad / 2), Color(1.0, 0.98, 0.8, 1.0 - float(frame) * 0.1))
		return img

	var recoil := 2 if (state == AnimState.FIRE and frame < 2) else 0
	var leg_shift := ((frame % 2) * 2 - 1) * 2 if state == AnimState.MOVE else 0

	if unit_id != "" and _draw_unit_id(img, unit_id, state, frame, c, outline, dark, mid, bright, accent, steel, recoil, leg_shift):
		if state == AnimState.FIRE and frame < 2:
			_fill_circle(img, c + 13, c, 3, Color(1.0, 0.92, 0.35, 1.0))
		elif state == AnimState.HIT:
			_fill_circle(img, c, c, 7, Color(1.0, 1.0, 1.0, 0.65))
		return img

	match unit_class:
		1, 4, 7: # Vehicle / Tank / Mech / Hovercraft chassis with high-contrast outline + turret
			_fill_rect(img, c - 11, c - 10, 22, 20, outline)
			_fill_rect(img, c - 10, c - 9, 20, 4, Color(0.16, 0.18, 0.2, 1.0))
			_fill_rect(img, c - 10, c + 5, 20, 4, Color(0.16, 0.18, 0.2, 1.0))
			_fill_rect(img, c - 8, c - 6, 16, 12, dark)
			_fill_rect(img, c - 6, c - 5, 12, 10, mid)
			_fill_rect(img, c - 5, c - 4, 3, 8, accent)
			_fill_circle(img, c - recoil, c, 5, bright)
			_fill_rect(img, c + 2 - recoil, c - 2, 10, 4, steel)
		2: # Naval hull + wake
			_fill_rect(img, c - 12, c - 6, 24, 12, outline)
			_fill_rect(img, c - 11, c - 5, 22, 10, dark)
			_fill_rect(img, c - 8, c - 4, 16, 8, mid)
			_fill_rect(img, c - 5, c - 3, 3, 6, accent)
			_fill_rect(img, c - 2 - recoil, c - 2, 10, 4, steel)
			if state == AnimState.MOVE:
				_fill_rect(img, c - 14, c - 3 + leg_shift, 3, 6, Color(0.8, 0.95, 1.0, 0.85))
		3: # Air drone / swept wings + rotor
			_fill_rect(img, c - 4, c - 12, 8, 24, outline)
			_fill_rect(img, c - 10, c - 4, 20, 8, outline)
			_fill_rect(img, c - 3, c - 11, 6, 22, dark)
			_fill_rect(img, c - 9, c - 3, 18, 6, mid)
			_fill_rect(img, c - 3, c - 11, 4, 3, accent)
			_fill_rect(img, c - 3, c + 8, 4, 3, accent)
			_fill_circle(img, c, c, 4, bright)
			_fill_rect(img, c + 3 - recoil, c - 1, 8, 2, steel)
		_: # Infantry robot (articulated shoulders, visor, rifle)
			_fill_rect(img, c - 6, c - 8, 12, 16, outline)
			_fill_rect(img, c - 4 + leg_shift, c - 7, 5, 4, Color(0.22, 0.25, 0.28, 1.0))
			_fill_rect(img, c - 4 - leg_shift, c + 3, 5, 4, Color(0.22, 0.25, 0.28, 1.0))
			_fill_rect(img, c - 5, c - 6, 10, 12, dark)
			_fill_circle(img, c, c, 5, mid)
			_fill_rect(img, c + 1, c - 2, 3, 4, accent)
			_fill_rect(img, c + 2 - recoil, c + 1, 9, 3, steel)

	if state == AnimState.FIRE and frame < 2:
		_fill_circle(img, c + 13, c, 3, Color(1.0, 0.92, 0.35, 1.0))
	elif state == AnimState.HIT:
		_fill_circle(img, c, c, 7, Color(1.0, 1.0, 1.0, 0.65))
	return img

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

static func _draw_unit_id(
	img: Image, unit_id: String, state: int, _frame: int, c: int,
	outline: Color, dark: Color, mid: Color, bright: Color, accent: Color, steel: Color,
	recoil: int, leg_shift: int
) -> bool:
	match unit_id:
		"riflebot":
			_fill_rect(img, c - 6, c - 8, 12, 16, outline)
			_fill_rect(img, c - 4 + leg_shift, c - 7, 5, 4, Color(0.22, 0.25, 0.28, 1))
			_fill_rect(img, c - 4 - leg_shift, c + 3, 5, 4, Color(0.22, 0.25, 0.28, 1))
			_fill_rect(img, c - 5, c - 6, 10, 12, dark)
			_fill_circle(img, c, c, 5, mid)
			_fill_rect(img, c - 3, c - 6, 5, 2, accent)
			_fill_rect(img, c + 1, c - 2, 3, 4, accent)
			_fill_rect(img, c + 2 - recoil, c + 1, 9, 3, steel)
		"heavybot":
			_fill_rect(img, c - 8, c - 9, 16, 18, outline)
			_fill_rect(img, c - 7, c - 8, 14, 16, dark)
			_fill_rect(img, c - 5, c - 6, 10, 12, mid)
			_fill_rect(img, c - 4, c - 7, 6, 2, accent)
			_fill_rect(img, c - 4, c + 5, 6, 2, accent)
			_fill_rect(img, c - 2, c - 3, 5, 6, bright)
			_fill_rect(img, c + 3 - recoil, c + 2, 9, 3, steel)
		"sapperbot":
			_fill_rect(img, c - 10, c - 7, 16, 14, outline)
			_fill_rect(img, c - 5, c - 6, 10, 12, dark)
			_fill_circle(img, c, c, 5, mid)
			_fill_rect(img, c - 9, c - 4, 4, 8, Color(0.95, 0.75, 0.18, 1))
			_fill_rect(img, c + 1, c - 2, 3, 4, accent)
			_fill_rect(img, c + 2 - recoil, c + 1, 9, 3, steel)
		"stealthbot":
			_fill_rect(img, c - 5, c - 9, 10, 18, outline)
			_fill_rect(img, c - 4, c - 8, 8, 16, dark)
			_fill_circle(img, c, c, 4, mid)
			_fill_rect(img, c + 2 - recoil, c - 5, 7, 2, accent)
			_fill_rect(img, c + 2 - recoil, c + 3, 7, 2, accent)
			_fill_rect(img, c + 1, c - 2, 2, 4, accent)
		"sniperbot":
			_fill_rect(img, c - 5, c - 7, 10, 14, outline)
			_fill_rect(img, c - 4, c - 6, 8, 12, dark)
			_fill_circle(img, c, c - 1, 4, mid)
			_fill_rect(img, c + 1, c - 3, 3, 3, accent)
			_fill_rect(img, c + 2 - recoil, c - 1, 13, 2, steel)
		"rocketbot":
			_fill_rect(img, c - 6, c - 7, 12, 14, outline)
			_fill_rect(img, c - 5, c - 6, 10, 12, dark)
			_fill_circle(img, c, c, 5, mid)
			_fill_rect(img, c - 3, c - 5, 5, 2, accent)
			_fill_rect(img, c + 1 - recoil, c - 3, 11, 5, Color(0.85, 0.32, 0.2, 1))
		"medicbot":
			_fill_rect(img, c - 6, c - 7, 12, 14, outline)
			_fill_rect(img, c - 5, c - 6, 10, 12, dark)
			_fill_circle(img, c, c, 5, mid)
			_fill_rect(img, c - 1, c - 4, 3, 8, Color(0.95, 1.0, 0.95, 1))
			_fill_rect(img, c - 3, c - 1, 7, 3, Color(0.95, 1.0, 0.95, 1))
		"engineerbot":
			_fill_rect(img, c - 6, c - 7, 12, 14, outline)
			_fill_rect(img, c - 5, c - 6, 10, 12, dark)
			_fill_circle(img, c, c, 5, mid)
			_fill_rect(img, c - 2, c - 2, 4, 4, Color(0.98, 0.82, 0.22, 1))
			_fill_rect(img, c + 2 - recoil, c - 3, 8, 2, accent)
		"apc":
			_fill_rect(img, c - 11, c - 7, 22, 14, outline)
			_fill_rect(img, c - 9, c - 6, 18, 12, dark)
			_fill_rect(img, c - 7, c - 4, 14, 8, mid)
			_fill_rect(img, c - 4, c - 3, 3, 6, accent)
			_fill_rect(img, c + 3 - recoil, c - 1, 7, 2, steel)
		"light_mech", "heavy_mech", "siege_mech":
			_fill_rect(img, c - 10, c - 10, 20, 20, outline)
			_fill_rect(img, c - 9, c - 9, 18, 5, Color(0.18, 0.2, 0.22, 1))
			_fill_rect(img, c - 9, c + 4, 18, 5, Color(0.18, 0.2, 0.22, 1))
			_fill_rect(img, c - 7, c - 6, 14, 12, dark)
			_fill_rect(img, c - 5, c - 5, 10, 10, mid)
			_fill_rect(img, c - 5, c - 8, 6, 2, accent)
			_fill_rect(img, c - 5, c + 6, 6, 2, accent)
			_fill_circle(img, c, c, 4, bright)
			_fill_rect(img, c + 2 - recoil, c - 5, 11, 3, steel)
			_fill_rect(img, c + 2 - recoil, c + 2, 11, 3, steel)
		"light_tank", "mbt", "heavy_tank":
			_fill_rect(img, c - 11, c - 10, 22, 20, outline)
			_fill_rect(img, c - 10, c - 9, 20, 4, Color(0.18, 0.2, 0.22, 1))
			_fill_rect(img, c - 10, c + 5, 20, 4, Color(0.18, 0.2, 0.22, 1))
			_fill_rect(img, c - 8, c - 6, 16, 12, dark)
			_fill_rect(img, c - 6, c - 5, 12, 10, mid)
			_fill_rect(img, c - 5, c - 4, 3, 8, accent)
			_fill_circle(img, c - recoil, c, 5, bright)
			_fill_rect(img, c + 2 - recoil, c - 2, 11, 4, steel)
		"artillery":
			_fill_rect(img, c - 10, c - 7, 20, 14, outline)
			_fill_rect(img, c - 9, c - 6, 18, 12, dark)
			_fill_rect(img, c - 7, c - 4, 12, 8, mid)
			_fill_rect(img, c - 5, c - 3, 3, 6, accent)
			_fill_rect(img, c - 1 - recoil, c - 2, 15, 4, steel)
		"aa_vehicle":
			_fill_rect(img, c - 9, c - 7, 18, 14, outline)
			_fill_rect(img, c - 8, c - 6, 16, 12, dark)
			_fill_rect(img, c - 6, c - 4, 12, 8, mid)
			_fill_circle(img, c - 1, c, 4, accent)
			_fill_rect(img, c + 2 - recoil, c - 4, 10, 2, steel)
			_fill_rect(img, c + 2 - recoil, c + 2, 10, 2, steel)
		"patrol_boat", "corvette", "cruiser", "battleship", "aircraft_carrier", "landing_craft":
			_fill_rect(img, c - 12, c - 6, 24, 12, outline)
			_fill_rect(img, c - 11, c - 5, 22, 10, dark)
			_fill_rect(img, c - 8, c - 4, 16, 8, mid)
			_fill_rect(img, c - 5, c - 3, 3, 6, accent)
			_fill_rect(img, c - 1 - recoil, c - 2, 10, 4, steel)
			if state == AnimState.MOVE:
				_fill_rect(img, c - 14, c - 3 + leg_shift, 3, 6, Color(0.8, 0.95, 1.0, 0.85))
		"attack_sub", "ballistic_sub":
			_fill_rect(img, c - 11, c - 4, 22, 8, outline)
			_fill_rect(img, c - 10, c - 3, 20, 6, dark)
			_fill_rect(img, c - 6, c - 2, 13, 4, mid)
			_fill_rect(img, c - 1, c - 2, 4, 4, accent)
			_fill_rect(img, c + 4 - recoil, c - 1, 6, 2, steel)
		"hovercraft":
			_fill_rect(img, c - 11, c - 7, 22, 14, outline)
			_fill_rect(img, c - 10, c - 6, 20, 12, dark)
			_fill_rect(img, c - 8, c - 4, 16, 8, mid)
			_fill_rect(img, c - 3, c - 3, 4, 6, accent)
			_fill_rect(img, c - 12, c + 4, 24, 3, Color(0.6, 0.9, 1.0, 0.7))
		"frogman":
			_fill_rect(img, c - 4, c - 8, 8, 16, outline)
			_fill_rect(img, c - 3, c - 7, 6, 14, dark)
			_fill_circle(img, c, c - 2, 4, mid)
			_fill_rect(img, c - 1, c - 3, 3, 3, accent)
			_fill_rect(img, c - 1, c + 4, 2, 4, Color(0.2, 0.6, 0.9, 1))
		"scout_drone", "fighter_drone", "bomber_drone", "awacs":
			_fill_rect(img, c - 4, c - 12, 8, 24, outline)
			_fill_rect(img, c - 10, c - 4, 20, 8, outline)
			_fill_rect(img, c - 3, c - 11, 6, 22, dark)
			_fill_rect(img, c - 9, c - 3, 18, 6, mid)
			_fill_rect(img, c - 3, c - 11, 4, 3, accent)
			_fill_rect(img, c - 3, c + 8, 4, 3, accent)
			_fill_circle(img, c, c, 4, bright)
			_fill_rect(img, c + 3 - recoil, c - 1, 8, 2, steel)
		_:
			return false
	return true
