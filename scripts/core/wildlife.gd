# scripts/core/wildlife.gd
class_name Wildlife
extends RefCounted

# Ambient non-combatant wildlife system:
# - DEER (forest/plains herbivore)
# - DOLPHIN (sea/river marine mammal)
# - SQUID (sea/river cephalopod)
# - BIRD (all maps, flies across terrain)
# Animals wander peacefully, flee rapidly when chased or shot at, and can die if hit.

enum Kind { DEER = 0, DOLPHIN = 1, SQUID = 2, BIRD = 3 }
enum Domain { LAND = 0, SEA = 1, AIR = 2 }

static func kind_name(kind: int) -> String:
	match kind:
		Kind.DEER: return "Deer"
		Kind.DOLPHIN: return "Dolphin"
		Kind.SQUID: return "Squid"
		Kind.BIRD: return "Bird"
		_: return "Critter"

static func domain_of(kind: int) -> int:
	match kind:
		Kind.DOLPHIN, Kind.SQUID:
			return Domain.SEA
		Kind.BIRD:
			return Domain.AIR
		_:
			return Domain.LAND

static func max_hp(kind: int) -> int:
	match kind:
		Kind.DEER: return 22
		Kind.DOLPHIN: return 26
		Kind.SQUID: return 20
		Kind.BIRD: return 12
		_: return 15

static func wander_speed(kind: int) -> float:
	match kind:
		Kind.DEER: return 34.0
		Kind.DOLPHIN: return 48.0
		Kind.SQUID: return 36.0
		Kind.BIRD: return 68.0
		_: return 35.0

static func flee_speed(kind: int) -> float:
	return wander_speed(kind) * 2.15

static func is_valid_terrain(kind: int, terrain: int) -> bool:
	match domain_of(kind):
		Domain.AIR:
			return true
		Domain.SEA:
			return terrain == MapData.Terrain.SEA or terrain == MapData.Terrain.RIVER
		_:
			return terrain == MapData.Terrain.PLAINS or terrain == MapData.Terrain.FOREST or terrain == MapData.Terrain.SWAMP

static func create_critter(id: int, kind: int, pos: Vector2, seed_val: int = 1) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val + id * 97
	var angle := rng.randf_range(0.0, TAU)
	return {
		"id": id,
		"kind": kind,
		"pos": pos,
		"vel": Vector2(cos(angle), sin(angle)) * wander_speed(kind),
		"hp": max_hp(kind),
		"max_hp": max_hp(kind),
		"alive": true,
		"flee_timer": 0.0,
		"death_timer": 0.0,
		"anim_phase": rng.randf_range(0.0, TAU),
		"wander_timer": rng.randf_range(2.5, 6.0),
	}

static func spawn_ambient_herd(map: MapData, seed_val: int = 1337, max_total: int = 12) -> Array[Dictionary]:
	# Spawns a small, occasional, non-intrusive set of wildlife appropriate to the map's biomes.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var herd: Array[Dictionary] = []
	var sea_tiles: Array[Vector2i] = []
	var land_tiles: Array[Vector2i] = []

	for y in range(4, map.height - 4, 4):
		for x in range(4, map.width - 4, 4):
			var t := map.get_terrain(x, y)
			if t == MapData.Terrain.SEA or t == MapData.Terrain.RIVER:
				sea_tiles.append(Vector2i(x, y))
			elif t == MapData.Terrain.FOREST or t == MapData.Terrain.PLAINS:
				land_tiles.append(Vector2i(x, y))

	var next_id := 1
	# Occasional birds on all maps (3-4 birds)
	var bird_count := mini(4, maxi(2, max_total / 3))
	for i in range(bird_count):
		var bx := rng.randf_range(160.0, float(map.width * 16 - 160))
		var by := rng.randf_range(160.0, float(map.height * 16 - 160))
		herd.append(create_critter(next_id, Kind.BIRD, Vector2(bx, by), seed_val + i))
		next_id += 1

	# Dolphins & Squid on maps with naval water tiles
	if not sea_tiles.is_empty():
		var marine_count := mini(4, sea_tiles.size())
		for i in range(marine_count):
			if herd.size() >= max_total:
				break
			var st := sea_tiles[rng.randi_range(0, sea_tiles.size() - 1)]
			var kind := Kind.DOLPHIN if (i % 2 == 0) else Kind.SQUID
			var wpos := Vector2(float(st.x * 16 + 8), float(st.y * 16 + 8))
			herd.append(create_critter(next_id, kind, wpos, seed_val + 100 + i))
			next_id += 1

	# Forest/Plains fauna (Deer)
	if not land_tiles.is_empty():
		while herd.size() < max_total:
			var lt := land_tiles[rng.randi_range(0, land_tiles.size() - 1)]
			var wpos := Vector2(float(lt.x * 16 + 8), float(lt.y * 16 + 8))
			herd.append(create_critter(next_id, Kind.DEER, wpos, seed_val + 200 + next_id))
			next_id += 1

	return herd

static func compute_flee_vector(critter_pos: Vector2, threat_positions: Array, detect_radius: float = 115.0) -> Vector2:
	var away := Vector2.ZERO
	var r2 := detect_radius * detect_radius
	for tp in threat_positions:
		if tp is Vector2:
			var diff: Vector2 = critter_pos - tp
			var d2 := diff.length_squared()
			if d2 > 0.001 and d2 <= r2:
				away += diff.normalized() * (1.0 - sqrt(d2) / detect_radius)
	if away.length_squared() > 0.0001:
		return away.normalized()
	return Vector2.ZERO

static func apply_damage(critter: Dictionary, amount: float, attacker_pos: Vector2 = Vector2.ZERO) -> bool:
	# Returns true if the critter died from this hit.
	if not bool(critter.get("alive", true)):
		return false
	var hp_after := int(critter.get("hp", 10)) - int(maxf(1.0, round(amount)))
	critter["hp"] = hp_after
	if hp_after <= 0:
		critter["hp"] = 0
		critter["alive"] = false
		critter["vel"] = Vector2.ZERO
		critter["death_timer"] = 1.2
		return true
	# Survives: panic and flee away from attacker
	critter["flee_timer"] = 3.2
	var kind := int(critter.get("kind", Kind.DEER))
	var pos: Vector2 = critter.get("pos", Vector2.ZERO)
	var flee_dir := (pos - attacker_pos).normalized()
	if flee_dir.length_squared() < 0.01:
		flee_dir = Vector2.RIGHT
	critter["vel"] = flee_dir * flee_speed(kind)
	return false

static func step_critter(critter: Dictionary, map: MapData, threat_positions: Array, delta: float, rng_seed: int = 1) -> void:
	if not bool(critter.get("alive", true)):
		critter["death_timer"] = maxf(0.0, float(critter.get("death_timer", 0.0)) - delta)
		return

	var kind := int(critter.get("kind", Kind.DEER))
	var pos: Vector2 = critter.get("pos", Vector2.ZERO)
	critter["anim_phase"] = fmod(float(critter.get("anim_phase", 0.0)) + delta * 9.0, TAU)
	var flee_t := maxf(0.0, float(critter.get("flee_timer", 0.0)) - delta)

	# Check nearby units/weapons for chase or gunfire threats
	var flee_vec := compute_flee_vector(pos, threat_positions, 120.0)
	if flee_vec != Vector2.ZERO:
		flee_t = maxf(flee_t, 2.2)
		critter["vel"] = flee_vec * flee_speed(kind)
	elif flee_t <= 0.0:
		var wt := float(critter.get("wander_timer", 2.0)) - delta
		if wt <= 0.0:
			var rng := RandomNumberGenerator.new()
			rng.seed = rng_seed + int(critter.get("id", 1)) * 131 + int(pos.x + pos.y)
			var ang := rng.randf_range(0.0, TAU)
			critter["vel"] = Vector2(cos(ang), sin(ang)) * wander_speed(kind)
			wt = rng.randf_range(3.0, 6.5)
		else:
			# Normalize to wander speed after fleeing subsides
			var cur_v: Vector2 = critter.get("vel", Vector2.RIGHT)
			if cur_v.length_squared() > 0.01:
				critter["vel"] = cur_v.normalized() * wander_speed(kind)
		critter["wander_timer"] = wt

	critter["flee_timer"] = flee_t
	var next_pos: Vector2 = pos + Vector2(critter.get("vel", Vector2.ZERO)) * delta
	var max_w := float(map.width * 16 - 24)
	var max_h := float(map.height * 16 - 24)

	# Keep inside map bounds and valid biome terrain
	var tx := clampi(int(next_pos.x / 16.0), 0, map.width - 1)
	var ty := clampi(int(next_pos.y / 16.0), 0, map.height - 1)
	var next_terrain := map.get_terrain(tx, ty)
	if next_pos.x < 24.0 or next_pos.y < 24.0 or next_pos.x > max_w or next_pos.y > max_h or not is_valid_terrain(kind, next_terrain):
		critter["vel"] = -Vector2(critter.get("vel", Vector2.RIGHT))
		next_pos = pos.clamp(Vector2(24.0, 24.0), Vector2(max_w, max_h))
	critter["pos"] = next_pos
