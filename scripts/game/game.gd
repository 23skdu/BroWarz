# scripts/game/game.gd
extends Node2D

const WildlifeRef := preload("res://scripts/core/wildlife.gd")

var map_data: MapData
var selected_units: Array = []
var selected_building: Node2D = null
var control_groups: Dictionary = {}  # key 0..9 -> Array of Unit
var occupied_tiles: Dictionary = {}  # Vector2i -> bool for Placement.can_place_building
var pending_build_id: String = ""
var pending_target_action: String = ""
var resource_deposits: Array[Dictionary] = []
var team_unlocked_tech: Dictionary = {0: [], 1: []}
var alliances: Dictionary = {}
var replay: Replay = Replay.new()
var spatial_grid: Dictionary = {}
var spatial_positions: Array = []
var tactical_pings: Array[Dictionary] = []
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

var terrain_image: Image
var terrain_texture: ImageTexture
var terrain_sprite: Sprite2D
var forest_decorations: Array = []  # Array of Dictionary {pos, kind, radius, shade}
var wildlife_herd: Array[Dictionary] = []

const TILE_SIZE: float = 16.0
const TERRAIN_PPT: int = 4
var fog: FogOfWar
var fog_image: Image
var fog_texture: ImageTexture
var fog_sprite: Sprite2D

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
	_generate_map(GameManager.map_type)
	terrain_image = UnitVisual.build_terrain_map_image(map_data, TERRAIN_PPT)
	terrain_texture = ImageTexture.create_from_image(terrain_image)
	terrain_sprite = Sprite2D.new()
	terrain_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	terrain_sprite.texture = terrain_texture
	terrain_sprite.scale = Vector2(TILE_SIZE / float(TERRAIN_PPT), TILE_SIZE / float(TERRAIN_PPT))
	terrain_sprite.centered = false
	terrain_sprite.z_index = -5
	add_child(terrain_sprite)
	_rebuild_forest_decorations()
	_spawn_resource_deposits()
	wildlife_herd = WildlifeRef.spawn_ambient_herd(map_data, GameManager.match_seed, 10)
	GameManager.active_clouds = Cover.spawn_clouds(float(map_data.width) * TILE_SIZE, float(map_data.height) * TILE_SIZE, GameManager.match_seed, 8)
	fog = FogOfWar.new(128, 128, map_data)
	fog_image = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	fog_texture = ImageTexture.create_from_image(fog_image)
	fog_sprite = Sprite2D.new()
	fog_sprite.texture = fog_texture
	fog_sprite.scale = Vector2(TILE_SIZE, TILE_SIZE)
	fog_sprite.centered = false
	fog_sprite.z_index = 10
	add_child(fog_sprite)
	camera = $Camera2D
	camera.position = Vector2(360, 300)
	_setup_hud()
	_init_economies()
	_spawn_starting_bases()
	GameManager.start_match(map_data)
	NetworkManager.attach_game(self)
	AudioManager.set_music("battle")

func _generate_map(map_type: int = 2) -> void:
	if map_type == 3:
		if GameManager.current_map != null:
			map_data = GameManager.current_map
			return
		var loaded := MapSerializer.load_from_file("user://custom_map.bwm")
		if loaded != null:
			map_data = loaded
			return
	var gen := TerrainGenerator.generate_forest(128, 128, GameManager.match_seed)
	match map_type:
		0:
			gen = TerrainGenerator.generate_desert(128, 128, GameManager.match_seed)
		1:
			gen = TerrainGenerator.generate_islands(128, 128, GameManager.match_seed)
		_:
			gen = TerrainGenerator.generate_forest(128, 128, GameManager.match_seed)
	map_data = gen

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
	_affect_wildlife_from_fire(from_pos, to_pos, 14.0)
	queue_redraw()

func _affect_wildlife_from_fire(from_pos: Vector2, to_pos: Vector2, dmg: float) -> void:
	for cr in wildlife_herd:
		if not bool(cr.get("alive", true)):
			continue
		var cpos: Vector2 = cr["pos"]
		if cpos.distance_to(to_pos) <= 20.0:
			var died: bool = WildlifeRef.apply_damage(cr, dmg, from_pos)
			if died:
				spawn_explosion_vfx(cpos, 10.0)
		elif cpos.distance_to(to_pos) <= 130.0 or cpos.distance_to(from_pos) <= 130.0:
			cr["flee_timer"] = 3.0
			var away := (cpos - to_pos).normalized()
			if away.length_squared() < 0.01:
				away = Vector2.RIGHT
			cr["vel"] = away * WildlifeRef.flee_speed(int(cr["kind"]))

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
	help_label.text = (
		"[LMB/Drag] Select | [RMB] Move/Attack-Move | [1-7] Train | "
		+ "[E] Embark | [U] Disembark | [B/V] Build | [T] Tech Up | [L] Laser | [N] Nuke"
	)
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
	_add_cmd_button(btn_bar, "Train Hovercraft [7]", func(): _player_train_unit("hovercraft"))
	_add_cmd_button(btn_bar, "Embark [E]", func(): _player_embark_selected())
	_add_cmd_button(btn_bar, "Disembark [U]", func(): _player_disembark_selected())
	_add_cmd_button(btn_bar, "Build Extractor [B]", func(): _enter_build_mode("extractor"))
	_add_cmd_button(btn_bar, "Build Turret [V]", func(): _enter_build_mode("turret"))
	_add_cmd_button(btn_bar, "Build Power [P]", func(): _enter_build_mode("power_plant"))
	_add_cmd_button(btn_bar, "Cancel Queue [X]", func(): _cancel_selected_building_queue())
	_add_cmd_button(btn_bar, "Tech Up [T]", func(): _player_upgrade_tech())
	_add_cmd_button(btn_bar, "Orbital Laser [L]", func(): _enter_target_mode("laser"))
	_add_cmd_button(btn_bar, "Nuclear Strike [N]", func(): _enter_target_mode("nuke"))
	_add_cmd_button(btn_bar, "Save [F5]", func(): quicksave_match())
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
	var uf = GameManager.player_faction if team == 0 else GameManager.ai_faction
	var body = u.get_node_or_null("Body")
	if body:
		body.color = Faction.color_of(uf)
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
	var bf = GameManager.player_faction if team == 0 else GameManager.ai_faction
	var bbody = b.get_node_or_null("Body")
	if bbody:
		bbody.color = Faction.color_of(bf)
	b.global_position = pos
	add_child(b)
	GameManager.register_fort_block(b)
	return b

func _world_mouse_pos(screen_pos: Vector2) -> Vector2:
	return screen_pos + camera.position - get_viewport_rect().size / 2.0

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_F12:
		_capture_screenshot()
		return
	if event is InputEventMouseButton:
		var world_pos := _world_mouse_pos(event.position)
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed and camera:
			camera.zoom = (camera.zoom * 1.12).clamp(Vector2(0.45, 0.45), Vector2(2.0, 2.0))
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed and camera:
			camera.zoom = (camera.zoom * 0.89).clamp(Vector2(0.45, 0.45), Vector2(2.0, 2.0))
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and Input.is_key_pressed(KEY_ALT):
				tactical_pings.append({"pos": world_pos, "timer": 4.0})
				queue_redraw()
				return
			if event.pressed and not pending_build_id.is_empty():
				if _build_structure_for_team(0, pending_build_id, world_pos):
					pending_build_id = ""
				return
			if event.pressed and not pending_target_action.is_empty():
				if pending_target_action == "laser":
					_player_fire_orbital_laser(world_pos)
				elif pending_target_action == "nuke":
					_player_fire_nuke(world_pos)
				pending_target_action = ""
				return
			if event.pressed:
				drag_selecting = true
				drag_start = world_pos
				drag_current = world_pos
			else:
				drag_selecting = false
				_complete_selection(drag_start, world_pos, Input.is_key_pressed(KEY_SHIFT), event.double_click)
				queue_redraw()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if not pending_build_id.is_empty() or not pending_target_action.is_empty():
				pending_build_id = ""
				pending_target_action = ""
				return
			if is_instance_valid(selected_building) and selected_building.team == 0:
				selected_building.set_rally(world_pos)
			else:
				_issue_move_order(world_pos, Input.is_key_pressed(KEY_A))
	elif event is InputEventMouseMotion and drag_selecting:
		drag_current = _world_mouse_pos(event.position)
		queue_redraw()
	elif event is InputEventKey and event.pressed and not event.echo:
		_handle_hotkey(event)

func _complete_selection(start_p: Vector2, end_p: Vector2, additive: bool, double_click: bool = false) -> void:
	if not additive:
		for u in selected_units:
			if is_instance_valid(u):
				u.selected = false
		selected_units.clear()
		if is_instance_valid(selected_building):
			selected_building.selected = false
		selected_building = null

	if start_p.distance_to(end_p) < 12.0:
		var clicked = _unit_at(end_p)
		if clicked and clicked.team == 0:
			if double_click and clicked.stats:
				for u in _get_team_units(0):
					if u.stats and u.stats.id == clicked.stats.id:
						u.selected = true
						if not selected_units.has(u):
							selected_units.append(u)
			else:
				clicked.selected = true
				if not selected_units.has(clicked):
					selected_units.append(clicked)
		else:
			var bld := _building_at(end_p)
			if bld and bld.team == 0:
				selected_building = bld
				bld.selected = true
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
	if event.keycode >= KEY_0 and event.keycode <= KEY_9 and Input.is_key_pressed(KEY_CTRL):
		var grp := int(event.keycode - KEY_0)
		control_groups[grp] = selected_units.duplicate()
		return
	match event.keycode:
		KEY_1: _player_train_unit("riflebot")
		KEY_2: _player_train_unit("rocketbot")
		KEY_3: _player_train_unit("stealthbot")
		KEY_4: _player_train_unit("mbt")
		KEY_5: _player_train_unit("aa_vehicle")
		KEY_6: _player_train_unit("fighter_drone")
		KEY_7: _player_train_unit("hovercraft")
		KEY_8, KEY_9, KEY_0:
			var grp_id := int(event.keycode - KEY_0)
			if control_groups.has(grp_id):
				for u in selected_units:
					if is_instance_valid(u):
						u.selected = false
				selected_units.clear()
				for u in control_groups[grp_id]:
					if is_instance_valid(u) and not u.is_exploding:
						u.selected = true
						selected_units.append(u)
		KEY_E: _player_embark_selected()
		KEY_U: _player_disembark_selected()
		KEY_X: _cancel_selected_building_queue()
		KEY_B: _enter_build_mode("extractor")
		KEY_V: _enter_build_mode("turret")
		KEY_P: _enter_build_mode("power_plant")
		KEY_T: _player_upgrade_tech()
		KEY_L: _enter_target_mode("laser")
		KEY_N: _enter_target_mode("nuke")
		KEY_F5: quicksave_match()
		KEY_F9: quickload_match()
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

func _player_embark_selected() -> int:
	return _embark_units_for_team(0, selected_units)

func _player_disembark_selected() -> int:
	return _disembark_units_for_team(0, selected_units)

func _embark_units_for_team(team: int, candidates: Array) -> int:
	var transports: Array = []
	for u in _get_team_units(team):
		if u.has_method("transport_capacity") and u.transport_capacity() > 0:
			transports.append(u)
	if transports.is_empty():
		return 0
	var loaded := 0
	for u in candidates.duplicate():
		if not is_instance_valid(u) or u.is_exploding or u.team != team:
			continue
		if u.has_method("transport_capacity") and u.transport_capacity() > 0:
			continue
		var best_t: Node2D = null
		var best_d := 140.0
		for t in transports:
			var t_node: Node2D = t
			if t_node.can_load_passenger(u):
				var d: float = (u as Node2D).global_position.distance_to(t_node.global_position)
				if d <= best_d:
					best_d = d
					best_t = t_node
		if best_t != null and best_t.embark_passenger(u):
			selected_units.erase(u)
			loaded += 1
	if loaded > 0 and is_instance_valid(status_label):
		status_label.text = "Embarked %d unit(s) into transport" % loaded
	return loaded

func _disembark_units_for_team(team: int, candidates: Array) -> int:
	var unloaded := 0
	var list := candidates if not candidates.is_empty() else _get_team_units(team)
	for u in list:
		if is_instance_valid(u) and not u.is_exploding and u.team == team and u.has_method("disembark_all"):
			unloaded += u.disembark_all()
	if unloaded > 0 and is_instance_valid(status_label):
		status_label.text = "Disembarked %d unit(s)" % unloaded
	return unloaded

func apply_command(cmd: Dictionary) -> bool:
	var ctype := String(cmd.get("type", ""))
	var team := int(cmd.get("team", GameManager.local_team))
	match ctype:
		"train":
			return _train_unit_for_team(team, String(cmd.get("id", "")))
		"build", "fortify":
			return _build_structure_for_team(team, String(cmd.get("id", "")))
		"embark":
			return _embark_units_for_team(team, _get_team_units(team)) > 0
		"disembark":
			return _disembark_units_for_team(team, _get_team_units(team)) > 0
		"move":
			var tx := float(cmd.get("target_x", 0.0))
			var ty := float(cmd.get("target_y", 0.0))
			var am := bool(cmd.get("attack_move", true))
			for u in _get_team_units(team):
				u.move_to(Vector2(tx, ty), am)
			return true
		"hold", "stop":
			for u in _get_team_units(team):
				u.stop_command()
				u.hold_position = (ctype == "hold")
			return true
	return false

func _train_unit_for_team(team: int, uid: String) -> bool:
	var s := GameManager.registry.get_unit(uid)
	if s == null:
		return false
	var wallet := ResourceManager.get_wallet(team)
	var fac_id := GameManager.player_faction if team == 0 else GameManager.ai_faction
	var cost := _wallet_cost(Faction.effective_unit_cost(fac_id, s))
	if not Economy.spend(wallet, cost):
		return false
	var producer: Node2D = null
	var valid_producers := UnitRegistry.producer_ids_for_unit(uid, s.unit_class)
	for b in get_tree().get_nodes_in_group("buildings"):
		if is_instance_valid(b) and not b.is_exploding and b.team == team:
			if b.stats and b.stats.id in valid_producers:
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

func _enter_build_mode(bid: String) -> void:
	pending_target_action = ""
	pending_build_id = bid
	if is_instance_valid(status_label):
		status_label.text = "Place %s: Left-Click map to build, Right-Click to cancel" % bid

func _enter_target_mode(action: String) -> void:
	pending_build_id = ""
	pending_target_action = action
	if is_instance_valid(status_label):
		status_label.text = "Target %s: Left-Click coordinates, Right-Click to cancel" % action.to_upper()

func _cancel_selected_building_queue() -> void:
	if is_instance_valid(selected_building) and selected_building.team == 0 and selected_building.has_method("cancel_last_queued"):
		var cancelled: String = selected_building.cancel_last_queued()
		if not cancelled.is_empty() and is_instance_valid(status_label):
			status_label.text = "Cancelled queued %s" % cancelled

func _team_has_builder_for(team: int, bid: String) -> bool:
	if not UnitRegistry.requires_advanced_builder(bid):
		return true
	for u in _get_team_units(team):
		if u.stats and UnitRegistry.can_unit_construct(u.stats.id, bid):
			return true
	return false

func _build_structure_for_team(team: int, bid: String, world_pos: Vector2 = Vector2.INF) -> bool:
	var bs := GameManager.registry.get_building(bid)
	if bs == null:
		return false
	if not _team_has_builder_for(team, bid):
		return false
	var target_pos := world_pos
	if target_pos == Vector2.INF:
		var base_pos := Vector2(160, 160) if team == 0 else Vector2(1080, 880)
		var count := _count_team_buildings(team, bid)
		var offset := Vector2((count % 4) * 58.0 - 60.0, floorf(float(count) / 4.0) * 58.0 + 75.0)
		if team == 1:
			offset = -offset
		target_pos = base_pos + offset
	elif map_data != null:
		var origin := Vector2i(int(target_pos.x / TILE_SIZE), int(target_pos.y / TILE_SIZE))
		if not Placement.can_place_building(map_data, bid, bs.footprint, origin, occupied_tiles):
			if team == 0 and is_instance_valid(status_label):
				status_label.text = "Cannot place %s here (blocked or invalid terrain)" % bid
			return false
		Placement.occupy(occupied_tiles, bs.footprint, origin)
	var wallet := ResourceManager.get_wallet(team)
	var cost := _wallet_cost(bs.cost_dict())
	if not Economy.spend(wallet, cost):
		return false
	_spawn_building_by_id(bid, target_pos, team)
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
	var unlocked: Array = team_unlocked_tech.get(0, [])
	var avail := Tech.available_nodes(unlocked)
	if not avail.is_empty():
		var nid := avail[0]
		var info := Tech.node_info(nid)
		var n_cost: Dictionary = info.get("cost", {})
		if Tech.research_cost_affordable(wallet, n_cost) and Economy.spend(wallet, n_cost):
			Tech.unlock(unlocked, nid)
			team_unlocked_tech[0] = unlocked
			player_tech_tier = mini(4, player_tech_tier + 1)
			AudioManager.play_sfx("tech_up")
			if is_instance_valid(status_label):
				status_label.text = "Researched %s!" % String(info.get("name", nid))
			return
	var cost := {Economy.Res.OIL: 100 * player_tech_tier, Economy.Res.IRON: 180 * player_tech_tier, Economy.Res.GEOTHERMAL: 60 * player_tech_tier}
	if Economy.spend(wallet, cost):
		player_tech_tier += 1
		AudioManager.play_sfx("tech_up")

func _player_fire_orbital_laser(world_target: Vector2 = Vector2.INF) -> void:
	if laser_cooldown > 0.0:
		return
	var wallet := ResourceManager.get_wallet(0)
	if not Economy.spend(wallet, {Economy.Res.GEOTHERMAL: 100, Economy.Res.OIL: 60}):
		return
	var mods := Faction.modifiers(GameManager.player_faction)
	laser_cooldown = 25.0 * float(mods.get("orbital_cooldown", 1.0))
	var target_pos := world_target
	if target_pos == Vector2.INF:
		target_pos = Vector2(1060, 860)
		var enemy := _find_priority_target_for_team(0)
		if enemy != null:
			target_pos = enemy.global_position
	var dmg := Strategic.orbital_laser_damage(180.0, float(wallet.get(Economy.Res.GEOTHERMAL, 0)))
	_apply_aoe_damage(target_pos, 95.0, dmg, 0)
	active_vfx.append({"type": "laser", "pos": target_pos, "radius": 95.0, "color": Color(0.2, 0.95, 1.0, 0.75), "timer": 1.2, "duration": 1.2})
	AudioManager.play_sfx("orbital_laser")

func _player_fire_nuke(world_target: Vector2 = Vector2.INF) -> void:
	if nuke_cooldown > 0.0:
		return
	var wallet := ResourceManager.get_wallet(0)
	if not Economy.spend(wallet, {Economy.Res.GEOTHERMAL: 200, Economy.Res.IRON: 300, Economy.Res.OIL: 180}):
		return
	nuke_cooldown = 45.0
	var target_pos := world_target
	if target_pos == Vector2.INF:
		target_pos = Vector2(1100, 900)
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
	_update_terrain_image()
	active_vfx.append({"type": "nuke", "pos": target_pos, "radius": 180.0, "color": Color(1.0, 0.45, 0.1, 0.8), "timer": 2.0, "duration": 2.0})
	AudioManager.play_sfx("nuclear_launch")

func _apply_aoe_damage(center: Vector2, radius: float, dmg: float, attacker_team: int) -> void:
	for u in get_tree().get_nodes_in_group("units"):
		if is_instance_valid(u) and not u.is_exploding and u.team != attacker_team and u.global_position.distance_to(center) <= radius:
			u.take_damage(dmg)
	for b in get_tree().get_nodes_in_group("buildings"):
		if is_instance_valid(b) and not b.is_exploding and b.team != attacker_team and b.global_position.distance_to(center) <= radius:
			b.take_damage(dmg)
	for cr in wildlife_herd:
		if bool(cr.get("alive", true)) and Vector2(cr["pos"]).distance_to(center) <= radius:
			WildlifeRef.apply_damage(cr, dmg, center)

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

func _building_at(pos: Vector2) -> Node2D:
	for b in get_tree().get_nodes_in_group("buildings"):
		if is_instance_valid(b) and not ("is_exploding" in b and b.is_exploding) and b.global_position.distance_to(pos) < 28.0:
			return b
	return null

func get_team_power_summary(team: int) -> Dictionary:
	var bids: Array = []
	for b in get_tree().get_nodes_in_group("buildings"):
		if is_instance_valid(b) and not ("is_exploding" in b and b.is_exploding) and b.team == team and b.stats:
			bids.append(b.stats.id)
	return Power.team_power_summary(bids)

func get_team_power_efficiency(team: int) -> float:
	return float(get_team_power_summary(team).get("efficiency", 1.0))

func _spawn_resource_deposits() -> void:
	resource_deposits.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = GameManager.match_seed ^ 0x10B4
	for i in range(16):
		var tx := rng.randi_range(6, 120)
		var ty := rng.randi_range(6, 120)
		var dep := ResourceDeposit.new()
		dep.type = i % 4
		dep.amount = 1500
		dep.harvest_rate = 10.0
		resource_deposits.append({"pos": Vector2(float(tx) * TILE_SIZE + 8.0, float(ty) * TILE_SIZE + 8.0), "deposit": dep})

func quicksave_match(path: String = "user://saves/quicksave.bws") -> Error:
	DirAccess.make_dir_recursive_absolute("user://saves")
	var gs := GameState.new()
	gs.tick = int(elapsed_time * 20.0)
	gs.resources = {0: ResourceManager.get_wallet(0).duplicate(), 1: ResourceManager.get_wallet(1).duplicate()}
	for u in units_container.get_children():
		if is_instance_valid(u) and not u.is_exploding and u.stats:
			gs.units.append({"id": u.stats.id, "team": u.team, "x": u.global_position.x, "y": u.global_position.y, "hp": u.hp})
	var sg := SaveGame.new()
	sg.game_state = gs.snapshot()
	sg.settings = {"elapsed_time": elapsed_time, "player_tech_tier": player_tech_tier}
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(sg.to_dict()))
	f.close()
	if is_instance_valid(status_label):
		status_label.text = "Match saved to %s" % path
	return OK

func quickload_match(path: String = "user://saves/quicksave.bws") -> bool:
	if not FileAccess.file_exists(path):
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary):
		return false
	var sg := SaveGame.from_dict(parsed as Dictionary)
	var gs := GameState.from_snapshot(sg.game_state)
	elapsed_time = float(sg.settings.get("elapsed_time", elapsed_time))
	player_tech_tier = int(sg.settings.get("player_tech_tier", player_tech_tier))
	if is_instance_valid(status_label):
		status_label.text = "Loaded save (tick %d, %d units)" % [gs.tick, gs.units.size()]
	return true

func _process(delta):
	elapsed_time += delta
	laser_cooldown = maxf(0.0, laser_cooldown - delta)
	nuke_cooldown = maxf(0.0, nuke_cooldown - delta)

	for i in range(active_vfx.size() - 1, -1, -1):
		active_vfx[i]["timer"] = float(active_vfx[i]["timer"]) - delta
		if float(active_vfx[i]["timer"]) <= 0.0:
			active_vfx.remove_at(i)

	for i in range(active_tracers.size() - 1, -1, -1):
		active_tracers[i]["timer"] = float(active_tracers[i]["timer"]) - delta
		if float(active_tracers[i]["timer"]) <= 0.0:
			active_tracers.remove_at(i)

	_update_wildlife(delta)
	if map_data != null:
		Cover.step_clouds(GameManager.active_clouds, float(map_data.width) * TILE_SIZE, float(map_data.height) * TILE_SIZE, delta)
	for i in range(tactical_pings.size() - 1, -1, -1):
		tactical_pings[i]["timer"] = float(tactical_pings[i]["timer"]) - delta
		if float(tactical_pings[i]["timer"]) <= 0.0:
			tactical_pings.remove_at(i)
	spatial_positions.clear()
	for u in units_container.get_children():
		if is_instance_valid(u) and not u.is_exploding:
			spatial_positions.append(u.global_position)
	spatial_grid = UnitVisual.build_spatial_grid(spatial_positions, UnitVisual.SpatialCellSize)
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

	# Hovercraft eel hazard
	for u in units_container.get_children():
		if is_instance_valid(u) and not u.is_exploding and u.stats and u.stats.id == "hovercraft":
			if u.eel_timer <= 0.0 and randf() < 0.0008:
				u.trigger_eels()
				if is_instance_valid(status_label):
					status_label.text = "My Hovercraft is full of eels!"
				AudioManager.play_sfx("eel_hazard")
	_update_fog()
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
		var r: Dictionary = ResourceManager.rates.get(0, {})
		var p_units := _get_team_units(0).size()
		var p_cap := int(ResourceManager.caps.get(0, 20))
		var pwr := get_team_power_summary(0)
		var pwr_pct := int(round(float(pwr["efficiency"]) * 100.0))
		hud_label.text = "Corp: %s | Tech: T%d | Pwr: %+d (%d%%) | Oil: %d (+%d/s) | Iron: %d (+%d/s) | Geo: %d (+%d/s) | Food: %d | Units: %d/%d" % [
			Faction.name_of(GameManager.player_faction),
			player_tech_tier,
			int(round(float(pwr["balance"]))), pwr_pct,
			int(w.get(Economy.Res.OIL, 0)), int(r.get(Economy.Res.OIL, 0)),
			int(w.get(Economy.Res.IRON, 0)), int(r.get(Economy.Res.IRON, 0)),
			int(w.get(Economy.Res.GEOTHERMAL, 0)), int(r.get(Economy.Res.GEOTHERMAL, 0)),
			int(w.get(Economy.Res.FOOD, 0)),
			p_units, p_cap
		]
	if is_instance_valid(ai_status_label):
		var ai_units := _get_team_units(1).size()
		var mode_str := "Single Player vs %s AI (%s)" % [
			AI.difficulty_name(GameManager.ai_difficulty),
			Faction.name_of(GameManager.ai_faction),
		] if GameManager.match_mode == GameManager.Mode.SINGLE_PLAYER else "Multiplayer P2P"
		ai_status_label.text = "%s | AI Posture: %s | AI Units: %d | AI Tech: T%d" % [
			mode_str, ai_tactical_state.to_upper(), ai_units, ai_tech_tier
		]

func _check_win():
	if not is_instance_valid(status_label):
		return
	# Primary victory: capture/destroy all enemy production buildings
	# (barracks, factories, airfields, shipyards). Units alone cannot
	# sustain a faction once production is gone.
	var production_ids := [
		"barracks", "factory", "airfield", "shipyard",
		"docks", "mech_factory_1", "mech_factory_2", "mech_factory_3",
		"advanced_shipyard", "aeries_1", "aeries_2",
	]
	var alive_teams := {}
	for b in get_tree().get_nodes_in_group("buildings"):
		if is_instance_valid(b) and not b.is_exploding:
			if b.stats and production_ids.has(b.stats.id):
				alive_teams[b.team] = alive_teams.get(b.team, 0) + 1
	if alive_teams.size() == 1:
		var t = alive_teams.keys()[0]
		var w0 := ResourceManager.get_wallet(0)
		var eco_sum := int(w0.get(Economy.Res.OIL, 0)) + int(w0.get(Economy.Res.IRON, 0)) + int(w0.get(Economy.Res.GEOTHERMAL, 0))
		var mil := Score.military_score(_get_team_units(0).size(), _get_team_building_counts(0).size())
		var tot := Score.total(mil, Score.economic_score(eco_sum))
		status_label.text = "Team %d wins! | Score: %d (Mil %d + Eco %d)" % [t, tot, mil, eco_sum]
		match_over = true
	elif alive_teams.size() == 0:
		status_label.text = "Draw"
		match_over = true

func _draw():
	# Minimal forest tree canopies and shrubs
	for dec in forest_decorations:
		var dpos: Vector2 = dec["pos"]
		var rad := float(dec["radius"])
		var shade := float(dec["shade"])
		draw_circle(dpos + Vector2(2, 2), rad, Color(0.04, 0.08, 0.04, 0.42))
		if dec["kind"] == "tree":
			draw_circle(dpos, rad, Color(0.12 + shade, 0.34 + shade, 0.14 + shade, 0.92))
			draw_circle(dpos - Vector2(1.5, 1.5), rad * 0.58, Color(0.22 + shade, 0.48 + shade, 0.22 + shade, 0.95))
		else:
			draw_circle(dpos, rad, Color(0.18 + shade, 0.40 + shade, 0.17 + shade, 0.88))

	# On-map finite resource deposits
	for rd in resource_deposits:
		var dep: ResourceDeposit = rd["deposit"]
		if dep.is_depleted():
			continue
		var rpos: Vector2 = rd["pos"]
		var rcol := Color(0.15, 0.15, 0.15, 0.9)
		match dep.type:
			Economy.Res.IRON: rcol = Color(0.65, 0.72, 0.85, 0.9)
			Economy.Res.GEOTHERMAL: rcol = Color(1.0, 0.45, 0.15, 0.9)
			Economy.Res.FOOD: rcol = Color(0.35, 0.85, 0.35, 0.9)
		draw_circle(rpos, 8.0, rcol)
		draw_arc(rpos, 10.0, 0, TAU, 16, rcol.lightened(0.3), 1.5)

	# Scorch marks from blown-up units and buildings
	for s in scorch_marks:
		draw_circle(s["pos"], float(s["radius"]), Color(0.1, 0.09, 0.08, float(s["alpha"])))

	# Ambient non-combatant wildlife (Deer, Dolphins, Squid, Birds)
	for cr in wildlife_herd:
		_draw_wildlife_critter(cr)

	# Weapon projectile tracers & impact sparks
	for tracer in active_tracers:
		var frac := clampf(1.0 - float(tracer["timer"]) / maxf(0.01, float(tracer["duration"])), 0.0, 1.0)
		var head: Vector2 = tracer["from"].lerp(tracer["to"], minf(1.0, frac * 1.35))
		var tail: Vector2 = tracer["from"].lerp(tracer["to"], maxf(0.0, frac - 0.35))
		draw_line(tail, head, tracer["color"], float(tracer["width"]))
		draw_circle(head, float(tracer["width"]) * 1.15, Color(1.0, 0.98, 0.85, 0.95))

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

	# Drifting cloud formations (affecting only aerial units)
	for cl in GameManager.active_clouds:
		var cpos: Vector2 = cl["pos"]
		var rad := float(cl.get("radius", 90.0))
		var calpha := float(cl.get("alpha", 0.32))
		# Soft ground shadow + multi-puff cloud canopy
		draw_circle(cpos + Vector2(14, 18), rad * 0.85, Color(0.03, 0.05, 0.08, calpha * 0.38))
		draw_circle(cpos, rad * 0.78, Color(0.94, 0.97, 1.0, calpha))
		draw_circle(cpos + Vector2(-rad * 0.35, rad * 0.12), rad * 0.56, Color(0.92, 0.96, 1.0, calpha * 0.92))
		draw_circle(cpos + Vector2(rad * 0.36, -rad * 0.10), rad * 0.58, Color(0.96, 0.98, 1.0, calpha * 0.92))
		draw_circle(cpos + Vector2(0, -rad * 0.25), rad * 0.52, Color(1.0, 1.0, 1.0, calpha * 0.95))

	# Interactive placement ghost & tactical cursor/pings
	if not pending_build_id.is_empty() and map_data != null:
		var mpos := _world_mouse_pos(get_viewport().get_mouse_position())
		var origin := Vector2i(int(mpos.x / TILE_SIZE), int(mpos.y / TILE_SIZE))
		var bs := GameManager.registry.get_building(pending_build_id)
		var fp := bs.footprint if bs != null else Vector2i(2, 2)
		var ok := Placement.can_place_building(map_data, pending_build_id, fp, origin, occupied_tiles)
		var gcol := Color(0.2, 1.0, 0.35, 0.45) if ok else Color(1.0, 0.2, 0.2, 0.45)
		draw_rect(Rect2(float(origin.x) * TILE_SIZE, float(origin.y) * TILE_SIZE, float(fp.x) * TILE_SIZE, float(fp.y) * TILE_SIZE), gcol, true)
	if not pending_target_action.is_empty():
		var tpos := _world_mouse_pos(get_viewport().get_mouse_position())
		var r_sz := 95.0 if pending_target_action == "laser" else 180.0
		draw_arc(tpos, r_sz, 0, TAU, 32, Color(1.0, 0.3, 0.2, 0.85), 2.5)
	for ping in tactical_pings:
		var ppos: Vector2 = ping["pos"]
		var pt := float(ping["timer"])
		draw_arc(ppos, 18.0 + (4.0 - pt) * 8.0, 0, TAU, 20, Color(0.2, 0.95, 1.0, clampf(pt * 0.25, 0.0, 1.0)), 2.5)

func _update_fog() -> void:
	if fog == null:
		return
	var team := my_team()
	if not GameManager.fog_enabled:
		fog_sprite.visible = false
		for u in units_container.get_children():
			if is_instance_valid(u):
				u.visible = true
		for b in get_tree().get_nodes_in_group("buildings"):
			if is_instance_valid(b):
				b.visible = true
		return
	fog_sprite.visible = true
	fog.reset_visibility()
	for u in units_container.get_children():
		if is_instance_valid(u) and GameManager.is_allied(team, u.team):
			var tx := int(u.global_position.x / TILE_SIZE)
			var ty := int(u.global_position.y / TILE_SIZE)
			var sight_tiles := 8
			if u.stats:
				sight_tiles = int(u.stats.sight / TILE_SIZE)
			fog.mark_visible(tx, ty, sight_tiles)
	for b in get_tree().get_nodes_in_group("buildings"):
		if is_instance_valid(b) and GameManager.is_allied(team, b.team):
			var tx := int(b.global_position.x / TILE_SIZE)
			var ty := int(b.global_position.y / TILE_SIZE)
			fog.mark_visible(tx, ty, 5)
	for y in range(128):
		for x in range(128):
			var col := Color(0, 0, 0, 0.9)
			if fog.is_visible(x, y):
				col = Color(0, 0, 0, 0.0)
			elif fog.is_explored(x, y):
				col = Color(0, 0, 0, 0.45)
			fog_image.set_pixel(x, y, col)
	fog_texture.update(fog_image)
	for u in units_container.get_children():
		if is_instance_valid(u):
			if GameManager.is_allied(team, u.team):
				u.visible = true
			else:
				var tx := int(u.global_position.x / TILE_SIZE)
				var ty := int(u.global_position.y / TILE_SIZE)
				u.visible = fog.is_visible(tx, ty)

func _terrain_color(t: int) -> Color:
	match t:
		MapData.Terrain.PLAINS: return Color(0.35, 0.55, 0.25)
		MapData.Terrain.FOREST: return Color(0.18, 0.4, 0.18)
		MapData.Terrain.SWAMP: return Color(0.3, 0.35, 0.2)
		MapData.Terrain.RIVER: return Color(0.2, 0.4, 0.75)
		MapData.Terrain.SEA: return Color(0.1, 0.25, 0.55)
		MapData.Terrain.MOUNTAIN: return Color(0.5, 0.5, 0.5)
		MapData.Terrain.URBAN: return Color(0.45, 0.4, 0.35)
		MapData.Terrain.ROAD: return Color(0.6, 0.55, 0.4)
		MapData.Terrain.BRIDGE: return Color(0.6, 0.5, 0.3)
		MapData.Terrain.WASTELAND: return Color(0.35, 0.2, 0.15)
		MapData.Terrain.DESERT: return Color(0.76, 0.65, 0.38)
		MapData.Terrain.HILLS: return Color(0.45, 0.50, 0.28)
	return Color(0.3, 0.3, 0.3)

func _update_terrain_image() -> void:
	if map_data == null:
		return
	terrain_image = UnitVisual.build_terrain_map_image(map_data, TERRAIN_PPT)
	if terrain_texture:
		terrain_texture = ImageTexture.create_from_image(terrain_image)
		if terrain_sprite:
			terrain_sprite.texture = terrain_texture
	_rebuild_forest_decorations()

func _rebuild_forest_decorations() -> void:
	forest_decorations.clear()
	if map_data == null:
		return
	for ty in range(2, map_data.height - 2):
		for tx in range(2, map_data.width - 2):
			if map_data.get_terrain(tx, ty) == MapData.Terrain.FOREST:
				var h := ((tx * 374761393) ^ (ty * 668265263)) & 255
				if (h % 4) == 0:
					var wpos := Vector2(float(tx * 16 + 4 + (h % 8)), float(ty * 16 + 4 + ((h >> 3) % 8)))
					forest_decorations.append({
						"pos": wpos,
						"kind": "tree" if (h % 2 == 0) else "shrub",
						"radius": 6.2 if (h % 2 == 0) else 3.8,
						"shade": float(h % 10) * 0.015,
					})

func _update_wildlife(delta: float) -> void:
	var threats: Array = []
	for u in units_container.get_children():
		if is_instance_valid(u) and not u.is_exploding:
			threats.append(u.global_position)
	for i in range(wildlife_herd.size() - 1, -1, -1):
		var cr: Dictionary = wildlife_herd[i]
		WildlifeRef.step_critter(cr, map_data, threats, delta, int(elapsed_time * 10.0) + i)
		if not bool(cr.get("alive", true)) and float(cr.get("death_timer", 0.0)) <= 0.0:
			wildlife_herd.remove_at(i)

func _draw_wildlife_critter(cr: Dictionary) -> void:
	var cpos: Vector2 = cr["pos"]
	var tx := clampi(int(cpos.x / TILE_SIZE), 0, 127)
	var ty := clampi(int(cpos.y / TILE_SIZE), 0, 127)
	if fog != null and not fog.is_visible(tx, ty):
		return
	var alive := bool(cr.get("alive", true))
	var kind := int(cr.get("kind", WildlifeRef.Kind.DEER))
	var vel: Vector2 = cr.get("vel", Vector2.RIGHT)
	var dir := vel.normalized() if vel.length_squared() > 0.01 else Vector2.RIGHT
	var perp := Vector2(-dir.y, dir.x)
	var phase := float(cr.get("anim_phase", 0.0))

	if not alive:
		var alpha := clampf(float(cr.get("death_timer", 0.0)), 0.0, 1.0)
		draw_circle(cpos, 4.2, Color(0.55, 0.14, 0.12, alpha))
		return

	match kind:
		WildlifeRef.Kind.BIRD:
			var flap := sin(phase * 1.8) * 4.5
			draw_circle(cpos + Vector2(6, 10), 2.4, Color(0, 0, 0, 0.24))
			var wing_l := cpos - dir * 2.0 + perp * (6.2 + flap * 0.4)
			var wing_r := cpos - dir * 2.0 - perp * (6.2 + flap * 0.4)
			draw_line(wing_l, cpos + dir * 2.5, Color(0.95, 0.96, 0.98, 0.95), 1.8)
			draw_line(wing_r, cpos + dir * 2.5, Color(0.95, 0.96, 0.98, 0.95), 1.8)
		WildlifeRef.Kind.DOLPHIN:
			var breach := sin(phase) * 2.0
			draw_arc(cpos, 6.0 + absf(breach), 0, TAU, 16, Color(0.75, 0.95, 1.0, 0.45), 1.2)
			draw_line(cpos - dir * 6.0, cpos + dir * 6.0, Color(0.45, 0.78, 0.92, 0.95), 3.2)
			draw_circle(cpos + dir * 2.0, 2.2, Color(0.32, 0.62, 0.80, 1.0))
		WildlifeRef.Kind.SQUID:
			var pulse := sin(phase * 1.3) * 1.8
			draw_circle(cpos + dir * 3.0, 3.8, Color(0.88, 0.42, 0.58, 0.92))
			for t_i in [-1.0, 0.0, 1.0]:
				var t_end: Vector2 = cpos - dir * (6.5 + pulse) + perp * (float(t_i) * 2.5)
				draw_line(cpos, t_end, Color(0.92, 0.55, 0.68, 0.85), 1.3)
		_:
			var stride := sin(phase * 1.5) * 1.5
			draw_circle(cpos + Vector2(1, 2), 3.2, Color(0, 0, 0, 0.28))
			draw_line(cpos - dir * 4.2, cpos + dir * 4.0, Color(0.68, 0.48, 0.28, 0.96), 3.0)
			draw_circle(cpos + dir * (4.8 + stride * 0.3), 2.2, Color(0.78, 0.58, 0.35, 1.0))
			draw_circle(cpos - dir * 4.8, 1.3, Color(0.95, 0.92, 0.85, 0.95))

func _capture_screenshot() -> void:
	var img := get_viewport().get_texture().get_image()
	if img == null:
		return
	var dir_path := "user://screenshots"
	DirAccess.make_dir_recursive_absolute(dir_path)
	var path := "%s/screenshot_%d.png" % [dir_path, int(Time.get_unix_time_from_system())]
	var err := img.save_png(path)
	if err == OK and is_instance_valid(status_label):
		status_label.text = "Screenshot saved: %s" % path
