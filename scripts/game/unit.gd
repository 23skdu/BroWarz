# scripts/game/unit.gd
extends CharacterBody2D

var stats: UnitStats
var team: int = 0
var hp: int = 100
var selected: bool = false
var faction: int = -1
var net_id: int = 0
var target_pos: Vector2 = Vector2.ZERO
var has_target: bool = false
var eel_timer: float = 0.0
var hex_grid: HexGrid = HexGrid.new(16.0)
var hex_path: Array[Vector2] = []
var path_index: int = 0
var attack_move: bool = false
var hold_position: bool = false
var attack_timer: float = 0.0
var attack_cooldown: float = 0.8
var emp_timer: float = 0.0
var cloak_timer: float = 0.0
var focus_target: Node2D = null
var cargo: Array = []  # Array of Unit nodes currently embarked inside this transport
var embarked_in: Node2D = null

# Animation & visual combat state
var anim_state: int = UnitVisual.AnimState.IDLE
var anim_elapsed: float = 0.0
var fire_anim_timer: float = 0.0
var hit_flash_timer: float = 0.0
var is_exploding: bool = false
var explode_timer: float = 0.0
var facing_angle: float = 0.0
var turret_angle: float = 0.0
var last_target_world_pos: Vector2 = Vector2.ZERO
var explosion_debris: Array[Dictionary] = []
var sprite_node: Sprite2D = null
var _frame_cache: Dictionary = {}  # "state:frame" -> ImageTexture

@onready var body = $Body
@onready var hp_bar = $HpBar

func _ready():
	if stats:
		hp = effective_max_hp()
		if stats.stealth:
			cloak_timer = effective_cloak_duration()
	target_pos = global_position
	facing_angle = 0.0 if team == 0 else PI
	turret_angle = facing_angle
	if body:
		body.visible = false
	_setup_animated_sprite()
	add_to_group("units")
	if net_id == 0:
		net_id = GameManager.next_net_id()

func setup(s: UnitStats, t: int, f: int = -1) -> void:
	stats = s
	team = t
	faction = f if f >= 0 else (GameManager.player_faction if t == 0 else GameManager.ai_faction)
	hp = effective_max_hp()
	facing_angle = 0.0 if t == 0 else PI
	turret_angle = facing_angle
	if s.stealth:
		cloak_timer = effective_cloak_duration()
	_frame_cache.clear()
	_update_visual()

func effective_max_hp() -> int:
	if stats == null:
		return 100
	var fac_id := faction if faction >= 0 else (GameManager.player_faction if team == 0 else GameManager.ai_faction)
	return Faction.effective_max_hp(fac_id, stats.id, stats.hp)

func effective_speed() -> float:
	if stats == null:
		return 100.0
	var fac_id := faction if faction >= 0 else (GameManager.player_faction if team == 0 else GameManager.ai_faction)
	return Faction.effective_speed(fac_id, stats.id, stats.speed)

func effective_cloak_duration() -> float:
	var fac_id := faction if faction >= 0 else (GameManager.player_faction if team == 0 else GameManager.ai_faction)
	return Faction.effective_cloak_duration(fac_id, 10.0)

func _setup_animated_sprite() -> void:
	if sprite_node != null:
		return
	sprite_node = Sprite2D.new()
	sprite_node.name = "AnimatedUnitSprite"
	sprite_node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite_node)
	_refresh_sprite_texture()

func _team_base_color() -> Color:
	var fac_id := faction if faction >= 0 else (GameManager.player_faction if team == 0 else GameManager.ai_faction)
	return Faction.color_of(fac_id)

func _refresh_sprite_texture() -> void:
	if sprite_node == null:
		return
	var f_idx := UnitVisual.frame_index(anim_state, anim_elapsed, anim_state != UnitVisual.AnimState.EXPLODE)
	var uid := stats.id if stats else ""
	var uclass := stats.unit_class if stats else 0
	sprite_node.texture = UnitVisual.get_cached_unit_texture(uclass, anim_state, f_idx, _team_base_color(), UnitVisual.DEFAULT_SPRITE_SIZE, uid)
	sprite_node.rotation = 0.0 if is_exploding else facing_angle
	var alpha := 0.42 if is_cloaked() else 1.0
	sprite_node.modulate = Color(1, 1, 1, alpha)

func _update_visual() -> void:
	if body:
		body.visible = false
	_refresh_sprite_texture()

func is_cloaked() -> bool:
	return not is_exploding and stats != null and stats.stealth and Stealth.is_cloaked(cloak_timer)

func apply_emp(duration: float) -> void:
	if is_exploding:
		return
	var ac := stats.armor_class if stats else 0
	emp_timer = maxf(emp_timer, EMP.disable_duration(duration, ac))

func transport_capacity() -> int:
	return UnitRegistry.transport_capacity(stats.id) if stats else 0

func can_load_passenger(unit: Node2D) -> bool:
	if unit == null or unit == self or not is_instance_valid(unit) or is_exploding:
		return false
	if unit.team != team or ("is_exploding" in unit and unit.is_exploding):
		return false
	if "embarked_in" in unit and unit.embarked_in != null:
		return false
	var cap := transport_capacity()
	if cap <= 0 or cargo.size() >= cap:
		return false
	var p_stats: UnitStats = unit.stats if "stats" in unit else null
	if p_stats == null:
		return false
	return UnitRegistry.can_embark(stats.id, p_stats.id, p_stats.unit_class)

func embark_passenger(unit: Node2D) -> bool:
	if not can_load_passenger(unit):
		return false
	cargo.append(unit)
	unit.embarked_in = self
	unit.selected = false
	unit.stop_command()
	unit.visible = false
	unit.set_physics_process(false)
	unit.remove_from_group("units")
	return true

func disembark_all(drop_origin: Vector2 = Vector2.INF) -> int:
	if cargo.is_empty():
		return 0
	var base_pos := global_position if drop_origin == Vector2.INF else drop_origin
	var offsets := Formation.grid_offsets(cargo.size(), 22.0)
	var unloaded := 0
	for i in range(cargo.size()):
		var p = cargo[i]
		if not is_instance_valid(p):
			continue
		p.embarked_in = null
		var drop_pos := base_pos + offsets[i] + Vector2(20.0, 0.0)
		if GameManager.current_map != null and p.stats:
			var tx := clampi(int(drop_pos.x / 16.0), 0, GameManager.current_map.width - 1)
			var ty := clampi(int(drop_pos.y / 16.0), 0, GameManager.current_map.height - 1)
			var heavy: bool = p.stats.unit_class in [6, 7]
			if not MapData.is_passable(GameManager.current_map.get_terrain(tx, ty), p.stats.unit_class, heavy):
				# Find nearest passable shoreline/land tile within 4 tiles
				for r in range(1, 5):
					var found := false
					for dy in range(-r, r + 1):
						for dx in range(-r, r + 1):
							if GameManager.current_map.in_bounds(tx + dx, ty + dy):
								var tt := GameManager.current_map.get_terrain(tx + dx, ty + dy)
								if MapData.is_passable(tt, p.stats.unit_class, heavy):
									drop_pos = Vector2(float(tx + dx) * 16.0 + 8.0, float(ty + dy) * 16.0 + 8.0)
									found = true
									break
						if found:
							break
					if found:
						break
		p.global_position = drop_pos
		p.visible = true
		p.set_physics_process(true)
		p.add_to_group("units")
		unloaded += 1
	cargo.clear()
	return unloaded

func _physics_process(delta):
	anim_elapsed += delta
	fire_anim_timer = maxf(0.0, fire_anim_timer - delta)
	hit_flash_timer = maxf(0.0, hit_flash_timer - delta)

	if is_exploding:
		explode_timer += delta
		anim_state = UnitVisual.AnimState.EXPLODE
		_refresh_sprite_texture()
		queue_redraw()
		if explode_timer >= UnitVisual.explosion_duration():
			queue_free()
		return

	emp_timer = EMP.tick(emp_timer, delta)
	if EMP.is_disabled(emp_timer):
		velocity = Vector2.ZERO
		anim_state = UnitVisual.AnimState.IDLE
		_refresh_sprite_texture()
		queue_redraw()
		return

	attack_timer -= delta
	# Hovercraft eel hazard
	if stats and stats.id == "hovercraft":
		eel_timer = maxf(0.0, eel_timer - delta)
		if eel_timer > 0.0:
			velocity = Vector2.ZERO
			anim_state = UnitVisual.AnimState.IDLE
			_refresh_sprite_texture()
			queue_redraw()
			return
	if stats and stats.stealth and not has_target and attack_timer <= 0.0:
		cloak_timer = minf(cloak_timer + delta, effective_cloak_duration())

	# Sapperbot is the unified worker: auto-repair nearby friendly units/structures.
	if stats and stats.id == "sapperbot":
		_auto_repair_allies(delta)
	if stats and stats.id == "sapperbot":
		_try_capture_enemy_building()
	if stats and stats.id == "aircraft_carrier" and not cargo.is_empty():
		_repair_carrier_drones(delta)

	if has_target:
		if attack_move:
			var enemy = _nearest_enemy_in_range()
			if enemy != null:
				velocity = Vector2.ZERO
				_perform_attack(enemy)
				_update_anim_state()
				queue_redraw()
				return
		if path_index < hex_path.size():
			target_pos = hex_path[path_index]
		var dir = (target_pos - global_position)
		if dir.length() > 4.0:
			var spd := effective_speed()
			var terrain_mult := _terrain_speed_multiplier()
			velocity = dir.normalized() * spd * terrain_mult
			facing_angle = lerp_angle(facing_angle, velocity.angle(), minf(1.0, delta * 14.0))
			if fire_anim_timer <= 0.0:
				turret_angle = lerp_angle(turret_angle, facing_angle, minf(1.0, delta * 10.0))
			move_and_slide()
		else:
			path_index += 1
			if path_index >= hex_path.size():
				has_target = false
				attack_move = false
				velocity = Vector2.ZERO
				hex_path.clear()
			else:
				target_pos = hex_path[path_index]
	else:
		velocity = Vector2.ZERO
		_try_attack()

	_update_anim_state()
	_update_visual()
	queue_redraw()

func _update_anim_state() -> void:
	var next_state := UnitVisual.select_state(is_exploding, fire_anim_timer, hit_flash_timer, velocity.length_squared())
	if next_state != anim_state:
		anim_state = next_state
		anim_elapsed = 0.0

func is_in_cloud() -> bool:
	return stats != null and stats.unit_class == 3 and GameManager.is_in_cloud(global_position)

func _terrain_speed_multiplier() -> float:
	if stats == null:
		return 1.0
	if stats.unit_class == 3:
		return MapData.speed_multiplier(MapData.Terrain.PLAINS, 3, false, is_in_cloud())
	if GameManager.current_map == null:
		return 1.0
	var tx := clampi(int(global_position.x / 16.0), 0, GameManager.current_map.width - 1)
	var ty := clampi(int(global_position.y / 16.0), 0, GameManager.current_map.height - 1)
	var t := GameManager.current_map.get_terrain(tx, ty)
	var heavy := stats.unit_class == 6 or stats.unit_class == 7
	return MapData.speed_multiplier(t, stats.unit_class, heavy, false)

func _auto_repair_allies(delta: float) -> void:
	var rate := 18.0 if (stats and stats.id == "sapperbot") else 12.0
	for u in get_tree().get_nodes_in_group("units"):
		if u == self or not is_instance_valid(u) or u.team != team or u.is_exploding:
			continue
		var max_hp: int = u.effective_max_hp() if u.has_method("effective_max_hp") else (u.stats.hp if u.stats else 100)
		if u.stats and Repair.can_repair(u.hp, max_hp):
			if global_position.distance_to(u.global_position) <= 100.0:
				var amt := int(ceil(Repair.repair_amount(rate, delta)))
				u.hp = mini(max_hp, u.hp + amt)
				if u.hp_bar:
					u.hp_bar.value = float(u.hp) / float(max_hp) * 100.0
				return
	if stats and stats.can_build:
		for b in get_tree().get_nodes_in_group("buildings"):
			if not is_instance_valid(b) or b.team != team or ("is_exploding" in b and b.is_exploding):
				continue
			if b.stats and Repair.can_repair(b.hp, b.stats.hp) and global_position.distance_to(b.global_position) <= 110.0:
				var b_amt := int(ceil(Repair.repair_amount(rate, delta)))
				b.hp = mini(b.stats.hp, b.hp + b_amt)
				if b.hp_bar:
					b.hp_bar.value = float(b.hp) / float(b.stats.hp) * 100.0
				return

func _try_capture_enemy_building() -> void:
	for b in get_tree().get_nodes_in_group("buildings"):
		if not is_instance_valid(b) or b.team == team or ("is_exploding" in b and b.is_exploding):
			continue
		if b.stats and b.hp <= int(float(b.stats.hp) * 0.5) and global_position.distance_to(b.global_position) <= 44.0:
			b.team = team
			if "body" in b and b.body:
				var fac := GameManager.player_faction if team == 0 else GameManager.ai_faction
				b.body.color = Faction.color_of(fac).darkened(0.12)
			AudioManager.play_sfx("tech_up")
			return

func _repair_carrier_drones(delta: float) -> void:
	for p in cargo:
		if is_instance_valid(p) and p.stats and Repair.can_repair(p.hp, p.stats.hp):
			var amt := int(ceil(Repair.repair_amount(15.0, delta)))
			p.hp = mini(p.stats.hp, p.hp + amt)

func _try_attack():
	if attack_timer > 0:
		return
	var enemy = focus_target if (is_instance_valid(focus_target) and not ("is_exploding" in focus_target and focus_target.is_exploding)) else _nearest_enemy()
	if enemy == null:
		return
	var rng := stats.range_px if stats else 200.0
	var dist := global_position.distance_to(enemy.global_position)
	if dist <= rng:
		_perform_attack(enemy)
	elif not hold_position and dist <= (stats.sight if stats else 300.0):
		target_pos = enemy.global_position
		has_target = true
		attack_move = true

func _perform_attack(enemy: Node2D) -> void:
	attack_timer = attack_cooldown
	fire_anim_timer = 0.26
	anim_state = UnitVisual.AnimState.FIRE
	anim_elapsed = 0.0
	last_target_world_pos = enemy.global_position
	var aim_dir := (enemy.global_position - global_position)
	if aim_dir.length_squared() > 0.01:
		turret_angle = aim_dir.angle()
		if stats == null or stats.unit_class != 1:
			facing_angle = turret_angle

	if stats and stats.stealth and Stealth.break_on_action(true, false, false):
		cloak_timer = 0.0
	var base_dmg := float(stats.base_damage if stats else 10)
	var dmg_type: int = stats.damage_type if stats else Damage.DamageType.KINETIC
	var target_armor: int = Damage.ArmorClass.LIGHT
	if "stats" in enemy and enemy.stats != null:
		if "armor_class" in enemy.stats:
			target_armor = enemy.stats.armor_class
		else:
			target_armor = Damage.ArmorClass.STRUCTURE
	var cover_mod := 1.0
	var atk_mod := 1.0
	var attacker_class := stats.unit_class if stats else 0
	var attacker_in_cloud := is_in_cloud()
	var target_class := 0
	var target_in_cloud := false
	if "stats" in enemy and enemy.stats != null and "unit_class" in enemy.stats:
		target_class = enemy.stats.unit_class
		if target_class == 3:
			target_in_cloud = GameManager.is_in_cloud(enemy.global_position)
	if GameManager.current_map != null:
		var ax := clampi(int(global_position.x / 16.0), 0, GameManager.current_map.width - 1)
		var ay := clampi(int(global_position.y / 16.0), 0, GameManager.current_map.height - 1)
		var tx := clampi(int(enemy.global_position.x / 16.0), 0, GameManager.current_map.width - 1)
		var ty := clampi(int(enemy.global_position.y / 16.0), 0, GameManager.current_map.height - 1)
		atk_mod = Cover.attack_modifier_for_unit(GameManager.current_map.get_terrain(ax, ay), attacker_class, attacker_in_cloud)
		cover_mod = Cover.defense_modifier_for_unit(GameManager.current_map.get_terrain(tx, ty), target_class, target_in_cloud)
	elif attacker_class == 3 or target_class == 3:
		atk_mod = Cover.attack_modifier_for_unit(MapData.Terrain.PLAINS, attacker_class, attacker_in_cloud)
		cover_mod = Cover.defense_modifier_for_unit(MapData.Terrain.PLAINS, target_class, target_in_cloud)
	var uid := stats.id if stats else ""
	var final_dmg := Damage.compute_for_unit(uid, base_dmg * atk_mod, dmg_type, target_armor, 0.0, cover_mod)

	# Spawn projectile tracer & muzzle flash in active game scene
	var scene = get_tree().current_scene
	if scene and scene.has_method("spawn_combat_tracer"):
		var muzzle_pos := global_position + Vector2.RIGHT.rotated(turret_angle) * 14.0
		scene.spawn_combat_tracer(muzzle_pos, enemy.global_position, dmg_type, team)

	enemy.take_damage(final_dmg)
	if dmg_type == Damage.DamageType.EMP and enemy.has_method("apply_emp"):
		enemy.apply_emp(2.5)
	AudioManager.play_sfx("weapon_fire")

func _nearest_enemy_in_range() -> Node2D:
	var e = _nearest_enemy()
	if e != null and global_position.distance_to(e.global_position) <= (stats.range_px if stats else 200.0):
		return e
	return null

func _nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_d := INF
	var sgt := stats.sight if stats else 300.0
	var uid := stats.id if stats else ""
	var has_radar := uid == "awacs" or uid == "scout_drone"
	var has_sonar := Vision.is_sonar_unit(uid)
	for u in get_tree().get_nodes_in_group("units"):
		if u == self or not is_instance_valid(u) or u.team == team:
			continue
		if "is_exploding" in u and u.is_exploding:
			continue
		if GameManager.is_allied(team, u.team):
			continue
		var d := global_position.distance_to(u.global_position)
		if u.stats and u.stats.armor_class == Damage.ArmorClass.SUBMERGED:
			if not Vision.sub_detected(sgt, d, has_sonar):
				continue
		if u.has_method("is_cloaked") and u.is_cloaked():
			if not Vision.stealth_detected(sgt, d, true, has_radar):
				continue
		if d < best_d:
			best_d = d
			best = u
	for b in get_tree().get_nodes_in_group("buildings"):
		if not is_instance_valid(b) or GameManager.is_allied(team, b.team):
			continue
		if "is_exploding" in b and b.is_exploding:
			continue
		var d := global_position.distance_to(b.global_position)
		if d < best_d:
			best_d = d
			best = b
	return best

func move_to(pos: Vector2, is_attack_move: bool = false) -> void:
	if is_exploding:
		return
	has_target = true
	attack_move = is_attack_move
	hold_position = false
	var goal := _goal_avoiding_fortifications(pos)
	_build_hex_path(goal)
	if hex_path.size() > 0:
		path_index = 0
		target_pos = hex_path[0]
	else:
		target_pos = hex_grid.hex_to_world(hex_grid.world_to_hex(goal))

## Walls and barbed wire stop ground units: nudge the order onto the
## nearest tile the unit can actually stand on.
func _goal_avoiding_fortifications(pos: Vector2) -> Vector2:
	if GameManager.current_map == null or stats == null:
		return pos
	var tx := clampi(int(pos.x / 16.0), 0, GameManager.current_map.width - 1)
	var ty := clampi(int(pos.y / 16.0), 0, GameManager.current_map.height - 1)
	if not GameManager.is_tile_blocked(tx, ty, stats.unit_class):
		return pos
	var free := GameManager.nearest_free_tile(tx, ty, stats.unit_class)
	return Vector2(free.x * 16.0 + 8.0, free.y * 16.0 + 8.0)

func _build_hex_path(goal_world: Vector2) -> void:
	hex_path.clear()
	path_index = 0
	if GameManager.current_map == null:
		hex_path.append(hex_grid.hex_to_world(hex_grid.world_to_hex(goal_world)))
		return
	var heavy := stats != null and (stats.unit_class == 6 or stats.unit_class == 7)
	var uclass := stats.unit_class if stats else 0
	var start_hex := hex_grid.world_to_hex(global_position)
	var goal_hex := hex_grid.world_to_hex(goal_world)
	var passable := func(h: Vector2i) -> bool:
		var wpos := hex_grid.hex_to_world(h)
		var tx := int(wpos.x / 16.0)
		var ty := int(wpos.y / 16.0)
		if not GameManager.current_map.in_bounds(tx, ty):
			return false
		# Sapper fortifications are hard terrain for ground units.
		if GameManager.is_tile_blocked(tx, ty, uclass):
			return false
		return MapData.is_passable(GameManager.current_map.get_terrain(tx, ty), uclass, heavy)
	var hexes := hex_grid.hex_path(start_hex, goal_hex, passable)
	for h in hexes:
		hex_path.append(hex_grid.hex_to_world(h))
	if hex_path.is_empty():
		hex_path.append(hex_grid.hex_to_world(goal_hex))

func stop_command() -> void:
	has_target = false
	attack_move = false
	hex_path.clear()
	path_index = 0
	focus_target = null
	velocity = Vector2.ZERO

func trigger_eels() -> void:
	eel_timer = 5.0

func take_damage(amount: float) -> void:
	if is_exploding:
		return
	hp -= int(maxf(1.0, round(amount)))
	hit_flash_timer = 0.14
	if hp_bar:
		hp_bar.value = maxf(0.0, float(hp) / float(effective_max_hp()) * 100.0)
	if hp <= 0:
		_trigger_explosion()

func _trigger_explosion() -> void:
	if is_exploding:
		return
	if not cargo.is_empty():
		disembark_all()
	is_exploding = true
	has_target = false
	selected = false
	velocity = Vector2.ZERO
	explode_timer = 0.0
	anim_state = UnitVisual.AnimState.EXPLODE
	anim_elapsed = 0.0
	if hp_bar:
		hp_bar.visible = false
	remove_from_group("units")
	explosion_debris = UnitVisual.generate_explosion_debris(int(get_instance_id()), 10)
	var scene = get_tree().current_scene
	if scene and scene.has_method("spawn_explosion_vfx"):
		var rad := 26.0 if (stats and stats.unit_class == 1) else 18.0
		scene.spawn_explosion_vfx(global_position, rad)
	AudioManager.play_sfx("unit_explode")

func _draw():
	var uclass := stats.unit_class if stats else 0
	var kin := UnitVisual.compute_kinematics(anim_state, anim_elapsed, uclass)

	if is_exploding:
		var prog := float(kin["explosion_progress"])
		var max_r := 26.0 if uclass == 1 else 18.0
		# Shockwave ring
		draw_arc(Vector2.ZERO, lerpf(4.0, max_r * 1.45, prog), 0, TAU, 24, Color(1.0, 0.75, 0.25, 1.0 - prog), 2.5)
		# Expanding fireball + smoke core
		draw_circle(Vector2.ZERO, lerpf(6.0, max_r, sin(prog * PI)), Color(1.0, 0.45, 0.1, 0.85 * (1.0 - prog * 0.7)))
		draw_circle(Vector2.ZERO, lerpf(3.0, max_r * 0.55, sin(prog * PI)), Color(1.0, 0.95, 0.65, 0.9 * (1.0 - prog)))
		# Flying shrapnel debris
		for p in explosion_debris:
			var d_pos: Vector2 = p["dir"] * float(p["speed"]) * explode_timer
			var c_heat := Color(1.0, 0.65, 0.2, 1.0 - prog).lerp(Color(0.25, 0.25, 0.25, 1.0 - prog), prog)
			draw_circle(d_pos, float(p["size"]) * (1.0 - prog * 0.5), c_heat)
		return

	# Moving dust/wake/exhaust puffs
	if anim_state == UnitVisual.AnimState.MOVE:
		var back_dir := -Vector2.RIGHT.rotated(facing_angle)
		var puff_offset := back_dir * (11.0 + absf(float(kin["stride"])) * 5.0)
		var puff_col := Color(0.75, 0.95, 1.0, 0.45) if uclass == 2 else Color(0.65, 0.62, 0.55, 0.38)
		draw_circle(puff_offset + Vector2(0, 3), 3.0 + absf(float(kin["stride"])) * 2.0, puff_col)
		draw_circle(puff_offset - Vector2(0, 3), 2.5 + (1.0 - absf(float(kin["stride"]))) * 2.0, puff_col)

	# Air drone spinning rotor blades
	if uclass == 3:
		var r_ang := float(kin["rotor_angle"])
		var blade := Vector2.RIGHT.rotated(r_ang) * 11.0
		draw_line(-blade, blade, Color(0.9, 0.95, 1.0, 0.55), 1.8)
		var blade2 := Vector2.RIGHT.rotated(r_ang + PI * 0.5) * 11.0
		draw_line(-blade2, blade2, Color(0.9, 0.95, 1.0, 0.55), 1.8)

	# Independent rotating turret & recoil barrel for vehicles/mechs
	if uclass == 1:
		var recoil_vec := -Vector2.RIGHT.rotated(turret_angle) * float(kin["recoil"])
		var barrel_end := Vector2.RIGHT.rotated(turret_angle) * 16.0 + recoil_vec
		draw_line(recoil_vec, barrel_end, Color(0.82, 0.85, 0.9, 1.0), 3.2)

	# Muzzle flash burst when firing
	var m_alpha := float(kin["muzzle_alpha"])
	if m_alpha > 0.05:
		var muzzle_dir := Vector2.RIGHT.rotated(turret_angle)
		var muzzle_tip := muzzle_dir * (16.0 - float(kin["recoil"]))
		draw_circle(muzzle_tip, 5.5 * m_alpha, Color(1.0, 0.65, 0.15, m_alpha))
		draw_circle(muzzle_tip + muzzle_dir * 3.0, 3.2 * m_alpha, Color(1.0, 0.98, 0.75, m_alpha))

	if selected:
		draw_arc(Vector2.ZERO, 18, 0, TAU, 24, Color.YELLOW, 2.0)
	if EMP.is_disabled(emp_timer):
		draw_arc(Vector2.ZERO, 14, 0, TAU, 16, Color.CYAN, 2.0)
	if not cargo.is_empty():
		for ci in range(cargo.size()):
			draw_rect(Rect2(-12.0 + float(ci) * 6.0, 14.0, 4.0, 4.0), Color(0.2, 1.0, 0.45, 0.95), true)
