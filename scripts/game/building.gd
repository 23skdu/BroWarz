# scripts/game/building.gd
extends StaticBody2D

var stats: BuildingStats
var team: int = 0
var hp: int = 500
var production_queue: Array = []

@onready var body = $Body
@onready var hp_bar = $HpBar

func _ready():
	if stats:
		hp = stats.hp
	production_queue = Production.new_queue()
	add_to_group("buildings")

func setup(s: BuildingStats, t: int) -> void:
	stats = s
	team = t
	hp = s.hp
	if body:
		body.color = Color.BLUE if t == 0 else Color.RED

func _process(delta):
	var completed = Production.tick(production_queue, delta)
	for uid in completed:
		_spawn_unit(uid)

func _spawn_unit(uid: String) -> void:
	# lookup stats by id (minimal)
	var u = preload("res://scenes/unit.tscn").instantiate()
	var s = UnitStats.new()
	s.id = uid
	s.display_name = uid
	s.hp = 100
	s.speed = 120.0
	s.base_damage = 10
	s.range_px = 200.0
	s.unit_class = 0
	u.setup(s, team)
	u.global_position = global_position + Vector2(40, 40)
	get_tree().current_scene.get_node("Units").add_child(u)

func take_damage(amount: float) -> void:
	hp -= int(round(amount))
	if hp_bar:
		hp_bar.value = float(hp) / float(stats.hp if stats else 500) * 100.0
	if hp <= 0:
		remove_from_group("buildings")
		queue_free()

func enqueue_unit(uid: String, build_time: float) -> void:
	Production.enqueue(production_queue, uid, build_time)
