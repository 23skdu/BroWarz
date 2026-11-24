# scripts/core/unit_visual.gd
class_name UnitVisual
extends RefCounted

# Procedural sprite animation state machine and pixel/vector frame parameters
# for moving, firing, taking damage, and exploding across unit domains.

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
	# Returns procedural animation offsets for articulated unit rendering:
	# stride_phase (-1..1), recoil_px (0..6), muzzle_alpha (0..1),
	# rotor_angle (0..TAU), explosion_progress (0..1), bob_px (-2..2)
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

static func build_unit_frame_image(unit_class: int, state: int, frame: int, team_color: Color, size: int = 32, unit_id: String = "") -> Image:
	# Generates a crisp 32x32 RGBA pixel-art sprite frame for AnimatedSprite2D / ImageTexture.
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := size / 2
	var dark := team_color.darkened(0.45)
	var mid := team_color
	var bright := team_color.lightened(0.35)
	var steel := Color(0.72, 0.76, 0.82, 1.0)

	if state == AnimState.EXPLODE:
		var rad := int(lerpf(4.0, float(c - 2), float(frame + 1) / float(frame_count(state))))
		var fire_c := Color(1.0, 0.9, 0.3, 1.0).lerp(Color(0.9, 0.2, 0.05, 0.75), float(frame) / 7.0)
		_fill_circle(img, c, c, rad, fire_c)
		_fill_circle(img, c, c, maxi(2, rad / 2), Color(1.0, 0.98, 0.8, 1.0 - float(frame) * 0.1))
		return img

	var recoil := 2 if (state == AnimState.FIRE and frame < 2) else 0
	var leg_shift := ((frame % 2) * 2 - 1) * 2 if state == AnimState.MOVE else 0

	if unit_id != "" and _draw_unit_id(img, unit_id, state, frame, c, dark, mid, bright, steel, recoil, leg_shift):
		if state == AnimState.FIRE and frame < 2:
			_fill_circle(img, c + 13, c, 3, Color(1.0, 0.92, 0.35, 1.0))
		elif state == AnimState.HIT:
			_fill_circle(img, c, c, 7, Color(1.0, 1.0, 1.0, 0.65))
		return img

	match unit_class:
		1, 4, 7: # Vehicle / Tank / Mech / Hovercraft chassis with treads + turret
			_fill_rect(img, c - 10, c - 9, 20, 4, Color(0.18, 0.2, 0.22, 1.0))
			_fill_rect(img, c - 10, c + 5, 20, 4, Color(0.18, 0.2, 0.22, 1.0))
			_fill_rect(img, c - 8, c - 6, 16, 12, dark)
			_fill_rect(img, c - 6, c - 5, 12, 10, mid)
			_fill_circle(img, c - recoil, c, 5, bright)
			_fill_rect(img, c + 2 - recoil, c - 2, 10, 4, steel)
		2: # Naval hull + wake
			_fill_rect(img, c - 11, c - 5, 22, 10, dark)
			_fill_rect(img, c - 8, c - 4, 16, 8, mid)
			_fill_rect(img, c - 2 - recoil, c - 2, 10, 4, steel)
			if state == AnimState.MOVE:
				_fill_rect(img, c - 14, c - 3 + leg_shift, 3, 6, Color(0.8, 0.95, 1.0, 0.85))
		3: # Air drone / swept wings + rotor
			_fill_rect(img, c - 3, c - 11, 6, 22, dark)
			_fill_rect(img, c - 9, c - 3, 18, 6, mid)
			_fill_circle(img, c, c, 4, bright)
			_fill_rect(img, c + 3 - recoil, c - 1, 8, 2, steel)
		_: # Infantry robot (articulated shoulders, visor, rifle)
			_fill_rect(img, c - 4 + leg_shift, c - 7, 5, 4, Color(0.22, 0.25, 0.28, 1.0))
			_fill_rect(img, c - 4 - leg_shift, c + 3, 5, 4, Color(0.22, 0.25, 0.28, 1.0))
			_fill_rect(img, c - 5, c - 6, 10, 12, dark)
			_fill_circle(img, c, c, 5, mid)
			_fill_rect(img, c + 1, c - 2, 3, 4, Color(0.3, 0.95, 1.0, 1.0))
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
	img: Image, unit_id: String, state: int, frame: int, c: int,
	dark: Color, mid: Color, bright: Color, steel: Color,
	recoil: int, leg_shift: int
) -> bool:
	match unit_id:
		"riflebot":
			_fill_rect(img, c - 4 + leg_shift, c - 7, 5, 4, Color(0.22,0.25,0.28,1))
			_fill_rect(img, c - 4 - leg_shift, c + 3, 5, 4, Color(0.22,0.25,0.28,1))
			_fill_rect(img, c - 5, c - 6, 10, 12, dark)
			_fill_circle(img, c, c, 5, mid)
			_fill_rect(img, c + 1, c - 2, 3, 4, Color(0.3,0.95,1.0,1.0))
			_fill_rect(img, c + 2 - recoil, c + 1, 9, 3, steel)
		"heavybot":
			_fill_rect(img, c - 7, c - 8, 14, 16, dark)
			_fill_rect(img, c - 5, c - 6, 10, 12, mid)
			_fill_rect(img, c - 3, c - 3, 6, 6, bright)
			_fill_rect(img, c + 3 - recoil, c + 2, 8, 3, steel)
		"sapperbot":
			_fill_rect(img, c - 5, c - 6, 10, 12, dark)
			_fill_circle(img, c, c, 5, mid)
			_fill_rect(img, c - 9, c - 4, 4, 8, Color(0.9,0.7,0.2,1))
			_fill_rect(img, c + 2 - recoil, c + 1, 9, 3, steel)
		"stealthbot":
			_fill_rect(img, c - 3, c - 8, 6, 16, dark)
			_fill_circle(img, c, c, 4, mid)
			_fill_rect(img, c - 1, c - 3, 2, 6, Color(0.6,0.9,1.0,0.9))
		"sniperbot":
			_fill_rect(img, c - 4, c - 6, 8, 12, dark)
			_fill_circle(img, c, c - 2, 4, mid)
			_fill_rect(img, c + 2 - recoil, c - 1, 14, 2, steel)
		"rocketbot":
			_fill_rect(img, c - 5, c - 6, 10, 12, dark)
			_fill_circle(img, c, c, 5, mid)
			_fill_rect(img, c + 2 - recoil, c - 3, 10, 6, Color(0.8,0.3,0.2,1))
		"medicbot":
			_fill_rect(img, c - 5, c - 6, 10, 12, dark)
			_fill_circle(img, c, c, 5, mid)
			_fill_rect(img, c - 2, c - 4, 4, 8, Color(1,1,1,1))
			_fill_rect(img, c - 4, c - 2, 8, 4, Color(1,1,1,1))
		"engineerbot":
			_fill_rect(img, c - 5, c - 6, 10, 12, dark)
			_fill_circle(img, c, c, 5, mid)
			_fill_rect(img, c + 2 - recoil, c - 3, 8, 2, Color(0.9,0.8,0.3,1))
		"apc":
			_fill_rect(img, c - 9, c - 6, 18, 12, dark)
			_fill_rect(img, c - 7, c - 4, 14, 8, mid)
			_fill_rect(img, c - 10, c - 3, 3, 6, Color(0.18,0.2,0.22,1))
			_fill_rect(img, c + 7, c - 3, 3, 6, Color(0.18,0.2,0.22,1))
		"light_mech", "heavy_mech", "siege_mech":
			_fill_rect(img, c - 9, c - 9, 18, 6, Color(0.18,0.2,0.22,1))
			_fill_rect(img, c - 9, c + 3, 18, 6, Color(0.18,0.2,0.22,1))
			_fill_rect(img, c - 7, c - 6, 14, 12, dark)
			_fill_rect(img, c - 5, c - 5, 10, 10, mid)
			_fill_circle(img, c, c, 4, bright)
			_fill_rect(img, c + 2 - recoil, c - 2, 11, 4, steel)
		"light_tank", "mbt", "heavy_tank":
			_fill_rect(img, c - 10, c - 9, 20, 4, Color(0.18,0.2,0.22,1))
			_fill_rect(img, c - 10, c + 5, 20, 4, Color(0.18,0.2,0.22,1))
			_fill_rect(img, c - 8, c - 6, 16, 12, dark)
			_fill_rect(img, c - 6, c - 5, 12, 10, mid)
			_fill_circle(img, c - recoil, c, 5, bright)
			_fill_rect(img, c + 2 - recoil, c - 2, 10, 4, steel)
		"artillery":
			_fill_rect(img, c - 9, c - 4, 18, 8, dark)
			_fill_rect(img, c - 7, c - 3, 14, 6, mid)
			_fill_rect(img, c + 2 - recoil, c - 6, 12, 3, steel)
		"aa_vehicle":
			_fill_rect(img, c - 8, c - 6, 16, 12, dark)
			_fill_rect(img, c - 6, c - 4, 12, 8, mid)
			_fill_rect(img, c - 2, c - 10, 4, 6, steel)
			_fill_rect(img, c - 8, c - 8, 16, 3, Color(0.2,0.2,0.2,1))
		"patrol_boat", "corvette", "cruiser", "battleship", "aircraft_carrier", "landing_craft":
			_fill_rect(img, c - 11, c - 5, 22, 10, dark)
			_fill_rect(img, c - 8, c - 4, 16, 8, mid)
			_fill_rect(img, c - 2 - recoil, c - 2, 10, 4, steel)
			if state == AnimState.MOVE:
				_fill_rect(img, c - 14, c - 3 + leg_shift, 3, 6, Color(0.8,0.95,1.0,0.85))
		"attack_sub", "ballistic_sub":
			_fill_rect(img, c - 9, c - 3, 18, 6, dark)
			_fill_rect(img, c - 6, c - 2, 12, 4, mid)
			_fill_rect(img, c + 4 - recoil, c - 1, 6, 2, steel)
		"hovercraft":
			_fill_rect(img, c - 10, c - 6, 20, 12, dark)
			_fill_rect(img, c - 8, c - 4, 16, 8, mid)
			_fill_rect(img, c - 12, c + 4, 24, 3, Color(0.6,0.9,1.0,0.7))
		"frogman":
			_fill_rect(img, c - 3, c - 7, 6, 14, dark)
			_fill_circle(img, c, c - 2, 4, mid)
			_fill_rect(img, c - 1, c + 4, 2, 4, Color(0.2,0.6,0.9,1))
		"scout_drone", "fighter_drone", "bomber_drone", "awacs":
			_fill_rect(img, c - 3, c - 11, 6, 22, dark)
			_fill_rect(img, c - 9, c - 3, 18, 6, mid)
			_fill_circle(img, c, c, 4, bright)
			_fill_rect(img, c + 3 - recoil, c - 1, 8, 2, steel)
		_:
			return false
	return true
