# scripts/game/game.gd
extends Node2D

var map_data: MapData
var selected_units: Array = []
var camera: Camera2D

@onready var units_container = $Units
@onready var ui = $UI
@onready var status_label = $UI/StatusLabel

func _ready():
	map_data = MapData.new(128, 128)
	# generate simple map
	for y in range(128):
		for x in range(128):
			if (x + y) % 17 == 0:
				map_data.set_terrain(x, y, MapData.Terrain.FOREST)
			elif x % 31 == 0 and y % 31 == 0:
				map_data.set_terrain(x, y, MapData.Terrain.MOUNTAIN)
	# spawn HQs
	_spawn_building(Vector2(80, 80), 0)
	_spawn_building(Vector2(920, 920), 1)
	# spawn starting units
	_spawn_unit(Vector2(100, 100), 0)
	_spawn_unit(Vector2(120, 100), 0)
	_spawn_unit(Vector2(900, 900), 1)
	_spawn_unit(Vector2(920, 900), 1)
	camera = $Camera2D
	GameManager.start_match(map_data)

func _spawn_unit(pos: Vector2, team: int) -> void:
	var u = preload("res://scenes/unit.tscn").instantiate()
	var s = UnitStats.new()
	s.id = "riflebot"
	s.display_name = "Riflebot"
	s.hp = 100
	s.speed = 120.0
	s.base_damage = 10
	s.range_px = 200.0
	s.unit_class = 0
	u.setup(s, team)
	u.global_position = pos
	units_container.add_child(u)

func _spawn_building(pos: Vector2, team: int) -> void:
	var b = preload("res://scenes/building.tscn").instantiate()
	var s = BuildingStats.new()
	s.id = "hq"
	s.display_name = "HQ"
	s.hp = 500
	s.is_hq = true
	b.setup(s, team)
	b.global_position = pos
	add_child(b)

func _unhandled_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# simple select: if clicking unit select it, else move selected
		var clicked = _unit_at(event.position + camera.position - get_viewport_rect().size/2) # rough
		if clicked:
			if not (Input.is_key_pressed(KEY_SHIFT)):
				for u in selected_units:
					u.selected = false
				selected_units.clear()
			clicked.selected = true
			selected_units.append(clicked)
		else:
			for u in selected_units:
				u.move_to(event.position + camera.position - get_viewport_rect().size/2)
	# camera pan with wasd handled in _process

func _unit_at(pos: Vector2):
	for u in units_container.get_children():
		if u.global_position.distance_to(pos) < 16:
			return u
	return null

func _process(delta):
	_check_win()
	var pan = Vector2.ZERO
	if Input.is_key_pressed(KEY_W): pan.y -= 1
	if Input.is_key_pressed(KEY_S): pan.y += 1
	if Input.is_key_pressed(KEY_A): pan.x -= 1
	if Input.is_key_pressed(KEY_D): pan.x += 1
	camera.position += pan * 400 * delta


func _check_win():
	if not is_instance_valid(status_label):
		return
	var teams = {}
	for u in units_container.get_children():
		if is_instance_valid(u):
			teams[u.team] = teams.get(u.team, 0) + 1
	if teams.size() == 1:
		var t = teams.keys()[0]
		status_label.text = "Team %d wins!" % t
	elif teams.size() == 0:
		status_label.text = "Draw"
