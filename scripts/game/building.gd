# scripts/game/building.gd
extends StaticBody2D

var stats: BuildingStats
var team: int = 0
var hp: int = 500
var production_queue: Array = []
var rally_point: Vector2 = Vector2.ZERO
var has_rally: bool = false
var turret_timer: float = 0.0

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
		var base_c := Color(0.15, 0.45, 0.95, 1.0) if t == 0 else Color(0.9, 0.2, 0.2, 1.0)
		if s.is_hq:
			base_c = base_c.lightened(0.2)
		body.color = base_c

func set_rally(pos: Vector2) -> void:
	rally_point = pos
	has_rally = true

func _process(delta):
	var completed = Production.tick(production_queue, delta)
	for uid in completed:
		_spawn_unit(uid)
	if stats and stats.id == "turret":
		_process_turret(delta)

func _process_turret(delta: float) -> void:
	turret_timer -= delta
	if turret_timer > 0.0:
		return
	for u in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(u) or u.team == team:
			continue
		if global_position.distance_to(u.global_position) <= 260.0:
			turret_timer = 0.9
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
	hp -= int(maxf(1.0, round(amount)))
	if hp_bar:
		hp_bar.value = float(hp) / float(stats.hp if stats else 500) * 100.0
	if hp <= 0:
		remove_from_group("buildings")
		queue_free()

func enqueue_unit(uid: String, build_time: float = -1.0) -> void:
	var btime := build_time
	if btime <= 0.0:
		var s := GameManager.registry.get_unit(uid)
		btime = s.build_time if s != null else 4.0
	Production.enqueue(production_queue, uid, btime)
