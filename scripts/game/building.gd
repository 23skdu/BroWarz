# scripts/game/building.gd
extends StaticBody2D

var stats: BuildingStats
var team: int = 0
var hp: int = 500
var production_queue: Array = []
var rally_point: Vector2 = Vector2.ZERO
var has_rally: bool = false
var turret_timer: float = 0.0
var turret_angle: float = 0.0
var fire_flash_timer: float = 0.0
var selected: bool = false
var is_exploding: bool = false
var explode_timer: float = 0.0
var explosion_debris: Array[Dictionary] = []
var queue_label: Label = null
var _last_queue_text: String = "__init__"
var _last_draw_selected: bool = false
var _last_draw_turret: float = -999.0
var _last_draw_prog: float = -1.0

@onready var body = $Body
@onready var sprite: Sprite2D = $Sprite
@onready var hp_bar = $HpBar

func _ready():
	if stats:
		hp = stats.hp
	production_queue = Production.new_queue()
	rally_point = global_position + Vector2(56, 56) if team == 0 else global_position - Vector2(56, 56)
	add_to_group("buildings")
	refresh_colorblind()
	_refresh_queue_label()

func setup(s: BuildingStats, t: int) -> void:
	stats = s
	team = t
	hp = s.hp
	rally_point = global_position + Vector2(56, 56) if t == 0 else global_position - Vector2(56, 56)
	_refresh_queue_label()
	refresh_colorblind()

## Re-apply the live colorblind palette (called when settings change).
func refresh_colorblind() -> void:
	if body == null:
		return
	var fac_id := GameManager.faction_for_team(team)
	var variant := 0
	var scene = get_tree().current_scene
	if scene != null and scene.has_method("color_variant_for_team"):
		variant = int(scene.color_variant_for_team(team))
	var team_color := Faction.colorblind_color_of(fac_id, SettingsManager.colorblind_palette(), variant)
	var base_c := team_color.darkened(0.12)
	if stats != null and stats.is_hq:
		base_c = base_c.lightened(0.22)
	body.color = base_c
	if sprite != null and stats != null and not stats.id.is_empty():
		sprite.texture = BuildingVisual.get_cached_building_texture(stats.id, team_color)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var footprint := float(maxi(stats.footprint.x, stats.footprint.y))
		sprite.scale = Vector2.ONE * clampf(footprint * 0.42, 0.68, 1.3)

func _refresh_queue_label() -> void:
	if queue_label == null:
		queue_label = Label.new()
		queue_label.name = "QueueLabel"
		queue_label.position = Vector2(-20, 30)
		queue_label.add_theme_font_size_override("font_size", 10)
		add_child(queue_label)
	var next_text := ""
	if not production_queue.is_empty():
		var names: Array = []
		for item in production_queue:
			if item is Dictionary:
				names.append(str(item.get("id", "?")))
			else:
				names.append(str(item))
		var prog := int(round(Production.current_progress(production_queue) * 100.0))
		next_text = "Queue: %s (%d%%)" % [", ".join(names), prog]
	if next_text != _last_queue_text:
		_last_queue_text = next_text
		queue_label.text = next_text

func set_rally(pos: Vector2) -> void:
	rally_point = pos
	has_rally = true

func _process(delta):
	fire_flash_timer = maxf(0.0, fire_flash_timer - delta)
	if is_exploding:
		explode_timer += delta
		queue_redraw()
		if explode_timer >= 0.75:
			queue_free()
		return

	var had_queue := not production_queue.is_empty()
	if had_queue:
		var eff := 1.0
		var scene = get_tree().current_scene
		if scene and scene.has_method("get_team_power_efficiency"):
			eff = float(scene.get_team_power_efficiency(team))
		var completed = Production.tick(production_queue, delta * eff)
		for uid in completed:
			_spawn_unit(uid)
		_refresh_queue_label()
	if stats and (stats.id == "turret" or stats.id == "missile_tower"):
		_process_turret(delta)
	var cur_prog := Production.current_progress(production_queue) if not production_queue.is_empty() else -1.0
	var dirty := fire_flash_timer > 0.0 \
		or selected != _last_draw_selected \
		or absf(turret_angle - _last_draw_turret) > 0.01 \
		or absf(cur_prog - _last_draw_prog) > 0.01 \
		or (had_queue and production_queue.is_empty())
	if dirty:
		_last_draw_selected = selected
		_last_draw_turret = turret_angle
		_last_draw_prog = cur_prog
		queue_redraw()

func _game_root() -> Node:
	var node: Node = self
	while node != null:
		if node.has_method("units_near") and node.has_method("spawn_combat_tracer"):
			return node
		node = node.get_parent()
	if not is_inside_tree():
		return null
	var tree := get_tree()
	if tree == null:
		return null
	var scene = tree.current_scene
	if scene != null and scene.has_method("units_near") and scene.has_method("spawn_combat_tracer"):
		return scene
	return null

func _process_turret(delta: float) -> void:
	turret_timer -= delta
	if turret_timer > 0.0:
		return
	var is_aa := stats != null and Fortification.is_anti_air(stats.id)
	var max_rng := 320.0 if is_aa else 260.0
	var candidates: Array = get_tree().get_nodes_in_group("units")
	var scene := _game_root()
	if scene != null:
		var nearby: Array = scene.units_near(global_position, max_rng)
		if not nearby.is_empty():
			candidates = nearby
	for u in candidates:
		if not is_instance_valid(u) or GameManager.is_allied(team, int(u.team)) or ("is_exploding" in u and u.is_exploding):
			continue
		if is_aa and u.stats and u.stats.unit_class != 3:
			continue
		if global_position.distance_to(u.global_position) <= max_rng:
			turret_timer = 0.9
			fire_flash_timer = 0.22
			turret_angle = (u.global_position - global_position).angle()
			var dmg_type := Damage.DamageType.EXPLOSIVE if is_aa else Damage.DamageType.KINETIC
			var dmg_val := 42.0 if is_aa else 25.0
			if scene and scene.has_method("spawn_combat_tracer"):
				scene.spawn_combat_tracer(global_position + Vector2.RIGHT.rotated(turret_angle) * 16.0, u.global_position, dmg_type, team)
			u.take_damage(dmg_val)
			break

func _spawn_unit(uid: String) -> void:
	var u = preload("res://scenes/unit.tscn").instantiate()
	var s: UnitStats = GameManager.registry.get_unit(uid)
	if s == null:
		s = UnitStats.new()
		s.id = uid
		s.display_name = uid.capitalize()
		s.hp = 100
		s.speed = 120.0
		s.base_damage = 12
		s.range_px = 200.0
		s.unit_class = 0
	u.setup(s, team)
	var offset := Vector2(randf_range(36.0, 56.0), randf_range(-24.0, 24.0))
	if team == 1:
		offset = - offset
	u.global_position = global_position + offset
	var scene = get_tree().current_scene
	if scene and scene.has_node("Units"):
		scene.get_node("Units").add_child(u)
		if has_rally:
			u.move_to(rally_point, true)
		if team == GameManager.local_team and not GameManager.is_spectator:
			AudioManager.play_bark("build_complete", GameManager.faction_for_team(team), s.display_name)

func take_damage(amount: float) -> void:
	if is_exploding:
		return
	hp -= int(maxf(1.0, round(amount)))
	if hp_bar:
		var ratio := clampf(float(hp) / maxf(1.0, float(stats.hp if stats else 500)), 0.0, 1.0)
		hp_bar.value = ratio * 100.0
		hp_bar.modulate = UnitVisual.hp_bar_color(ratio)
	if hp <= 0:
		_trigger_destruction()

func _trigger_destruction() -> void:
	if is_exploding:
		return
	is_exploding = true
	explode_timer = 0.0
	if body:
		body.visible = false
	if sprite:
		sprite.visible = false
	if hp_bar:
		hp_bar.visible = false
	GameManager.unregister_fort_block(self)
	var game_root := _game_root()
	if game_root != null and game_root.has_method("on_building_destroyed"):
		game_root.on_building_destroyed(self)
	remove_from_group("buildings")
	explosion_debris = UnitVisual.generate_explosion_debris(int(get_instance_id()), 14)
	var scene = get_tree().current_scene
	if scene and scene.has_method("spawn_explosion_vfx"):
		scene.spawn_explosion_vfx(global_position, 42.0)
	AudioManager.play_sfx("building_explode")

func enqueue_unit(uid: String, build_time: float = -1.0) -> void:
	var btime := build_time
	if btime <= 0.0:
		var s := GameManager.registry.get_unit(uid)
		btime = s.build_time if s != null else 4.0
	Production.enqueue(production_queue, uid, btime)
	_refresh_queue_label()

func cancel_last_queued() -> String:
	if production_queue.is_empty():
		return ""
	var cancelled := Production.cancel(production_queue, production_queue.size() - 1)
	_refresh_queue_label()
	return cancelled

func _draw():
	if is_exploding:
		var prog := clampf(explode_timer / 0.75, 0.0, 1.0)
		draw_arc(Vector2.ZERO, lerpf(10.0, 58.0, prog), 0, TAU, 28, Color(1.0, 0.65, 0.2, 1.0 - prog), 3.5)
		draw_circle(Vector2.ZERO, lerpf(12.0, 40.0, sin(prog * PI)), Color(1.0, 0.38, 0.08, 0.85 * (1.0 - prog * 0.6)))
		draw_circle(Vector2.ZERO, lerpf(6.0, 22.0, sin(prog * PI)), Color(1.0, 0.95, 0.65, 0.9 * (1.0 - prog)))
		for p in explosion_debris:
			var d_pos: Vector2 = p["dir"] * float(p["speed"]) * 1.4 * explode_timer
			draw_circle(d_pos, float(p["size"]), Color(0.95, 0.5, 0.15, 1.0 - prog))
		return

	# Grounded architectural contact shadow beneath the structure
	var gfx: Dictionary = UnitVisual.graphics_profile(String(SettingsManager.graphics_quality()))
	if bool(gfx.get("shadows", true)):
		var fp := float(maxi(stats.footprint.x, stats.footprint.y)) if stats else 2.0
		var half := clampf(fp * 9.5, 14.0, 26.0)
		draw_rect(Rect2(-half + 4.0, -half + 6.0, half * 2.0, half * 2.0), Color(0.02, 0.03, 0.04, 0.28), true)

	# Per-ID silhouettes come from BuildingVisual; only live turret aim is drawn here.
	if stats and (stats.id == "turret" or stats.id == "missile_tower"):
		var tip := Vector2.RIGHT.rotated(turret_angle) * 18.0
		draw_line(Vector2.ZERO, tip, Color(0.85, 0.88, 0.92, 1.0), 3.5)
		if fire_flash_timer > 0.0:
			draw_circle(tip, 5.5, Color(1.0, 0.88, 0.3, 0.9))
	if not production_queue.is_empty():
		var p := Production.current_progress(production_queue)
		draw_rect(Rect2(-19, 21, 38.0, 6.0), Color(0.05, 0.07, 0.09, 0.8), true)
		draw_rect(Rect2(-18, 22, 36.0 * p, 4.0), Color(0.2, 1.0, 0.4, 0.95), true)
	if selected:
		draw_rect(Rect2(-24, -24, 48, 48), Color(0.25, 0.95, 1.0, 0.9), false, 2.0)
		var local_rally := rally_point - global_position
		draw_line(Vector2.ZERO, local_rally, Color(0.25, 0.95, 1.0, 0.55), 1.5)
		draw_circle(local_rally, 4.5, Color(0.25, 0.95, 1.0, 0.9))
