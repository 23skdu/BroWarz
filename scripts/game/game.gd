# scripts/game/game.gd
extends Node2D

var map_data: MapData
var selected_units: Array = []
var control_groups: Dictionary = {}  # key 0..9 -> Array of Unit
var camera: Camera2D
var match_over: bool = false
var elapsed_time: float = 0.0
var economy_timer: float = 0.0
var ai_timer: float = 0.0
var ai_tech_tier: int = 1
var player_tech_tier: int = 1
var ai_tactical_state: String = "rally"
var drag_selecting: bool = false
var drag_start: Vector2 = Vector2.ZERO
var drag_current: Vector2 = Vector2.ZERO
var laser_cooldown: float = 0.0
var nuke_cooldown: float = 0.0
var active_vfx: Array = []      # Array of Dictionary {type, pos, radius, max_radius, color, timer, duration}
var active_tracers: Array = []  # Array of Dictionary {from, to, color, width, timer, duration}
var scorch_marks: Array = []    # Array of Dictionary {pos, radius, alpha}

@onready var units_container = $Units
@onready var ui = $UI
@onready var status_label = $UI/StatusLabel

var hud_label: Label
var ai_status_label: Label
var help_label: Label

func _ready():
	if GameManager.registry.units.is_empty():
		GameManager.registry.populate_defaults()
	map_data = MapData.new(128, 128)
	_generate_map()
	camera = $Camera2D
	camera.position = Vector2(360, 300)
	_setup_hud()
	_init_economies()
	_spawn_starting_bases()
	GameManager.start_match(map_data)
	AudioManager.set_music("battle")

func _generate_map() -> void:
	for y in range(128):
		for x in range(128):
			if (x + y) % 17 == 0:
				map_data.set_terrain(x, y, MapData.Terrain.FOREST)
			elif (x * 3 + y) % 29 == 0 and x > 15 and x < 105:
				map_data.set_terrain(x, y, MapData.Terrain.URBAN)
			elif x % 31 == 0 and y % 31 == 0 and x > 10 and y > 10:
				map_data.set_terrain(x, y, MapData.Terrain.MOUNTAIN)
			elif abs(x - y) < 2 and x > 35 and x < 85:
				map_data.set_terrain(x, y, MapData.Terrain.ROAD)

func spawn_combat_tracer(from_pos: Vector2, to_pos: Vector2, dmg_type: int, _team: int) -> void:
	var col := Color(1.0, 0.92, 0.4, 0.95)
	var w := 2.2
	var dur := 0.14
	match dmg_type:
		Damage.DamageType.EXPLOSIVE:
			col = Color(1.0, 0.55, 0.15, 0.95)
			w = 3.2
			dur = 0.22
		Damage.DamageType.ENERGY:
			col = Color(0.25, 0.95, 1.0, 0.95)
			w = 2.8
			dur = 0.18
		Damage.DamageType.EMP:
			col = Color(0.55, 0.8, 1.0, 0.95)
			w = 2.6
			dur = 0.2
		Damage.DamageType.THERMAL:
			col = Color(1.0, 0.3, 0.1, 0.95)
			w = 3.6
			dur = 0.24
	active_tracers.append({
		"from": from_pos,
		"to": to_pos,
		"color": col,
		"width": w,
		"timer": dur,
		"duration": dur,
	})
	queue_redraw()

func spawn_explosion_vfx(world_pos: Vector2, max_radius: float = 24.0) -> void:
	active_vfx.append({
		"type": "explosion",
		"pos": world_pos,
		"radius": max_radius,
		"color": Color(1.0, 0.5, 0.12, 0.85),
		"timer": 0.55,
		"duration": 0.55,
	})
	scorch_marks.append({
		"pos": world_pos,
		"radius": max_radius * 0.65,
		"alpha": 0.45,
	})
	if scorch_marks.size() > 64:
		scorch_marks.pop_front()
	queue_redraw()

func _setup_hud() -> void:
	hud_label = Label.new()
	hud_label.name = "HudLabel"
	hud_label.position = Vector2(20, 50)
	ui.add_child(hud_label)

	ai_status_label = Label.new()
	ai_status_label.name = "AiStatusLabel"
	ai_status_label.position = Vector2(20, 80)
	ui.add_child(ai_status_label)

	help_label = Label.new()
	help_label.name = "HelpLabel"
	help_label.position = Vector2(20, 110)
	help_label.text = "[LMB/Drag] Select | [RMB] Move/Attack-Move | [1-6] Train (Rifle/Rocket/Stealth/Tank/AA/Fighter) | [B] Build Extractor | [T] Tech Up | [L] Orbital Laser | [N] Launch Nuke"
	ui.add_child(help_label)

	var btn_bar := HBoxContainer.new()
	btn_bar.name = "CommandBar"
	btn_bar.position = Vector2(20, 140)
	ui.add_child(btn_bar)

	_add_cmd_button(btn_bar, "Train Riflebot [1]", func(): _player_train_unit("riflebot"))
	_add_cmd_button(btn_bar, "Train Rocketbot [2]", func(): _player_train_unit("rocketbot"))
	_add_cmd_button(btn_bar, "Train Stealthbot [3]", func(): _player_train_unit("stealthbot"))
	_add_cmd_button(btn_bar, "Train Tank [4]", func(): _player_train_unit("mbt"))
	_add_cmd_button(btn_bar, "Train AA [5]", func(): _player_train_unit("aa_vehicle"))
	_add_cmd_button(btn_bar, "Train Fighter [6]", func(): _player_train_unit("fighter_drone"))
	_add_cmd_button(btn_bar, "Build Extractor [B]", func(): _player_build_structure("extractor"))
	_add_cmd_button(btn_bar, "Build Turret [V]", func(): _player_build_structure("turret"))
	_add_cmd_button(btn_bar, "Tech Up [T]", func(): _player_upgrade_tech())
	_add_cmd_button(btn_bar, "Orbital Laser [L]", func(): _player_fire_orbital_laser())
	_add_cmd_button(btn_bar, "Nuclear Strike [N]", func(): _player_fire_nuke())
	_add_cmd_button(btn_bar, "Main Menu", func(): SceneManager.goto_scene("res://scenes/main_menu.tscn"))

func _add_cmd_button(parent: Node, label_text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = label_text
	b.pressed.connect(cb)
	parent.add_child(b)

func _init_economies() -> void:
	var start_res := {
		Economy.Res.OIL: 300,
		Economy.Res.IRON: 500,
		Economy.Res.GEOTHERMAL: 150,
		Economy.Res.FOOD: 200,
	}
	ResourceManager.init_player(0, start_res)
	ResourceManager.init_player(1, start_res)
	_set_base_rates(0, 1.0)
	var ai_mult := AI.income_multiplier(GameManager.ai_difficulty)
	_set_base_rates(1, ai_mult)
	ResourceManager.caps[0] = 20
	ResourceManager.caps[1] = 20

func _set_base_rates(pid: int, mult: float) -> void:
	ResourceManager.set_rate(pid, Economy.Res.OIL, int(round(18.0 * mult)))
	ResourceManager.set_rate(pid, Economy.Res.IRON, int(round(32.0 * mult)))
	ResourceManager.set_rate(pid, Economy.Res.GEOTHERMAL, int(round(10.0 * mult)))
	ResourceManager.set_rate(pid, Economy.Res.FOOD, int(round(15.0 * mult)))

func _spawn_starting_bases() -> void:
	# Player 0 (Blue) top-left base
	_spawn_building_by_id("hq", Vector2(140, 140), 0)
	_spawn_building_by_id("barracks", Vector2(220, 140), 0)
	_spawn_building_by_id("factory", Vector2(140, 220), 0)
	_spawn_building_by_id("extractor", Vector2(80, 200), 0)
	_spawn_unit_by_id("riflebot", Vector2(200, 200), 0)
	_spawn_unit_by_id("riflebot", Vector2(230, 200), 0)
	_spawn_unit_by_id("rocketbot", Vector2(200, 230), 0)
	_spawn_unit_by_id("engineerbot", Vector2(170, 200), 0)

	# Player 1 (Red / Skirmish AI) bottom-right base
	_spawn_building_by_id("hq", Vector2(1100, 900), 1)
	_spawn_building_by_id("barracks", Vector2(1010, 900), 1)
	_spawn_building_by_id("factory", Vector2(1100, 810), 1)
	_spawn_building_by_id("extractor", Vector2(1170, 840), 1)
	_spawn_unit_by_id("riflebot", Vector2(1020, 820), 1)
	_spawn_unit_by_id("riflebot", Vector2(1050, 820), 1)
	_spawn_unit_by_id("rocketbot", Vector2(1020, 850), 1)
	_spawn_unit_by_id("engineerbot", Vector2(1070, 850), 1)

func _spawn_unit(pos: Vector2, team: int) -> void:
	_spawn_unit_by_id("riflebot", pos, team)

func _spawn_unit_by_id(uid: String, pos: Vector2, team: int) -> Node2D:
	var u = preload("res://scenes/unit.tscn").instantiate()
	var s: UnitStats = GameManager.registry.get_unit(uid)
	if s == null:
		s = UnitStats.new()
		s.id = uid
		s.display_name = uid.capitalize()
	u.setup(s, team)
	u.global_position = pos
	units_container.add_child(u)
	return u

func _spawn_building(pos: Vector2, team: int) -> void:
	_spawn_building_by_id("hq", pos, team)

func _spawn_building_by_id(bid: String, pos: Vector2, team: int) -> Node2D:
	var b = preload("res://scenes/building.tscn").instantiate()
	var s: BuildingStats = GameManager.registry.get_building(bid)
	if s == null:
		s = BuildingStats.new()
		s.id = bid
		s.display_name = bid.capitalize()
		s.is_hq = (bid == "hq")
	b.setup(s, team)
	b.global_position = pos
	add_child(b)
	return b

func _world_mouse_pos(screen_pos: Vector2) -> Vector2:
	return screen_pos + camera.position - get_viewport_rect().size / 2.0

func _unhandled_input(event):
	if event is InputEventMouseButton:
		var world_pos := _world_mouse_pos(event.position)
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				drag_selecting = true
				drag_start = world_pos
				drag_current = world_pos
			else:
				drag_selecting = false
				_complete_selection(drag_start, world_pos, Input.is_key_pressed(KEY_SHIFT))
				queue_redraw()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_issue_move_order(world_pos, Input.is_key_pressed(KEY_A))
	elif event is InputEventMouseMotion and drag_selecting:
		drag_current = _world_mouse_pos(event.position)
		queue_redraw()
	elif event is InputEventKey and event.pressed and not event.echo:
		_handle_hotkey(event)

func _complete_selection(start_p: Vector2, end_p: Vector2, additive: bool) -> void:
	if not additive:
		for u in selected_units:
			if is_instance_valid(u):
				u.selected = false
		selected_units.clear()

	if start_p.distance_to(end_p) < 12.0:
		var clicked = _unit_at(end_p)
		if clicked and clicked.team == 0:
			clicked.selected = true
			if not selected_units.has(clicked):
				selected_units.append(clicked)
	else:
		var rect := Rect2(start_p, end_p - start_p).abs()
		for u in units_container.get_children():
			if is_instance_valid(u) and not u.is_exploding and u.team == 0 and rect.has_point(u.global_position):
				u.selected = true
				if not selected_units.has(u):
					selected_units.append(u)

func _issue_move_order(target: Vector2, is_attack_move: bool = true) -> void:
	var valid_units: Array = []
	for u in selected_units:
		if is_instance_valid(u) and not u.is_exploding:
			valid_units.append(u)
	if valid_units.is_empty():
		return
	var offsets := Formation.grid_offsets(valid_units.size(), 28.0)
	for i in range(valid_units.size()):
		valid_units[i].move_to(target + offsets[i], is_attack_move)
	AudioManager.play_sfx("order_move")

func _handle_hotkey(event: InputEventKey) -> void:
	match event.keycode:
		KEY_1: _player_train_unit("riflebot")
		KEY_2: _player_train_unit("rocketbot")
		KEY_3: _player_train_unit("stealthbot")
		KEY_4: _player_train_unit("mbt")
		KEY_5: _player_train_unit("aa_vehicle")
		KEY_6: _player_train_unit("fighter_drone")
		KEY_B: _player_build_structure("extractor")
		KEY_V: _player_build_structure("turret")
		KEY_T: _player_upgrade_tech()
		KEY_L: _player_fire_orbital_laser()
		KEY_N: _player_fire_nuke()
		KEY_H:
			for u in selected_units:
				if is_instance_valid(u):
					u.stop_command()
					u.hold_position = true

func _wallet_cost(s_cost: Dictionary) -> Dictionary:
	return {
		Economy.Res.OIL: int(s_cost.get("oil", 0)),
		Economy.Res.IRON: int(s_cost.get("iron", 0)),
		Economy.Res.GEOTHERMAL: int(s_cost.get("geo", 0)),
		Economy.Res.FOOD: int(s_cost.get("food", 0)),
	}

func _player_train_unit(uid: String) -> void:
	_train_unit_for_team(0, uid)

func _train_unit_for_team(team: int, uid: String) -> bool:
	var s := GameManager.registry.get_unit(uid)
	if s == null:
		return false
	var wallet := ResourceManager.get_wallet(team)
	var cost := _wallet_cost(s.cost_dict())
	if not Economy.spend(wallet, cost):
		return false
	var producer: Node2D = null
	for b in get_tree().get_nodes_in_group("buildings"):
		if is_instance_valid(b) and not b.is_exploding and b.team == team:
			if (s.unit_class == 0 and b.stats and b.stats.id == "barracks") or (s.unit_class == 1 and b.stats and b.stats.id == "factory") or (s.unit_class == 3 and b.stats and b.stats.id == "airfield"):
				producer = b
				break
			if producer == null and b.stats and b.stats.is_hq:
				producer = b
	if producer != null and producer.has_method("enqueue_unit"):
		producer.enqueue_unit(uid, s.build_time)
		return true
	_spawn_unit_by_id(uid, Vector2(180, 180) if team == 0 else Vector2(1040, 840), team)
	return true

func _player_build_structure(bid: String) -> void:
	_build_structure_for_team(0, bid)

func _build_structure_for_team(team: int, bid: String) -> bool:
	var bs := GameManager.registry.get_building(bid)
	if bs == null:
		return false
	var wallet := ResourceManager.get_wallet(team)
	var cost := _wallet_cost(bs.cost_dict())
	if not Economy.spend(wallet, cost):
		return false
	var base_pos := Vector2(160, 160) if team == 0 else Vector2(1080, 880)
	var count := _count_team_buildings(team, bid)
	var offset := Vector2((count % 4) * 58.0 - 60.0, int(count / 4) * 58.0 + 75.0)
	if team == 1:
		offset = -offset
	_spawn_building_by_id(bid, base_pos + offset, team)
	if bid == "extractor":
		var cur_iron := int(ResourceManager.rates[team].get(Economy.Res.IRON, 20))
		var cur_oil := int(ResourceManager.rates[team].get(Economy.Res.OIL, 10))
		var cur_geo := int(ResourceManager.rates[team].get(Economy.Res.GEOTHERMAL, 5))
		ResourceManager.set_rate(team, Economy.Res.IRON, cur_iron + 12)
		ResourceManager.set_rate(team, Economy.Res.OIL, cur_oil + 8)
		ResourceManager.set_rate(team, Economy.Res.GEOTHERMAL, cur_geo + 5)
	elif bid == "farm":
		ResourceManager.caps[team] = int(ResourceManager.caps.get(team, 20)) + 8
	return true

func _player_upgrade_tech() -> void:
	if player_tech_tier >= 4:
		return
	var wallet := ResourceManager.get_wallet(0)
	var cost := {Economy.Res.OIL: 100 * player_tech_tier, Economy.Res.IRON: 180 * player_tech_tier, Economy.Res.GEOTHERMAL: 60 * player_tech_tier}
	if Economy.spend(wallet, cost):
		player_tech_tier += 1
		AudioManager.play_sfx("tech_up")

func _player_fire_orbital_laser() -> void:
	if laser_cooldown > 0.0:
		return
	var wallet := ResourceManager.get_wallet(0)
	if not Economy.spend(wallet, {Economy.Res.GEOTHERMAL: 100, Economy.Res.OIL: 60}):
		return
	laser_cooldown = 25.0
	var target_pos := Vector2(1060, 860)
	var enemy := _find_priority_target_for_team(0)
	if enemy != null:
		target_pos = enemy.global_position
	var dmg := Strategic.orbital_laser_damage(180.0, float(wallet.get(Economy.Res.GEOTHERMAL, 0)))
	_apply_aoe_damage(target_pos, 95.0, dmg, 0)
	active_vfx.append({"type": "laser", "pos": target_pos, "radius": 95.0, "color": Color(0.2, 0.95, 1.0, 0.75), "timer": 1.2, "duration": 1.2})
	AudioManager.play_sfx("orbital_laser")

func _player_fire_nuke() -> void:
	if nuke_cooldown > 0.0:
		return
	var wallet := ResourceManager.get_wallet(0)
	if not Economy.spend(wallet, {Economy.Res.GEOTHERMAL: 200, Economy.Res.IRON: 300, Economy.Res.OIL: 180}):
		return
	nuke_cooldown = 45.0
	var target_pos := Vector2(1100, 900)
	var enemy_hq := _find_team_hq(1)
	if enemy_hq != null:
		target_pos = enemy_hq.global_position
	_apply_aoe_damage(target_pos, 180.0, 650.0, 0)
	if Strategic.creates_fallout("nuke"):
		var rad := Strategic.nuke_fallout_radius(4, 1.0)
		var cx := clampi(int(target_pos.x / 16.0), 0, map_data.width - 1)
		var cy := clampi(int(target_pos.y / 16.0), 0, map_data.height - 1)
		for dy in range(-rad, rad + 1):
			for dx in range(-rad, rad + 1):
				map_data.set_terrain(cx + dx, cy + dy, MapData.Terrain.WASTELAND)
	active_vfx.append({"type": "nuke", "pos": target_pos, "radius": 180.0, "color": Color(1.0, 0.45, 0.1, 0.8), "timer": 2.0, "duration": 2.0})
	AudioManager.play_sfx("nuclear_launch")

func _apply_aoe_damage(center: Vector2, radius: float, dmg: float, attacker_team: int) -> void:
	for u in get_tree().get_nodes_in_group("units"):
		if is_instance_valid(u) and not u.is_exploding and u.team != attacker_team and u.global_position.distance_to(center) <= radius:
			u.take_damage(dmg)
	for b in get_tree().get_nodes_in_group("buildings"):
		if is_instance_valid(b) and not b.is_exploding and b.team != attacker_team and b.global_position.distance_to(center) <= radius:
			b.take_damage(dmg)

func _find_team_hq(team: int) -> Node2D:
	for b in get_tree().get_nodes_in_group("buildings"):
		if is_instance_valid(b) and not b.is_exploding and b.team == team and b.stats and b.stats.is_hq:
			return b
	return null

func _find_priority_target_for_team(attacker_team: int) -> Node2D:
	var candidates: Array = []
	var node_map: Dictionary = {}
	for b in get_tree().get_nodes_in_group("buildings"):
		if is_instance_valid(b) and not b.is_exploding and b.team != attacker_team:
			var id := b.get_instance_id()
			node_map[id] = b
			candidates.append({"id": id, "strength": float(b.hp)})
	for u in get_tree().get_nodes_in_group("units"):
		if is_instance_valid(u) and not u.is_exploding and u.team != attacker_team:
			var id := u.get_instance_id()
			node_map[id] = u
			candidates.append({"id": id, "strength": float(u.hp)})
	var picked_id := AI.choose_weakest_target(candidates)
	return node_map.get(picked_id, null)

func _unit_at(pos: Vector2):
	for u in units_container.get_children():
		if is_instance_valid(u) and not u.is_exploding and u.global_position.distance_to(pos) < 18:
			return u
	return null

func _process(delta):
	elapsed_time += delta
	laser_cooldown = maxf(0.0, laser_cooldown - delta)
	nuke_cooldown = maxf(0.0, nuke_cooldown - delta)

	var needs_redraw := false
	for i in range(active_vfx.size() - 1, -1, -1):
		active_vfx[i]["timer"] = float(active_vfx[i]["timer"]) - delta
		needs_redraw = true
		if float(active_vfx[i]["timer"]) <= 0.0:
			active_vfx.remove_at(i)

	for i in range(active_tracers.size() - 1, -1, -1):
		active_tracers[i]["timer"] = float(active_tracers[i]["timer"]) - delta
		needs_redraw = true
		if float(active_tracers[i]["timer"]) <= 0.0:
			active_tracers.remove_at(i)

	if needs_redraw:
		queue_redraw()

	# Economy 1s tick
	economy_timer += delta
	if economy_timer >= 1.0:
		ResourceManager.tick(1.0)
		economy_timer -= 1.0

	# Single-player Skirmish AI tick
	if not match_over and GameManager.match_mode == GameManager.Mode.SINGLE_PLAYER:
		ai_timer += delta
		var interval := AI.decision_interval(GameManager.ai_difficulty)
		if ai_timer >= interval:
			ai_timer = 0.0
			_run_skirmish_ai_turn()

	_update_hud()
	_check_win()
	var pan = Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): pan.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): pan.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): pan.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): pan.x += 1
	camera.position += pan * 420.0 * delta

func _run_skirmish_ai_turn() -> void:
	var ai_wallet := ResourceManager.get_wallet(1)
	var b_counts := _get_team_building_counts(1)
	var ai_units := _get_team_units(1)
	var player_units := _get_team_units(0)
	var pop_cap := int(ResourceManager.caps.get(1, 20))

	# 1. Economy & Base Expansion
	var next_bld := AI.select_next_building(b_counts, ai_units.size(), pop_cap)
	if AI.should_expand(float(ResourceManager.rates[1].get(Economy.Res.IRON, 0)), 20.0):
		_build_structure_for_team(1, next_bld)

	# 2. Tech progression
	if ai_tech_tier < 3 and elapsed_time > 25.0 * ai_tech_tier:
		var t_cost := {Economy.Res.OIL: 90 * ai_tech_tier, Economy.Res.IRON: 150 * ai_tech_tier}
		if Economy.spend(ai_wallet, t_cost):
			ai_tech_tier += 1

	# 3. Counter-production
	var enemy_comp := _classify_units(player_units)
	enemy_comp["fortifications"] = _count_team_buildings(0, "turret")
	var chosen_uid := AI.choose_production_unit(ai_wallet, enemy_comp, ai_tech_tier)
	_train_unit_for_team(1, chosen_uid)
	if GameManager.ai_difficulty == AI.Difficulty.HARD and ai_units.size() < pop_cap:
		_train_unit_for_team(1, "riflebot")

	# 4. Tactical squad coordination
	var ai_hq := _find_team_hq(1)
	var ai_base_pos := ai_hq.global_position if ai_hq != null else Vector2(1100, 900)
	var enemy_near_base := 0
	var closest_intruder: Node2D = null
	for pu in player_units:
		if pu.global_position.distance_to(ai_base_pos) <= 320.0:
			enemy_near_base += 1
			closest_intruder = pu

	var combat_units: Array = []
	for u in ai_units:
		if u.stats == null or u.stats.id != "engineerbot":
			combat_units.append(u)

	var wave_size := AI.attack_wave_threshold(GameManager.ai_difficulty, elapsed_time / 60.0)
	ai_tactical_state = AI.choose_tactical_state(combat_units.size(), enemy_near_base, wave_size)

	var primary_target_pos := Vector2(160, 160)
	var weak_target := _find_priority_target_for_team(1)
	if weak_target != null:
		primary_target_pos = weak_target.global_position

	var rally_pos := Vector2(880, 720)
	var offsets := Formation.grid_offsets(combat_units.size(), 30.0)
	for i in range(combat_units.size()):
		var u: Node2D = combat_units[i]
		var max_hp := float(u.stats.hp if u.stats else 100)
		var hp_ratio := float(u.hp) / maxf(1.0, max_hp)
		if AI.retreat_threshold(hp_ratio, 0.28):
			u.move_to(ai_base_pos + Vector2(-40, -40), false)
			continue
		match ai_tactical_state:
			"defend":
				var def_pos := closest_intruder.global_position if closest_intruder != null else ai_base_pos
				u.move_to(def_pos + offsets[i] * 0.5, true)
			"attack":
				u.move_to(primary_target_pos + offsets[i], true)
			"harass":
				if i % 2 == 0:
					u.move_to(primary_target_pos + offsets[i], true)
				else:
					u.move_to(rally_pos + offsets[i], true)
			_:
				if not u.has_target:
					u.move_to(rally_pos + offsets[i], true)

func _get_team_units(team: int) -> Array:
	var res: Array = []
	for u in units_container.get_children():
		if is_instance_valid(u) and not u.is_exploding and u.team == team:
			res.append(u)
	return res

func _classify_units(unit_list: Array) -> Dictionary:
	var counts := {"infantry": 0, "vehicle": 0, "naval": 0, "air": 0}
	for u in unit_list:
		if not is_instance_valid(u) or u.stats == null:
			counts["infantry"] += 1
			continue
		match u.stats.unit_class:
			1: counts["vehicle"] += 1
			2: counts["naval"] += 1
			3: counts["air"] += 1
			_: counts["infantry"] += 1
	return counts

func _get_team_building_counts(team: int) -> Dictionary:
	var d: Dictionary = {}
	for b in get_tree().get_nodes_in_group("buildings"):
		if is_instance_valid(b) and not b.is_exploding and b.team == team and b.stats:
			var bid: String = b.stats.id
			d[bid] = int(d.get(bid, 0)) + 1
	return d

func _count_team_buildings(team: int, bid: String) -> int:
	return int(_get_team_building_counts(team).get(bid, 0))

func _update_hud() -> void:
	if is_instance_valid(hud_label):
		var w := ResourceManager.get_wallet(0)
		var r := ResourceManager.rates.get(0, {})
		var p_units := _get_team_units(0).size()
		var p_cap := int(ResourceManager.caps.get(0, 20))
		hud_label.text = "Corp: %s | Tech: T%d | Oil: %d (+%d/s) | Iron: %d (+%d/s) | Geo: %d (+%d/s) | Food: %d | Units: %d/%d" % [
			Faction.name_of(GameManager.player_faction),
			player_tech_tier,
			int(w.get(Economy.Res.OIL, 0)), int(r.get(Economy.Res.OIL, 0)),
			int(w.get(Economy.Res.IRON, 0)), int(r.get(Economy.Res.IRON, 0)),
			int(w.get(Economy.Res.GEOTHERMAL, 0)), int(r.get(Economy.Res.GEOTHERMAL, 0)),
			int(w.get(Economy.Res.FOOD, 0)),
			p_units, p_cap
		]
	if is_instance_valid(ai_status_label):
		var ai_units := _get_team_units(1).size()
		var mode_str := "Single Player vs %s AI (%s)" % [AI.difficulty_name(GameManager.ai_difficulty), Faction.name_of(GameManager.ai_faction)] if GameManager.match_mode == GameManager.Mode.SINGLE_PLAYER else "Multiplayer P2P"
		ai_status_label.text = "%s | AI Posture: %s | AI Units: %d | AI Tech: T%d" % [
			mode_str, ai_tactical_state.to_upper(), ai_units, ai_tech_tier
		]

func _check_win():
	if not is_instance_valid(status_label):
		return
	var teams := {}
	for u in units_container.get_children():
		if is_instance_valid(u) and not u.is_exploding:
			teams[u.team] = teams.get(u.team, 0) + 1
	for b in get_tree().get_nodes_in_group("buildings"):
		if is_instance_valid(b) and not b.is_exploding:
			teams[b.team] = teams.get(b.team, 0) + 1
	if teams.size() == 1:
		var t = teams.keys()[0]
		status_label.text = "Team %d wins!" % t
		match_over = true
	elif teams.size() == 0:
		status_label.text = "Draw"
		match_over = true

func _draw():
	# Scorch marks from blown-up units and buildings
	for s in scorch_marks:
		draw_circle(s["pos"], float(s["radius"]), Color(0.1, 0.09, 0.08, float(s["alpha"])))

	# Weapon projectile tracers & impact sparks
	for tr in active_tracers:
		var frac := clampf(1.0 - float(tr["timer"]) / maxf(0.01, float(tr["duration"])), 0.0, 1.0)
		var head: Vector2 = tr["from"].lerp(tr["to"], minf(1.0, frac * 1.35))
		var tail: Vector2 = tr["from"].lerp(tr["to"], maxf(0.0, frac - 0.35))
		draw_line(tail, head, tr["color"], float(tr["width"]))
		draw_circle(head, float(tr["width"]) * 1.15, Color(1.0, 0.98, 0.85, 0.95))

	# Explosions, Orbital Laser Beams, and Nuclear Mushrooms
	for v in active_vfx:
		var dur := maxf(0.01, float(v.get("duration", 1.0)))
		var prog := clampf(1.0 - float(v["timer"]) / dur, 0.0, 1.0)
		var pos: Vector2 = v["pos"]
		var rad := float(v["radius"])
		match String(v.get("type", "explosion")):
			"laser":
				draw_line(pos - Vector2(0, 600), pos, Color(0.25, 0.95, 1.0, 1.0 - prog), 12.0 * (1.0 - prog * 0.5))
				draw_circle(pos, rad * sin(prog * PI), v["color"])
			"nuke":
				draw_arc(pos, rad * prog * 1.25, 0, TAU, 36, Color(1.0, 0.85, 0.3, 1.0 - prog), 5.0)
				draw_circle(pos, rad * sin(prog * PI), v["color"])
				draw_circle(pos, rad * 0.55 * sin(prog * PI), Color(1.0, 0.96, 0.75, 1.0 - prog))
			_:
				draw_arc(pos, rad * prog * 1.35, 0, TAU, 24, Color(1.0, 0.8, 0.3, 1.0 - prog), 2.5)
				draw_circle(pos, rad * sin(prog * PI), Color(1.0, 0.45, 0.1, 0.75 * (1.0 - prog)))

	if drag_selecting:
		var r := Rect2(drag_start, drag_current - drag_start).abs()
		draw_rect(r, Color(0.2, 0.9, 0.3, 0.18), true)
		draw_rect(r, Color(0.2, 0.95, 0.3, 0.9), false, 2.0)
