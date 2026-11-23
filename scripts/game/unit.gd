# scripts/game/unit.gd
extends CharacterBody2D

var stats: UnitStats
var team: int = 0
var hp: int = 100
var selected: bool = false
var target_pos: Vector2 = Vector2.ZERO
var has_target: bool = false
var attack_timer: float = 0.0
var attack_cooldown: float = 0.8

@onready var body = $Body
@onready var hp_bar = $HpBar

func _ready():
	if stats:
		hp = stats.hp
	target_pos = global_position
	add_to_group("units")

func setup(s: UnitStats, t: int) -> void:
	stats = s
	team = t
	hp = s.hp
	if body:
		body.color = Color.BLUE if t == 0 else Color.RED

func _physics_process(delta):
	attack_timer -= delta
	if has_target:
		var dir = (target_pos - global_position)
		if dir.length() > 4:
			velocity = dir.normalized() * (stats.speed if stats else 100.0)
			move_and_slide()
		else:
			has_target = false
			velocity = Vector2.ZERO
	else:
		velocity = Vector2.ZERO
		_try_attack()
	queue_redraw()

func _try_attack():
	if attack_timer > 0:
		return
	var enemy = _nearest_enemy()
	if enemy == null:
		return
	if global_position.distance_to(enemy.global_position) <= (stats.range_px if stats else 200.0):
		attack_timer = attack_cooldown
		var dmg = stats.base_damage if stats else 10
		enemy.take_damage(float(dmg))

func _nearest_enemy():
	var best = null
	var best_d = INF
	for u in get_tree().get_nodes_in_group("units"):
		if u == self or not is_instance_valid(u):
			continue
		if u.team == team:
			continue
		var d = global_position.distance_to(u.global_position)
		if d < best_d:
			best_d = d
			best = u
	return best

func move_to(pos: Vector2) -> void:
	target_pos = pos
	has_target = true

func take_damage(amount: float) -> void:
	hp -= int(round(amount))
	if hp_bar:
		hp_bar.value = float(hp) / float(stats.hp if stats else 100) * 100.0
	if hp <= 0:
		remove_from_group("units")
		queue_free()

func _draw():
	if selected:
		draw_arc(Vector2.ZERO, 18, 0, TAU, 24, Color.YELLOW, 2.0)
