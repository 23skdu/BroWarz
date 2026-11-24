# scripts/core/cover.gd
class_name Cover
extends RefCounted

# Per-terrain combat defense (incoming damage multiplier) and attack (outgoing damage multiplier)
# rules by unit class, plus drifting cloud weather system that exclusively affects aerial units (unit_class == 3).

static func modifier(terrain: int) -> float:
	match terrain:
		MapData.Terrain.MOUNTAIN: return 0.65
		MapData.Terrain.URBAN: return 0.70
		MapData.Terrain.FOREST: return 0.80
		MapData.Terrain.HILLS: return 0.85
		MapData.Terrain.BRIDGE: return 0.92
		MapData.Terrain.RIVER: return 0.95
		MapData.Terrain.SEA: return 1.00
		MapData.Terrain.PLAINS: return 1.00
		MapData.Terrain.ROAD: return 1.05
		MapData.Terrain.DESERT: return 1.08
		MapData.Terrain.SWAMP: return 1.10
		MapData.Terrain.WASTELAND: return 1.15
		_: return 1.00

static func provides_cover(terrain: int) -> bool:
	return modifier(terrain) < 1.0

static func defense_modifier_for_unit(terrain: int, unit_class: int, in_cloud: bool = false) -> float:
	# Air units (unit_class == 3) are NEVER affected by ground terrain; only clouds affect them!
	if unit_class == 3:
		return cloud_air_defense_modifier(in_cloud)
	match terrain:
		MapData.Terrain.URBAN:
			# Infantry/frogbots use buildings for deep cover (0.65x); vehicles/mechs are cramped in streets (0.85x)
			if unit_class in [0, 5, 6]:
				return 0.65
			return 0.85
		MapData.Terrain.FOREST:
			# Infantry conceal in woods (0.75x); vehicles slowed with moderate cover (0.90x)
			if unit_class in [0, 5, 6]:
				return 0.75
			return 0.90
		MapData.Terrain.HILLS:
			# High ground hull-down protection for both infantry and armor
			return 0.82 if unit_class in [0, 6] else 0.85
		MapData.Terrain.MOUNTAIN:
			# Heavy infantry (6) and heavy/siege mechs (7) gain fortified ridge cover
			return 0.65 if unit_class == 6 else 0.72
		MapData.Terrain.SWAMP:
			# Bogged ground exposes infantry/mechs (1.12x), whereas amphibious frogbots/hovercraft thrive (0.90x)
			if unit_class in [4, 5]:
				return 0.90
			return 1.12
		MapData.Terrain.RIVER:
			# Confined river channel: frogbots submerge (0.80x), surface boats slightly exposed (1.05x)
			if unit_class == 5:
				return 0.80
			return 1.05
		MapData.Terrain.SEA:
			# Open ocean: frogbots/subsurface gain wave concealment (0.82x), naval hulls normal (0.95x)
			if unit_class == 5:
				return 0.82
			return 0.95
		MapData.Terrain.DESERT:
			# Open dunes expose infantry (1.10x); tracked armor/hovercraft operate cleanly (1.02x)
			return 1.10 if unit_class in [0, 6] else 1.02
		MapData.Terrain.ROAD:
			# Open paved highway leaves units exposed for speed
			return 1.08
		MapData.Terrain.BRIDGE:
			# Reinforced bridge girders provide slight side shielding
			return 0.92
		MapData.Terrain.WASTELAND:
			# Radioactive fallout corrodes armor and sensors (+15% damage taken)
			return 1.15
		_: # PLAINS
			return 1.00

static func attack_modifier_for_unit(terrain: int, unit_class: int, in_cloud: bool = false) -> float:
	# Outgoing weapon effectiveness multiplier based on shooter's terrain (or cloud for air units).
	# Air units (unit_class == 3) ignore ground terrain and are only modified by clouds!
	if unit_class == 3:
		return cloud_air_attack_modifier(in_cloud)
	match terrain:
		MapData.Terrain.HILLS:
			return 1.12  # High-ground firing advantage
		MapData.Terrain.MOUNTAIN:
			return 1.18  # Commanding elevation bonus for Heavybots & Heavy/Siege Mechs
		MapData.Terrain.URBAN:
			return 1.08 if unit_class in [0, 5, 6] else 0.92
		MapData.Terrain.FOREST:
			return 1.05 if unit_class in [0, 5, 6] else 0.90
		MapData.Terrain.ROAD, MapData.Terrain.BRIDGE:
			return 1.05 if unit_class in [1, 4, 7] else 1.00
		MapData.Terrain.PLAINS:
			return 1.05 if unit_class in [1, 7] else 1.00
		MapData.Terrain.DESERT:
			return 1.05 if unit_class in [1, 4, 7] else 0.95
		MapData.Terrain.SWAMP:
			return 1.05 if unit_class in [4, 5] else 0.88
		MapData.Terrain.RIVER:
			return 1.10 if unit_class == 5 else 0.96
		MapData.Terrain.SEA:
			return 1.10 if unit_class in [2, 5] else 1.00
		MapData.Terrain.WASTELAND:
			return 0.90  # Sensor interference in nuclear fallout
		_:
			return 1.00

# --- Drifting Cloud System (Exclusively affects Air Units: unit_class == 3) ---

static func cloud_air_speed_multiplier(in_cloud: bool) -> float:
	# Headwinds and turbulence inside a cloud bank slow aerial drones by 22%
	return 0.78 if in_cloud else 1.00

static func cloud_air_defense_modifier(in_cloud: bool) -> float:
	# Cloud cover conceals aerial drones from anti-air targeting (-25% incoming damage)
	return 0.75 if in_cloud else 1.00

static func cloud_air_attack_modifier(in_cloud: bool) -> float:
	# Cloud cover obscures optical/laser targeting pods (-15% outgoing weapon damage)
	return 0.85 if in_cloud else 1.00

static func spawn_clouds(map_width_px: float, map_height_px: float, rng_seed: int, count: int = 8) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed ^ 0x5A17C3
	var clouds: Array[Dictionary] = []
	var w := maxf(256.0, map_width_px)
	var h := maxf(256.0, map_height_px)
	for i in range(maxi(1, count)):
		var angle := rng.randf_range(-0.35, 0.35)
		var spd := rng.randf_range(18.0, 36.0)
		clouds.append({
			"id": i + 1,
			"pos": Vector2(rng.randf_range(0.0, w), rng.randf_range(0.0, h)),
			"vel": Vector2(cos(angle), sin(angle)) * spd,
			"radius": rng.randf_range(72.0, 128.0),
			"alpha": rng.randf_range(0.26, 0.42),
			"seed": rng.randi(),
		})
	return clouds

static func step_clouds(clouds: Array, map_width_px: float, map_height_px: float, delta: float) -> void:
	var w := maxf(256.0, map_width_px)
	var h := maxf(256.0, map_height_px)
	for c in clouds:
		var pos: Vector2 = c["pos"] + c["vel"] * delta
		var rad := float(c.get("radius", 90.0))
		if pos.x - rad > w:
			pos.x = -rad
		elif pos.x + rad < 0.0:
			pos.x = w + rad
		if pos.y - rad > h:
			pos.y = -rad
		elif pos.y + rad < 0.0:
			pos.y = h + rad
		c["pos"] = pos

static func is_point_in_cloud(clouds: Array, world_pos: Vector2) -> bool:
	for c in clouds:
		var cpos: Vector2 = c["pos"]
		var rad := float(c.get("radius", 90.0))
		if world_pos.distance_squared_to(cpos) <= rad * rad:
			return true
	return false
