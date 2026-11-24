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
var is_exploding: bool = false
var explode_timer: float = 0.0
var explosion_debris: Array[Dictionary] = []

@onready var body = $Body
@onready var hp_bar = $HpBar

func _ready():
	if stats:
		hp = stats.hp
	production_queue = Production.new_queue()
	rally_point = global_position + Vector2(56, 56) if team == 0 else global_position - Vector2(56, 56)
	add_to_group("buildings")

func setup(s: BuildingStats, t: int) -> void:
	stats = s
	team = t
	hp = s.hp
	rally_point = global_position + Vector2(56, 56) if t == 0 else global_position - Vector2(56, 56)
	if body:
		var fac_id := GameManager.player_faction if t == 0 else GameManager.ai_faction
		var base_c := Faction.color_of(fac_id).darkened(0.12)
		if s.is_hq:
			base_c = base_c.lightened(0.22)
		body.color = base_c

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

	var completed = Production.tick(production_queue, delta)
	for uid in completed:
		_spawn_unit(uid)
	if stats and stats.id == "turret":
		_process_turret(delta)
	queue_redraw()

func _process_turret(delta: float) -> void:
	turret_timer -= delta
	if turret_timer > 0.0:
		return
	for u in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(u) or u.team == team or ("is_exploding" in u and u.is_exploding):
			continue
		if global_position.distance_to(u.global_position) <= 260.0:
			turret_timer = 0.9
			fire_flash_timer = 0.22
			turret_angle = (u.global_position - global_position).angle()
			var scene = get_tree().current_scene
			if scene and scene.has_method("spawn_combat_tracer"):
				scene.spawn_combat_tracer(global_position + Vector2.RIGHT.rotated(turret_angle) * 16.0, u.global_position, Damage.DamageType.KINETIC, team)
			u.take_damage(25.0)
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
		offset = -offset
	u.global_position = global_position + offset
	var scene = get_tree().current_scene
	if scene and scene.has_node("Units"):
		scene.get_node("Units").add_child(u)
		if has_rally:
			u.move_to(rally_point, true)

func take_damage(amount: float) -> void:
	if is_exploding:
		return
	hp -= int(maxf(1.0, round(amount)))
	if hp_bar:
		hp_bar.value = maxf(0.0, float(hp) / float(stats.hp if stats else 500) * 100.0)
	if hp <= 0:
		_trigger_destruction()

func _trigger_destruction() -> void:
	if is_exploding:
		return
	is_exploding = true
	explode_timer = 0.0
	if body:
		body.visible = false
	if hp_bar:
		hp_bar.visible = false
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

	# Structural detail frame and turret barrel
	draw_rect(Rect2(-20, -20, 40, 40), Color(0.9, 0.95, 1.0, 0.35), false, 2.0)
	if stats and stats.is_hq:
		draw_arc(Vector2.ZERO, 12.0, 0, TAU, 20, Color(1.0, 0.9, 0.3, 0.85), 2.0)
	elif stats and stats.id == "turret":
		var tip := Vector2.RIGHT.rotated(turret_angle) * 18.0
		draw_line(Vector2.ZERO, tip, Color(0.85, 0.88, 0.92, 1.0), 3.5)
		if fire_flash_timer > 0.0:
			draw_circle(tip, 5.5, Color(1.0, 0.88, 0.3, 0.9))
	if not production_queue.is_empty():
		var p := Production.current_progress(production_queue)
		draw_rect(Rect2(-18, 22, 36.0 * p, 4.0), Color(0.2, 1.0, 0.4, 0.9), true)
