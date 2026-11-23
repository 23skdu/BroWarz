# scripts/game/unit.gd
extends CharacterBody2D

var stats: UnitStats
var team: int = 0
var hp: int = 100
var selected: bool = false
var target_pos: Vector2 = Vector2.ZERO
var has_target: bool = false
var attack_move: bool = false
var hold_position: bool = false
var attack_timer: float = 0.0
var attack_cooldown: float = 0.8
var emp_timer: float = 0.0
var cloak_timer: float = 0.0
var focus_target: Node2D = null

@onready var body = $Body
@onready var hp_bar = $HpBar

func _ready():
	if stats:
		hp = stats.hp
		if stats.stealth:
			cloak_timer = 10.0
	target_pos = global_position
	add_to_group("units")

func setup(s: UnitStats, t: int) -> void:
	stats = s
	team = t
	hp = s.hp
	if s.stealth:
		cloak_timer = 10.0
	_update_visual()

func _update_visual() -> void:
	if not body:
		return
	var base_color := Color(0.2, 0.55, 1.0, 1.0) if team == 0 else Color(0.95, 0.25, 0.25, 1.0)
	if stats:
		match stats.unit_class:
			1: # vehicle / mech
				base_color = base_color.darkened(0.15)
				body.offset_left = -11.0
				body.offset_top = -11.0
				body.offset_right = 11.0
				body.offset_bottom = 11.0
			2: # naval
				base_color = base_color.lerp(Color.CYAN, 0.25)
			3: # air
				base_color = base_color.lightened(0.25)
	if is_cloaked():
		base_color.a = 0.45
	body.color = base_color

func is_cloaked() -> bool:
	return stats != null and stats.stealth and Stealth.is_cloaked(cloak_timer)

func apply_emp(duration: float) -> void:
	var ac := stats.armor_class if stats else 0
	emp_timer = maxf(emp_timer, EMP.disable_duration(duration, ac))

func _physics_process(delta):
	emp_timer = EMP.tick(emp_timer, delta)
	if EMP.is_disabled(emp_timer):
		velocity = Vector2.ZERO
		queue_redraw()
		return

	attack_timer -= delta
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
				queue_redraw()
				return
		var dir = (target_pos - global_position)
		if dir.length() > 6.0:
			var spd := stats.speed if stats else 100.0
			var terrain_mult := _terrain_speed_multiplier()
			velocity = dir.normalized() * spd * terrain_mult
			move_and_slide()
		else:
			has_target = false
			attack_move = false
			velocity = Vector2.ZERO
	else:
		velocity = Vector2.ZERO
		_try_attack()
	_update_visual()
	queue_redraw()

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
		if u == self or not is_instance_valid(u) or u.team != team:
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
	var enemy = focus_target if is_instance_valid(focus_target) else _nearest_enemy()
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
	# Sapper bonus vs buildings
	if stats and stats.id == "sapperbot" and target_armor == Damage.ArmorClass.STRUCTURE:
		final_dmg *= 2.5
	enemy.take_damage(final_dmg)
	if dmg_type == Damage.DamageType.EMP and enemy.has_method("apply_emp"):
		enemy.apply_emp(2.5)

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
		var d := global_position.distance_to(b.global_position)
		if d < best_d:
			best_d = d
			best = b
	return best

func move_to(pos: Vector2, is_attack_move: bool = false) -> void:
	target_pos = pos
	has_target = true
	attack_move = is_attack_move
	hold_position = false

func stop_command() -> void:
	has_target = false
	attack_move = false
	focus_target = null
	velocity = Vector2.ZERO

func take_damage(amount: float) -> void:
	hp -= int(maxf(1.0, round(amount)))
	if hp_bar:
		hp_bar.value = float(hp) / float(stats.hp if stats else 100) * 100.0
	if hp <= 0:
		remove_from_group("units")
		queue_free()

func _draw():
	if selected:
		draw_arc(Vector2.ZERO, 18, 0, TAU, 24, Color.YELLOW, 2.0)
	if EMP.is_disabled(emp_timer):
		draw_arc(Vector2.ZERO, 14, 0, TAU, 16, Color.CYAN, 2.0)
