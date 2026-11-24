# scripts/game/unit.gd
extends CharacterBody2D

var stats: UnitStats
var team: int = 0
var hp: int = 100
var selected: bool = false
var faction: int = -1
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
		hp = stats.hp
		if stats.stealth:
			cloak_timer = 10.0
	target_pos = global_position
	facing_angle = 0.0 if team == 0 else PI
	turret_angle = facing_angle
	if body:
		body.visible = false
	_setup_animated_sprite()
	add_to_group("units")

func setup(s: UnitStats, t: int, f: int = -1) -> void:
	stats = s
	team = t
	faction = f if f >= 0 else (0 if t == 0 else 1)
	hp = s.hp
	facing_angle = 0.0 if t == 0 else PI
	turret_angle = facing_angle
	if s.stealth:
		cloak_timer = 10.0
	_frame_cache.clear()
	_update_visual()

func _setup_animated_sprite() -> void:
	if sprite_node != null:
		return
	sprite_node = Sprite2D.new()
	sprite_node.name = "AnimatedUnitSprite"
	sprite_node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite_node)
	_refresh_sprite_texture()

func _team_base_color() -> Color:
	var c := Faction.color_of(faction) if faction >= 0 else (Color(0.22, 0.58, 1.0, 1.0) if team == 0 else Color(0.96, 0.26, 0.24, 1.0))
	if stats:
		match stats.unit_class:
			1, 4, 7: c = c.darkened(0.1)
			2: c = c.lerp(Color.CYAN, 0.25)
			3: c = c.lightened(0.2)
			5: c = c.darkened(0.2)
	return c

func _refresh_sprite_texture() -> void:
	if sprite_node == null:
		return
	var f_idx := UnitVisual.frame_index(anim_state, anim_elapsed, anim_state != UnitVisual.AnimState.EXPLODE)
	var key := "%d:%d" % [anim_state, f_idx]
	if not _frame_cache.has(key):
		var uclass := stats.unit_class if stats else 0
		var uid := stats.id if stats else ""
		var img := UnitVisual.build_unit_frame_image(uclass, anim_state, f_idx, _team_base_color(), 32, uid)
		_frame_cache[key] = ImageTexture.create_from_image(img)
	sprite_node.texture = _frame_cache[key]
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
		cloak_timer = minf(cloak_timer + delta, 10.0)

	# Medicbot auto-repair nearby friendly robots
	if stats and stats.id == "medicbot":
		_auto_repair_allies(delta)

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
			var spd := stats.speed if stats else 100.0
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

func _terrain_speed_multiplier() -> float:
	if GameManager.current_map == null or stats == null:
		return 1.0
	var tx := clampi(int(global_position.x / 16.0), 0, GameManager.current_map.width - 1)
	var ty := clampi(int(global_position.y / 16.0), 0, GameManager.current_map.height - 1)
	var t := GameManager.current_map.get_terrain(tx, ty)
	var cost := MapData.movement_cost(t, stats.unit_class)
	if cost >= INF or cost <= 0.0:
		return 0.5
	return clampf(1.0 / cost, 0.4, 1.4)

func _auto_repair_allies(delta: float) -> void:
	for u in get_tree().get_nodes_in_group("units"):
		if u == self or not is_instance_valid(u) or u.team != team or u.is_exploding:
			continue
		if u.stats and Repair.can_repair(u.hp, u.stats.hp):
			if global_position.distance_to(u.global_position) <= 100.0:
				var amt := int(ceil(Repair.repair_amount(12.0, delta)))
				u.hp = mini(u.stats.hp, u.hp + amt)
				if u.hp_bar:
					u.hp_bar.value = float(u.hp) / float(u.stats.hp) * 100.0
				break

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
	if GameManager.current_map != null:
		var tx := clampi(int(enemy.global_position.x / 16.0), 0, GameManager.current_map.width - 1)
		var ty := clampi(int(enemy.global_position.y / 16.0), 0, GameManager.current_map.height - 1)
		cover_mod = Cover.modifier(GameManager.current_map.get_terrain(tx, ty))
	var final_dmg := Damage.compute(base_dmg, dmg_type, target_armor, 0.0, cover_mod)
	if stats and stats.id == "sapperbot" and target_armor == Damage.ArmorClass.STRUCTURE:
		final_dmg *= 2.5

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
	var has_radar := stats != null and (stats.id == "awacs" or stats.id == "scout_drone")
	for u in get_tree().get_nodes_in_group("units"):
		if u == self or not is_instance_valid(u) or u.team == team:
			continue
		if "is_exploding" in u and u.is_exploding:
			continue
		var d := global_position.distance_to(u.global_position)
		if u.has_method("is_cloaked") and u.is_cloaked():
			if not Vision.stealth_detected(sgt, d, true, has_radar):
				continue
		if d < best_d:
			best_d = d
			best = u
	for b in get_tree().get_nodes_in_group("buildings"):
		if not is_instance_valid(b) or b.team == team:
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
	_build_hex_path(pos)
	if hex_path.size() > 0:
		path_index = 0
		target_pos = hex_path[0]
	else:
		target_pos = hex_grid.hex_to_world(hex_grid.world_to_hex(pos))

func _build_hex_path(goal_world: Vector2) -> void:
	hex_path.clear()
	path_index = 0
	if GameManager.current_map == null:
		hex_path.append(hex_grid.hex_to_world(hex_grid.world_to_hex(goal_world)))
		return
	var heavy := stats != null and (stats.unit_class == 6 or stats.unit_class == 7)
	var start_hex := hex_grid.world_to_hex(global_position)
	var goal_hex := hex_grid.world_to_hex(goal_world)
	var passable := func(h: Vector2i) -> bool:
		var wpos := hex_grid.hex_to_world(h)
		var tx := int(wpos.x / 16.0)
		var ty := int(wpos.y / 16.0)
		if not GameManager.current_map.in_bounds(tx, ty):
			return false
		return MapData.is_passable(GameManager.current_map.get_terrain(tx, ty), stats.unit_class if stats else 0, heavy)
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
		hp_bar.value = maxf(0.0, float(hp) / float(stats.hp if stats else 100) * 100.0)
	if hp <= 0:
		_trigger_explosion()

func _trigger_explosion() -> void:
	if is_exploding:
		return
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
